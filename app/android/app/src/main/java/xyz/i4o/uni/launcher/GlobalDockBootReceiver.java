package xyz.i4o.uni.launcher;
import android.content.*;
/** Restore only the owner's previously enabled dock after normal boot. */
public final class GlobalDockBootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c,Intent i){
        if(Intent.ACTION_BOOT_COMPLETED.equals(i.getAction()))GlobalDockService.ensureStarted(c);
    }
}
