package xyz.i4o.uni.launcher.integration;

import android.content.ComponentName;
import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/** Generated catalog is the same versioned evidence used by the design, not a second list. */
public final class OfficialCatalog {
    private final JSONObject catalog;
    public OfficialCatalog(Context context) {
        JSONObject loaded = new JSONObject();
        try {
            InputStream in = context.getAssets().open("official-widgets.json");
            ByteArrayOutputStream out = new ByteArrayOutputStream(); byte[] b = new byte[4096]; int n;
            while ((n = in.read(b)) != -1) out.write(b, 0, n);
            in.close(); loaded = new JSONObject(out.toString("UTF-8"));
        } catch (Exception e) { android.util.Log.e("UniCatalog", "Catalog unavailable", e); }
        catalog = loaded;
    }
    public List<ComponentName> providers(String type) {
        List<ComponentName> result = new ArrayList<ComponentName>();
        String normalized = "music".equals(type) ? "media" : "nav".equals(type) ? "navigation" : type;
        JSONArray types = catalog.optJSONArray("types");
        if (types != null) for (int i=0;i<types.length();i++) {
            JSONObject row = types.optJSONObject(i);
            if (row != null && normalized.equals(row.optString("id"))) {
                JSONArray components = row.optJSONArray("providerComponents");
                if (components != null) for (int j=0;j<components.length();j++) {
                    ComponentName c = ComponentName.unflattenFromString(components.optString(j));
                    if(c != null) result.add(c);
                }
            }
        }
        return result;
    }
    public String packageFor(String type) {
        if ("climate".equals(type)) return "com.ecarx.hvac";
        if ("vehicle".equals(type)) return "com.ecarx.xcvehicle";
        if ("settings".equals(type)) return "com.ecarx.settings";
        if ("phone".equals(type)) return "com.ecarx.btphone";
        if ("nav".equals(type)) return "com.autonavi.amapauto";
        List<ComponentName> list = providers(type);
        return list.isEmpty() ? "" : list.get(0).getPackageName();
    }
}
