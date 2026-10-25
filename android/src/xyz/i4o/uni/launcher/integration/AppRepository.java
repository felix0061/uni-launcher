package xyz.i4o.uni.launcher.integration;

import android.content.Context;
import android.content.Intent;
import android.content.ComponentName;
import android.content.pm.ResolveInfo;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.util.Base64;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class AppRepository {
    private final Context context;
    private final Map<String, ComponentName> allowed = new LinkedHashMap<String, ComponentName>();
    public AppRepository(Context context) {this.context=context;}
    public JSONArray refresh() {
        allowed.clear(); JSONArray result=new JSONArray();
        Intent query=new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> apps=context.getPackageManager().queryIntentActivities(query,0);
        Collections.sort(apps,new Comparator<ResolveInfo>() {
            public int compare(ResolveInfo a,ResolveInfo b){return a.loadLabel(context.getPackageManager()).toString().compareTo(b.loadLabel(context.getPackageManager()).toString());}
        });
        for(ResolveInfo app:apps) try {
            if (!usable(app.activityInfo)) continue;
            if(context.getPackageName().equals(app.activityInfo.packageName))continue;
            ComponentName c=new ComponentName(app.activityInfo.packageName,app.activityInfo.name);
            String key=c.flattenToString(); if(allowed.containsKey(key))continue;
            allowed.put(key,c);
            Drawable drawable=app.loadIcon(context.getPackageManager());
            Bitmap bitmap=Bitmap.createBitmap(72,72,Bitmap.Config.ARGB_8888);Canvas canvas=new Canvas(bitmap);
            drawable.setBounds(0,0,72,72);drawable.draw(canvas);
            ByteArrayOutputStream out=new ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.PNG,100,out);bitmap.recycle();
            result.put(new JSONObject().put("id",key).put("package",app.activityInfo.packageName).put("label",app.loadLabel(context.getPackageManager()).toString())
                .put("icon","data:image/png;base64,"+Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP)));
        } catch(Exception e){android.util.Log.w("UniApps","Unable to read app icon",e);}
        return result;
    }
    public boolean launch(String key) {
        ComponentName c=allowed.get(key);if(c==null)return false;
        try {if (!usable(context.getPackageManager().getActivityInfo(c,0))) return false;
            context.startActivity(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;}
        catch(Exception e){return false;}
    }
    public boolean launchPackage(String pkg) {
        try {
            Intent i = packageIntent(pkg);
            if (i == null) return false;
            context.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;
        } catch(Exception e){return false;}
    }
    public String packageStatus(String pkg) {
        if (pkg == null || pkg.length() == 0) return "not-installed";
        try {
            ApplicationInfo app = context.getPackageManager().getApplicationInfo(pkg,0);
            if (!app.enabled) return "disabled";
            return packageIntent(pkg) == null ? "no-accessible-launcher" : "available";
        } catch (PackageManager.NameNotFoundException e) { return "not-installed"; }
        catch (Exception e) { return "unavailable"; }
    }
    private Intent packageIntent(String pkg) throws PackageManager.NameNotFoundException {
        if (pkg == null || pkg.length() == 0) return null;
        PackageManager pm = context.getPackageManager();
        if (!pm.getApplicationInfo(pkg,0).enabled) return null;
        Intent intent = pm.getLaunchIntentForPackage(pkg);
        if (intent == null) return null;
        ResolveInfo resolved = pm.resolveActivity(intent,0);
        if (resolved == null || !usable(resolved.activityInfo) || !pkg.equals(resolved.activityInfo.packageName)) return null;
        // Pin the checked component; do not let implicit resolution pick a different application.
        return new Intent(intent).setComponent(new ComponentName(pkg,resolved.activityInfo.name));
    }
    private boolean usable(ActivityInfo info) {
        return info != null && info.enabled && info.applicationInfo != null && info.applicationInfo.enabled
            && info.exported && (info.permission == null || info.permission.length() == 0
                || context.checkSelfPermission(info.permission) == PackageManager.PERMISSION_GRANTED);
    }
    public boolean launchOfficial(String type) {
        for (String pkg : new OfficialCatalog(context).applicationPackages(type)) {
            if (launchPackage(pkg)) return true;
        }
        return false;
    }
    public boolean launchOfficialAvm() {
        // Exact component in official CarUtils. Never enable it or substitute the PAC camera.
        ComponentName c=new ComponentName("com.ecarx.parking","com.ecarx.park2.MainAvmActivity");
        try{
            android.content.pm.ActivityInfo info=context.getPackageManager().getActivityInfo(c,0);
            if(!usable(info))return false;
            context.startActivity(new Intent(Intent.ACTION_MAIN).setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;
        }catch(Exception e){return false;}
    }
}
