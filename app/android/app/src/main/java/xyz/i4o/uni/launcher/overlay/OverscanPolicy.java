package xyz.i4o.uni.launcher.overlay;

import android.content.Context;
import android.content.SharedPreferences;

/** Reserve the dock strip by shrinking every app window's bottom edge.
 * `wm overscan` is a WindowManager shell command; as a platform-signed app we
 * may hold the required signature permission, but a denied exec must degrade
 * gracefully (the overlay then covers the last 96px of external apps). */
public final class OverscanPolicy {
    private static final String APPLIED="uniOverscanApplied";
    private static final String[] ON={"wm","overscan","0,0,0,96"};
    private static final String[] OFF={"wm","overscan","reset"};
    private OverscanPolicy(){}
    public static boolean applied(Context c){
        return c.getSharedPreferences("launcher",0).getBoolean(APPLIED,false);
    }
    public static boolean apply(Context c,SharedPreferences p,boolean on){
        try{
            // Call the Android 9 binder API directly: `cmd window` shell
            // entrypoints can reject an app UID even with platform permissions.
            try{
                Object service=Class.forName("android.view.WindowManagerGlobal")
                    .getMethod("getWindowManagerService").invoke(null);
                Class.forName("android.view.IWindowManager").getMethod("setOverscan",
                    int.class,int.class,int.class,int.class,int.class)
                    .invoke(service,0,0,0,0,on?96:0);
                p.edit().putBoolean(APPLIED,on).commit();return true;
            }catch(ReflectiveOperationException|RuntimeException e){
                android.util.Log.w("UniDock","Direct workspace reservation unavailable",e);
            }
            Process process=new ProcessBuilder().command(on?ON:OFF).start();
            boolean ok=process.waitFor()==0;
            if(ok)p.edit().putBoolean(APPLIED,on).commit();
            return ok;
        }catch(RuntimeException|InterruptedException|java.io.IOException e){
            return false;
        }
    }
}
