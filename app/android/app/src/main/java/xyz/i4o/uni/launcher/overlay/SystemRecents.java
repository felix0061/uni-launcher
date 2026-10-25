package xyz.i4o.uni.launcher.overlay;

import android.content.Context;
import android.os.IBinder;
import android.util.Log;
import android.widget.Toast;

/** Opens the OEM SystemUI task-card page; never constructs a substitute list. */
public final class SystemRecents {
    private static int previousTask=-1;
    private SystemRecents(){}
    public static void toggle(Context context){
        // IP753 registers a dedicated recent-task panel rather than SystemUI's
        // AOSP recents callback. Resolve its declared exported action first.
        android.content.Intent oem=new android.content.Intent("ecarx.action.OPEN_RECENT_PANEL")
            .setPackage("com.ecarx.recents").addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
        android.content.pm.ResolveInfo target=context.getPackageManager().resolveActivity(oem,0);
        if(target!=null&&target.activityInfo!=null&&target.activityInfo.exported){
            try{
                android.app.ActivityManager tasks=(android.app.ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
                java.util.List<DisplayTasks.Task> running=DisplayTasks.visible(context);
                if(!running.isEmpty()&&"com.ecarx.recents".equals(running.get(0).packageName)){
                    int targetTask=-1;
                    for(DisplayTasks.Task task:DisplayTasks.all(context))
                        if(task.id==previousTask){targetTask=task.id;break;}
                    if(targetTask<0)for(DisplayTasks.Task task:DisplayTasks.all(context))
                        if(!"com.ecarx.recents".equals(task.packageName)){targetTask=task.id;break;}
                    if(targetTask>=0){tasks.moveTaskToFront(targetTask,0);return;}
                }
                if(!running.isEmpty())previousTask=running.get(0).id;
                // Supply bounds before creation where the firmware supports
                // them; resizing an already-created OEM panel can crash it.
                android.util.DisplayMetrics real=new android.util.DisplayMetrics();
                ((android.view.WindowManager)context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getRealMetrics(real);
                android.app.ActivityOptions options=android.app.ActivityOptions.makeBasic();
                options.setLaunchBounds(new android.graphics.Rect(0,0,real.widthPixels,
                    real.heightPixels-Math.round(real.widthPixels*96f/1920f)));
                context.startActivity(oem,options.toBundle());return;
            }
            catch(RuntimeException e){Log.w("UniRecents","OEM task panel unavailable",e);}
        }
        try{
            Class<?> manager=Class.forName("android.os.ServiceManager");
            IBinder binder=(IBinder)manager.getMethod("getService",String.class).invoke(null,"statusbar");
            Class<?> stub=Class.forName("com.android.internal.statusbar.IStatusBarService$Stub");
            Object service=stub.getMethod("asInterface",IBinder.class).invoke(null,binder);
            Class.forName("com.android.internal.statusbar.IStatusBarService").getMethod("toggleRecentApps").invoke(service);
            return;
        }catch(ReflectiveOperationException|RuntimeException e){Log.w("UniRecents","Status bar recent-tasks API unavailable",e);}
        // Android 9 fallback uses the already declared platform INJECT_EVENTS
        // permission. Run off the main thread; input waits for its own dispatch.
        new Thread(()->{
            try{if(new ProcessBuilder("input","keyevent","187").start().waitFor()==0)return;}
            catch(Exception e){Log.w("UniRecents","App-switch key unavailable",e);}
            new android.os.Handler(android.os.Looper.getMainLooper()).post(()->Toast.makeText(context,"系统任务列表暂不可用",Toast.LENGTH_SHORT).show());
        },"uni-recents").start();
    }
}
