package xyz.i4o.uni.launcher.overlay;

import android.app.PendingIntent;
import android.content.*;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.os.*;
import java.io.*;
import java.lang.reflect.Method;

/** Code-free resource adapter bundled only in the platform-signed car APK.
 * Native navigation insets keep system confirmation controls above the dock.
 * No framework file is replaced; disabling the dock restores the overlay state. */
public final class NavigationInsets {
    public static final String PACKAGE="xyz.i4o.uni.launcher.insets";
    private static final String SAVED="uniNativeInsetsOriginal",APPLIED="uniNativeInsetsApplied";
    private NavigationInsets(){}
    public static boolean applied(Context c){return c.getSharedPreferences("launcher",0).getBoolean(APPLIED,false);}
    public static boolean supported(Context c){
        if(c.checkSelfPermission("android.permission.CHANGE_OVERLAY_PACKAGES")!=PackageManager.PERMISSION_GRANTED
            ||c.checkSelfPermission("android.permission.STATUS_BAR_SERVICE")!=PackageManager.PERMISSION_GRANTED)return false;
        try{c.getPackageManager().getPackageInfo(PACKAGE,0);return true;}catch(PackageManager.NameNotFoundException e){return false;}
    }
    private static Object manager()throws Exception{
        android.os.IBinder binder=(android.os.IBinder)Class.forName("android.os.ServiceManager").getMethod("getService",String.class).invoke(null,"overlay");
        return Class.forName("android.content.om.IOverlayManager$Stub").getMethod("asInterface",android.os.IBinder.class).invoke(null,binder);
    }
    private static Object invoke(Object manager,String name,Class<?>[] types,Object...args)throws Exception{
        return Class.forName("android.content.om.IOverlayManager").getMethod(name,types).invoke(manager,args);
    }
    public static boolean activate(Context c,SharedPreferences p){
        if(c.checkSelfPermission("android.permission.CHANGE_OVERLAY_PACKAGES")!=PackageManager.PERMISSION_GRANTED)return false;
        try{
            Object manager=manager();int user=android.os.Process.myUid()/100000;
            Object info=invoke(manager,"getOverlayInfo",new Class<?>[]{String.class,int.class},PACKAGE,user);
            if(info==null)return false;
            boolean was=(Boolean)info.getClass().getMethod("isEnabled").invoke(info);
            if(!p.contains(SAVED))p.edit().putBoolean(SAVED,was).commit();
            invoke(manager,"setHighestPriority",new Class<?>[]{String.class,int.class},PACKAGE,user);
            boolean ok=Boolean.TRUE.equals(invoke(manager,"setEnabled",new Class<?>[]{String.class,boolean.class,int.class},PACKAGE,true,user));
            if(ok){p.edit().putBoolean(APPLIED,true).commit();refreshPolicy(c);}return ok;
        }catch(Exception e){android.util.Log.w("UniInsets","Native navigation resources unavailable",e);return false;}
    }
    public static void restore(Context c,SharedPreferences p){
        if(!p.contains(SAVED))return;
        try{
            Object manager=manager();int user=android.os.Process.myUid()/100000;
            invoke(manager,"setEnabled",new Class<?>[]{String.class,boolean.class,int.class},PACKAGE,p.getBoolean(SAVED,false),user);
            p.edit().remove(SAVED).remove(APPLIED).commit();
            refreshPolicy(c);
        }catch(Exception e){android.util.Log.w("UniInsets","Unable to restore native navigation resources",e);}
    }
    private static void refreshPolicy(Context c){
        // Android 9 caches policy dimensions independently of app resources.
        // Reconfigure with the existing density; never change its actual value
        // or introduce a forced-density preference where there was none.
        new Handler(Looper.getMainLooper()).postDelayed(()->{
            try{
                Object binder=Class.forName("android.view.WindowManagerGlobal").getMethod("getWindowManagerService").invoke(null);
                Class<?> type=Class.forName("android.view.IWindowManager");int user=android.os.Process.myUid()/100000;
                String forced=android.provider.Settings.Secure.getString(c.getContentResolver(),"display_density_forced");
                if(forced==null||forced.isEmpty())type.getMethod("clearForcedDisplayDensityForUser",int.class,int.class).invoke(binder,0,user);
                else{
                    int density=((Number)type.getMethod("getBaseDisplayDensity",int.class).invoke(binder,0)).intValue();
                    type.getMethod("setForcedDisplayDensityForUser",int.class,int.class,int.class).invoke(binder,0,density,user);
                }
            }catch(Exception e){android.util.Log.w("UniInsets","Navigation policy refresh unavailable",e);}
        },250);
    }
    public static void prepare(Context c,Runnable done){
        try{c.getPackageManager().getPackageInfo(PACKAGE,0);done.run();return;}catch(PackageManager.NameNotFoundException ignored){}
        if(c.checkSelfPermission("android.permission.INSTALL_PACKAGES")!=PackageManager.PERMISSION_GRANTED){done.run();return;}
        InputStream asset;
        try{asset=c.getAssets().open("uni-nav-insets.apk");}catch(IOException e){done.run();return;}
        Handler main=new Handler(Looper.getMainLooper());String action=c.getPackageName()+".NATIVE_INSETS_INSTALLED";
        BroadcastReceiver receiver=new BroadcastReceiver(){public void onReceive(Context context,Intent intent){
            try{context.unregisterReceiver(this);}catch(RuntimeException ignored){}
            done.run();
        }};
        c.registerReceiver(receiver,new IntentFilter(action));
        new Thread(()->{
            int id=-1;PackageInstaller installer=c.getPackageManager().getPackageInstaller();
            try(InputStream in=asset){
                PackageInstaller.SessionParams params=new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                params.setAppPackageName(PACKAGE);id=installer.createSession(params);
                try(PackageInstaller.Session session=installer.openSession(id)){
                    try(OutputStream out=session.openWrite("base.apk",0,-1)){byte[] buffer=new byte[16384];int size;while((size=in.read(buffer))>=0)out.write(buffer,0,size);session.fsync(out);}
                    PendingIntent result=PendingIntent.getBroadcast(c,753,new Intent(action).setPackage(c.getPackageName()),PendingIntent.FLAG_UPDATE_CURRENT);
                    session.commit(result.getIntentSender());
                }
            }catch(Exception e){
                if(id>=0)try{installer.abandonSession(id);}catch(RuntimeException ignored){}
                android.util.Log.w("UniInsets","Resource adapter installation unavailable",e);
                main.post(()->{try{c.unregisterReceiver(receiver);}catch(RuntimeException ignored){}done.run();});
            }
        },"uni-native-insets").start();
    }
}
