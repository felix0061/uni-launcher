package ecarx.xsf.mediacenter;

import android.app.Activity;
import android.os.Bundle;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.widget.TextView;

/** Synthetic source. Installed ONLY by tools/build-fixture.py onto an emulator. */
public final class FixtureActivity extends Activity {
    private static MediaSession session;
    private static boolean playing=true;
    private static int track=0;
    public void onCreate(Bundle saved){
        super.onCreate(saved);TextView t=new TextView(this);t.setText("UNI emulator test source — not OEM software");t.setTextSize(24);setContentView(t);
        startService(new android.content.Intent(this,FixtureMediaService.class));
    }
    static void ensureSession(android.content.Context context){
        if(session==null){
            session=new MediaSession(context,"UniEmulatorFixture");
            session.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS|MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);
            session.setCallback(new MediaSession.Callback(){
                public void onPlay(){playing=true;update();}
                public void onPause(){playing=false;update();}
                public void onSkipToNext(){track++;update();}
                public void onSkipToPrevious(){track--;update();}
            });
        }
        session.setActive(true);update();
    }
    private static void update(){
        session.setMetadata(new MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE,track==0?"<img src=x onerror=window.injected=true>":"Fixture track "+track)
            .putString(MediaMetadata.METADATA_KEY_ARTIST,"UNI test artist").putString(MediaMetadata.METADATA_KEY_ALBUM,"Synthetic media session")
            .putString("android.media.metadata.LYRICS","[00:00.00]Fixture lyric first\n[00:03.00]Fixture lyric second\n[00:06.00]Fixture lyric third")
            .putLong(MediaMetadata.METADATA_KEY_DURATION,180000).build());
        session.setPlaybackState(new PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_SKIP_TO_NEXT|PlaybackState.ACTION_SKIP_TO_PREVIOUS)
            .setState(playing?PlaybackState.STATE_PLAYING:PlaybackState.STATE_PAUSED,1000,1).build());
    }
}
