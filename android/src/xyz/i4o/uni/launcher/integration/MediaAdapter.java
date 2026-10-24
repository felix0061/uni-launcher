package xyz.i4o.uni.launcher.integration;

import android.content.ComponentName;
import android.content.Context;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Handler;
import org.json.JSONObject;
import java.util.List;

/** Standard MediaSession is explicitly labeled; OEM source parity still needs car verification. */
public final class MediaAdapter {
    private final MediaSessionManager manager;
    private final ComponentName listener;
    private final Runnable changed;
    private final Handler handler=new Handler();
    private MediaController controller;
    private boolean authorized;
    private final MediaController.Callback callback=new MediaController.Callback(){
        public void onMetadataChanged(MediaMetadata m){changed.run();}
        public void onPlaybackStateChanged(PlaybackState s){changed.run();}
        public void onSessionDestroyed(){select(null);changed.run();}
    };
    private final MediaSessionManager.OnActiveSessionsChangedListener sessions=new MediaSessionManager.OnActiveSessionsChangedListener(){
        public void onActiveSessionsChanged(List<MediaController> list){select(list);changed.run();}
    };
    public MediaAdapter(Context context,Runnable changed){
        this.changed=changed;manager=(MediaSessionManager)context.getSystemService(Context.MEDIA_SESSION_SERVICE);
        listener=new ComponentName(context,MediaAccessService.class);
    }
    public void start(){
        stop();
        try{manager.addOnActiveSessionsChangedListener(sessions,listener,handler);select(manager.getActiveSessions(listener));authorized=true;}
        catch(SecurityException e){authorized=false;select(null);}
    }
    private void select(List<MediaController> list){
        if(controller!=null)controller.unregisterCallback(callback);
        controller=null;
        if(list!=null)for(MediaController c:list){
            if(controller==null)controller=c;
            if("ecarx.xsf.mediacenter".equals(c.getPackageName())){controller=c;break;}
            PlaybackState state=c.getPlaybackState();
            if(state!=null&&state.getState()==PlaybackState.STATE_PLAYING)controller=c;
        }
        if(controller!=null)controller.registerCallback(callback,handler);
    }
    public JSONObject snapshot(){
        JSONObject j=new JSONObject();try{
            j.put("authorized",authorized).put("available",controller!=null).put("playing",false);
            if(controller!=null){
                MediaMetadata m=controller.getMetadata();PlaybackState p=controller.getPlaybackState();
                j.put("source",controller.getPackageName()).put("title",m==null?"":m.getString(MediaMetadata.METADATA_KEY_TITLE))
                    .put("artist",m==null?"":m.getString(MediaMetadata.METADATA_KEY_ARTIST))
                    .put("collection",m==null?"":m.getString(MediaMetadata.METADATA_KEY_ALBUM))
                    .put("playing",p!=null&&p.getState()==PlaybackState.STATE_PLAYING);
            }
        }catch(Exception ignored){}return j;
    }
    public boolean command(String action){
        if(controller==null)return false;
        PlaybackState p=controller.getPlaybackState();if(p==null)return false;
        long actions=p.getActions();MediaController.TransportControls t=controller.getTransportControls();
        if("next".equals(action)&&(actions&PlaybackState.ACTION_SKIP_TO_NEXT)!=0)t.skipToNext();
        else if("previous".equals(action)&&(actions&PlaybackState.ACTION_SKIP_TO_PREVIOUS)!=0)t.skipToPrevious();
        else if("toggle-play".equals(action)){
            if(p.getState()==PlaybackState.STATE_PLAYING&&(actions&(PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_PLAY_PAUSE))!=0)t.pause();
            else if(p.getState()!=PlaybackState.STATE_PLAYING&&(actions&(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PLAY_PAUSE))!=0)t.play();
            else return false;
        }else return false;
        return true;
    }
    public void stop(){try{manager.removeOnActiveSessionsChangedListener(sessions);}catch(Exception ignored){}select(null);}
}
