package xyz.i4o.uni.launcher.integration;

import android.content.ComponentName;
import android.content.Context;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Handler;
import android.os.Bundle;
import android.os.SystemClock;
import org.json.JSONObject;
import org.json.JSONArray;
import xyz.i4o.uni.launcher.core.MediaSourcePolicy;
import android.graphics.Bitmap;
import android.util.Base64;
import java.io.ByteArrayOutputStream;
import java.util.List;
import java.util.ArrayList;

/** Standard MediaSession is explicitly labeled; OEM source parity still needs car verification. */
public final class MediaAdapter {
    private final MediaSessionManager manager;
    private final ComponentName listener;
    private final Runnable changed;
    private final NeteaseMediaAdapter netease;
    private final Handler handler=new Handler();
    private MediaController controller;
    private boolean authorized;
    private String preferred="auto";
    private Bitmap lastCover;
    private String coverData="";
    private boolean artworkDirty=true;
    private JSONArray activeSources=new JSONArray();
    private final List<MediaController> observed=new ArrayList<>();
    public void setPreferredPackage(String value){preferred=value==null||value.isEmpty()?"auto":value;start();}
    private final MediaController.Callback callback=new MediaController.Callback(){
        public void onMetadataChanged(MediaMetadata m){artworkDirty=true;changed.run();}
        public void onPlaybackStateChanged(PlaybackState s){choose();changed.run();}
        public void onExtrasChanged(Bundle extras){changed.run();}
        public void onSessionDestroyed(){
            try{select(manager.getActiveSessions(listener));}catch(SecurityException e){authorized=false;select(null);}
            changed.run();
        }
    };
    private final MediaSessionManager.OnActiveSessionsChangedListener sessions=new MediaSessionManager.OnActiveSessionsChangedListener(){
        public void onActiveSessionsChanged(List<MediaController> list){select(list);changed.run();}
    };
    public MediaAdapter(Context context,Runnable changed){
        this.changed=changed;netease=new NeteaseMediaAdapter(changed);manager=(MediaSessionManager)context.getSystemService(Context.MEDIA_SESSION_SERVICE);
        listener=new ComponentName(context,MediaAccessService.class);
    }
    public void start(){
        stop();
        try{manager.addOnActiveSessionsChangedListener(sessions,listener,handler);select(manager.getActiveSessions(listener));authorized=true;}
        catch(SecurityException e){authorized=false;select(null);}
    }
    private void select(List<MediaController> list){
        for(MediaController c:observed)c.unregisterCallback(callback);
        observed.clear();
        controller=null;
        lastCover=null;coverData="";artworkDirty=true;activeSources=new JSONArray();
        if(list!=null)observed.addAll(list);
        choose();
        // Observe every session: a player's state can change without the
        // active-session list changing, including paused -> playing.
        for(MediaController c:observed)c.registerCallback(callback,handler);
    }
    private void choose(){
            activeSources=new JSONArray();
            String[] packages=new String[observed.size()];boolean[] playing=new boolean[observed.size()];
            for(int i=0;i<observed.size();i++){
                MediaController c=observed.get(i);PlaybackState p=c.getPlaybackState();
                packages[i]=c.getPackageName();playing[i]=p!=null&&p.getState()==PlaybackState.STATE_PLAYING;
                try{activeSources.put(new JSONObject().put("package",packages[i]).put("playing",playing[i]));}catch(Exception ignored){}
            }
            int selected=MediaSourcePolicy.select(preferred,packages,playing);
            MediaController next=selected>=0?observed.get(selected):null;
            if(next!=controller){controller=next;lastCover=null;coverData="";artworkDirty=true;}
            netease.setController(controller);
    }
    public JSONObject snapshot(){
        JSONObject j=new JSONObject();try{
            j.put("authorized",authorized).put("available",controller!=null).put("playing",false).put("preferredPackage",preferred).put("sessions",activeSources)
                .put("reason",!authorized?"请授权媒体访问":controller==null?"所选播放器尚未建立媒体会话":"");
            if(controller!=null){
                MediaMetadata m=controller.getMetadata();PlaybackState p=controller.getPlaybackState();
                j.put("source",controller.getPackageName()).put("title",m==null?"":m.getString(MediaMetadata.METADATA_KEY_TITLE))
                    .put("artist",m==null?"":m.getString(MediaMetadata.METADATA_KEY_ARTIST))
                    .put("collection",m==null?"":m.getString(MediaMetadata.METADATA_KEY_ALBUM))
                    .put("playing",p!=null&&p.getState()==PlaybackState.STATE_PLAYING);
                long actions=p==null?0:p.getActions();
                j.put("canNext",(actions&PlaybackState.ACTION_SKIP_TO_NEXT)!=0)
                    .put("canSeek",(actions&PlaybackState.ACTION_SEEK_TO)!=0)
                    .put("canPrevious",(actions&PlaybackState.ACTION_SKIP_TO_PREVIOUS)!=0)
                    .put("canToggle",p!=null&&(actions&(p.getState()==PlaybackState.STATE_PLAYING?(PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_PLAY_PAUSE):(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PLAY_PAUSE)))!=0)
                    .put("artwork",artwork(m));
                // Android has no universal lyrics contract. Only accept an explicit
                // text payload; URIs, cache files and private OEM APIs are not guessed.
                String lyrics=readLyrics(m,controller.getExtras());
                j.put("lyrics",lyrics).put("lyricsSource",lyrics.isEmpty()?"":"media-session")
                    .put("durationMs",m==null?0:Math.max(0,m.getLong(MediaMetadata.METADATA_KEY_DURATION)))
                    .put("positionMs",position(p)).put("positionKnown",p!=null&&p.getPosition()>=0)
                    .put("sampledAtMs",System.currentTimeMillis())
                    .put("speed",p==null?0:p.getPlaybackSpeed());
                netease.augmentSnapshot(j);
            }
        }catch(Exception ignored){}return j;
    }
    private String artwork(MediaMetadata m){
        if(!artworkDirty)return coverData;artworkDirty=false;
        if(m==null){lastCover=null;coverData="";return "";}
        Bitmap bitmap=m.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
        if(bitmap==null)bitmap=m.getBitmap(MediaMetadata.METADATA_KEY_ART);
        if(bitmap==lastCover)return coverData;
        lastCover=bitmap;coverData="";
        if(bitmap!=null&&!bitmap.isRecycled())try{
            float scale=Math.min(1f,256f/Math.max(bitmap.getWidth(),bitmap.getHeight()));
            Bitmap small=Bitmap.createScaledBitmap(bitmap,Math.max(1,(int)(bitmap.getWidth()*scale)),Math.max(1,(int)(bitmap.getHeight()*scale)),true);
            ByteArrayOutputStream bytes=new ByteArrayOutputStream();small.compress(Bitmap.CompressFormat.JPEG,80,bytes);
            coverData=Base64.encodeToString(bytes.toByteArray(),Base64.NO_WRAP);
            if(small!=bitmap)small.recycle();
        }catch(RuntimeException ignored){}
        return coverData;
    }
    private static String readLyrics(MediaMetadata metadata,Bundle extras){
        String[] keys={"android.media.metadata.LYRICS","android.media.metadata.LYRIC","lyrics","lyric","lrc"};
        for(String key:keys){
            try{CharSequence value=metadata==null?null:metadata.getText(key);
                if(value!=null&&value.length()>0&&value.length()<=131072)return value.toString();
            }catch(RuntimeException ignored){}
            try{Object value=extras==null?null:extras.get(key);
                if(value instanceof CharSequence&&((CharSequence)value).length()>0&&((CharSequence)value).length()<=131072)return value.toString();
            }catch(RuntimeException ignored){}
        }
        return "";
    }
    private static long position(PlaybackState p){
        if(p==null||p.getPosition()<0)return 0;
        long value=p.getPosition();
        if(p.getState()==PlaybackState.STATE_PLAYING&&p.getLastPositionUpdateTime()>0)
            value+=(long)(Math.max(0,SystemClock.elapsedRealtime()-p.getLastPositionUpdateTime())*p.getPlaybackSpeed());
        return Math.max(0,value);
    }
    public boolean command(String action){
        return command(action,-1);
    }
    public boolean command(String action,long positionMs){
        if(controller==null)return false;
        if(NeteaseMediaAdapter.supports(controller))return netease.command(action,positionMs);
        PlaybackState p=controller.getPlaybackState();if(p==null)return false;
        long actions=p.getActions();MediaController.TransportControls t=controller.getTransportControls();
        if("next".equals(action)&&(actions&PlaybackState.ACTION_SKIP_TO_NEXT)!=0)t.skipToNext();
        else if("previous".equals(action)&&(actions&PlaybackState.ACTION_SKIP_TO_PREVIOUS)!=0)t.skipToPrevious();
        else if("seek".equals(action)&&positionMs>=0&&(actions&PlaybackState.ACTION_SEEK_TO)!=0){
            MediaMetadata m=controller.getMetadata();long duration=m==null?0:m.getLong(MediaMetadata.METADATA_KEY_DURATION);
            t.seekTo(duration>0?Math.min(positionMs,duration):positionMs);
        }
        else if("toggle-play".equals(action)){
            if(p.getState()==PlaybackState.STATE_PLAYING&&(actions&(PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_PLAY_PAUSE))!=0)t.pause();
            else if(p.getState()!=PlaybackState.STATE_PLAYING&&(actions&(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PLAY_PAUSE))!=0)t.play();
            else return false;
        }else return false;
        return true;
    }
    public void stop(){try{manager.removeOnActiveSessionsChangedListener(sessions);}catch(Exception ignored){}select(null);}
}
