package xyz.i4o.uni.launcher.overlay;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.provider.Settings;

/** Own only our exact policy update; restore the previous value without
 * overwriting later changes made by another app. No overscan or display resize. */
public final class SystemNavigationPolicy {
    private static final String SAVED="uniSystemNavSaved", APPLIED="uniSystemNavApplied";
    private SystemNavigationPolicy(){}
    public static boolean granted(Context c){return c.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS")==PackageManager.PERMISSION_GRANTED;}
    public static boolean setHidden(Context c,SharedPreferences p,boolean hidden){
        if(!granted(c))return false;
        try{
            String current=Settings.Global.getString(c.getContentResolver(),"policy_control");
            if(hidden){
                String previous=current==null?"<unset>":current;
                if(p.contains(SAVED)&&java.util.Objects.equals(current,p.getString(APPLIED,"")))previous=p.getString(SAVED,previous);
                else if(p.contains("savedPolicy")&&"immersive.navigation=*".equals(current))previous=p.getString("savedPolicy",previous);
                String desired=merge(current,NavigationInsets.applied(c));
                if(!Settings.Global.putString(c.getContentResolver(),"policy_control",desired))return false;
                return p.edit().putString(SAVED,previous).putString(APPLIED,desired).putBoolean("systemNavigationHidden",true).remove("savedPolicy").putBoolean("hideNavigation",false).putBoolean("globalNavigation",false).commit();
            }
            if(p.contains(SAVED)&&java.util.Objects.equals(current,p.getString(APPLIED,""))){
                String saved=p.getString(SAVED,"<unset>");
                if(!Settings.Global.putString(c.getContentResolver(),"policy_control","<unset>".equals(saved)?null:saved))return false;
            }
            return p.edit().remove(SAVED).remove(APPLIED).putBoolean("systemNavigationHidden",false)
                .putBoolean("hideNavigation",false).putBoolean("globalNavigation",false).commit();
        }catch(RuntimeException e){return false;}
    }
    private static String merge(String current,boolean nativeInsets){
        StringBuilder result=new StringBuilder();
        // XCSystemUI's CarNavigationBar only reacts to immersive.full;
        // immersive.navigation clears the inset but keeps drawing the bar.
        if(current!=null)for(String part:current.split(":"))if(!part.isEmpty()&&!part.startsWith("immersive.")){
            if(result.length()>0)result.append(':');result.append(part);
        }
        if(result.length()>0)result.append(':');return result.append(nativeInsets?"immersive.status=*,-com.ecarx.parking":"immersive.full=*,-com.ecarx.parking").toString();
    }
}
