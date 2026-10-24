package xyz.i4o.uni.launcher.integration;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import org.json.JSONObject;

/** Resolve installed navigation only; never launch a guessed component. */
public final class NavigationApps {
    private final Context context;
    private final SharedPreferences prefs;
    public NavigationApps(Context context,SharedPreferences prefs){this.context=context;this.prefs=prefs;}
    public String selected(){
        String saved=prefs.getString("navigationPackage","auto");
        if(!"auto".equals(saved))return saved;
        for(String p:new String[]{"com.autonavi.amapauto","com.autonavi.amapautolite","com.autonavi.amapauto32","com.autonavi.minimap"})
            if(context.getPackageManager().getLaunchIntentForPackage(p)!=null)return p;
        return "";
    }
    public Intent launchIntent(){String pkg=selected();return pkg.isEmpty()?null:context.getPackageManager().getLaunchIntentForPackage(pkg);}
    public JSONObject snapshot(){
        JSONObject j=new JSONObject();try{
            Intent intent=launchIntent();
            boolean permission=context.checkSelfPermission("android.permission.INJECT_EVENTS")==PackageManager.PERMISSION_GRANTED;
            boolean stacks=context.checkSelfPermission("android.permission.MANAGE_ACTIVITY_STACKS")==PackageManager.PERMISSION_GRANTED;
            boolean move=context.checkSelfPermission("android.permission.INTERNAL_SYSTEM_WINDOW")==PackageManager.PERMISSION_GRANTED;
            boolean api=Build.VERSION.SDK_INT==28;
            boolean enabled=prefs.getBoolean("embedNavigation",true);
            String label="高德地图";try{label=context.getPackageManager().getApplicationLabel(context.getPackageManager().getApplicationInfo(selected(),0)).toString();}catch(Exception ignored){}
            j.put("label",label).put("package",selected()).put("preferredPackage",prefs.getString("navigationPackage","auto"))
                .put("installed",intent!=null).put("enabled",enabled).put("injectGranted",permission).put("activityStacksGranted",stacks).put("moveStackGranted",move)
                .put("canEmbed",api&&permission&&stacks&&move&&intent!=null&&enabled)
                .put("reason",intent==null?"请安装或选择高德地图":!enabled?"地图嵌入已关闭":!api?"当前容器适用于 Android 9":!permission||!stacks||!move?"需要车机系统嵌入授权":"等待地图容器就绪");
        }catch(Exception ignored){}return j;
    }
}
