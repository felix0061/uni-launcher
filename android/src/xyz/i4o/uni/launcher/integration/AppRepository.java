package xyz.i4o.uni.launcher.integration;

import android.content.Context;
import android.content.Intent;
import android.content.ComponentName;
import android.content.pm.ResolveInfo;
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
        try {context.startActivity(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;}
        catch(Exception e){return false;}
    }
    public boolean launchPackage(String pkg) {
        if(pkg.length()==0)return false;
        Intent i=context.getPackageManager().getLaunchIntentForPackage(pkg);if(i==null)return false;
        try{context.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;}catch(Exception e){return false;}
    }
    public boolean launchOfficialAvm() {
        // Exact component in official CarUtils. Never enable it or substitute the PAC camera.
        ComponentName c=new ComponentName("com.ecarx.parking","com.ecarx.park2.MainAvmActivity");
        try{
            android.content.pm.ActivityInfo info=context.getPackageManager().getActivityInfo(c,0);
            if(!info.enabled||!info.applicationInfo.enabled||!info.exported)return false;
            context.startActivity(new Intent(Intent.ACTION_MAIN).setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;
        }catch(Exception e){return false;}
    }
}
