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
        if(session==null){
            session=new MediaSession(this,"UniEmulatorFixture");
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
            .putString(MediaMetadata.METADATA_KEY_ARTIST,"UNI test artist").putString(MediaMetadata.METADATA_KEY_ALBUM,"Synthetic media session").build());
        session.setPlaybackState(new PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY|PlaybackState.ACTION_PAUSE|PlaybackState.ACTION_SKIP_TO_NEXT|PlaybackState.ACTION_SKIP_TO_PREVIOUS)
            .setState(playing?PlaybackState.STATE_PLAYING:PlaybackState.STATE_PAUSED,1000,1).build());
    }
}
