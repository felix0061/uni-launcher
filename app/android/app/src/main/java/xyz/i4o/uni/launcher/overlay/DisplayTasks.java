package xyz.i4o.uni.launcher.overlay;

import android.app.ActivityManager;
import android.content.ComponentName;
import android.content.Context;
import java.util.ArrayList;
import java.util.List;

/** Only physical-display tasks belong to the global dock. ActivityView maps
 * can lead getRunningTasks() even while HOME is visible on display 0. */
public final class DisplayTasks {
    public static final class Task {
        public final int id;
        public final String packageName;
        Task(int id,String packageName){this.id=id;this.packageName=packageName;}
    }
    private DisplayTasks(){}
    public static List<Task> visible(Context context){
        return read(context,true);
    }
    public static List<Task> all(Context context){
        return read(context,false);
    }
    private static List<Task> read(Context context,boolean visibleOnly){
        List<Task> result=new ArrayList<>();
        try{
            Object manager=ActivityManager.class.getMethod("getService").invoke(null);
            List<?> stacks=(List<?>)Class.forName("android.app.IActivityManager").getMethod("getAllStackInfos").invoke(manager);
            for(Object stack:stacks){
                Class<?> type=stack.getClass();
                if(type.getField("displayId").getInt(stack)!=0||(visibleOnly&&!type.getField("visible").getBoolean(stack)))continue;
                int[] ids=(int[])type.getField("taskIds").get(stack);
                String[] names=(String[])type.getField("taskNames").get(stack);
                if(ids==null||names==null)continue;
                for(int i=Math.min(ids.length,names.length)-1;i>=0;i--){
                    ComponentName component=ComponentName.unflattenFromString(names[i]);
                    if(component!=null)result.add(new Task(ids[i],component.getPackageName()));
                }
            }
            return result;
        }catch(ReflectiveOperationException|RuntimeException ignored){}
        // Unprivileged emulator fallback. Physical car builds have the stack API.
        ActivityManager am=(ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
        try{for(ActivityManager.RunningTaskInfo task:am.getRunningTasks(8))
            if(task.topActivity!=null)result.add(new Task(task.id,task.topActivity.getPackageName()));
        }catch(RuntimeException ignored){}
        return result;
    }
    public static String topPackage(Context context){
        List<Task> tasks=visible(context);return tasks.isEmpty()?"":tasks.get(0).packageName;
    }
}
