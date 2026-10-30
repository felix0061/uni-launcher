package xyz.i4o.uni.launcher.integration;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;

/** 地名 → 坐标（WGS-84）。
 *
 * 高德的 androidauto://route / navi 都必须给 lat/lon，只给地名只会打开地图不规划路线。
 * 这里用 OpenStreetMap 的 Nominatim 做免费地理编码（不需要 key，车机有网就能用），
 * 结果按地名缓存，避免每说一次都联网。
 *
 * 注意：返回的是 WGS-84，高德要 GCJ-02，所以调用方**必须**带 dev=1
 * （dev=1 的语义就是「坐标未加密，请服务端做国测加密」）。 */
final class NavGeocoder {
    private static final String TAG = "UniNavigation";
    private static final Map<String, double[]> CACHE = new HashMap<>();
    private static android.content.SharedPreferences prefs;
    /** 天地图 key：设置页可覆盖，这里给个默认值 */
    private static final String DEFAULT_TK = "79689cf212a75df9522c57c7ff94b1f6";

    private NavGeocoder() {}

    private static double[] tianditu(String key, String tk) {
        if (tk == null || tk.isEmpty()) return null;
        HttpURLConnection c = null;
        try {
            // 正向查地名只能用 v2/search（geocoder 是逆地理，只吃 lon/lat）
            // mapBound 必须给，全国范围 73,3,136,54；不给就一条都搜不到
            String post = "{\"keyWord\":\"" + key.replace("\"", "") + "\",\"level\":12,"
                    + "\"mapBound\":\"73,3,136,54\",\"queryType\":1,\"start\":0,\"count\":5}";
            String url = "https://api.tianditu.gov.cn/v2/search?postStr="
                    + java.net.URLEncoder.encode(post, "UTF-8") + "&type=query&tk=" + tk;
            c = (HttpURLConnection) new URL(url).openConnection();
            c.setConnectTimeout(2500); c.setReadTimeout(2500);
            if (c.getResponseCode() != 200) return null;
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(c.getInputStream(), "UTF-8"))) {
                String line; while ((line = r.readLine()) != null) sb.append(line);
            }
            JSONObject o = new JSONObject(sb.toString());
            JSONArray pois = o.optJSONArray("pois");
            if (pois == null || pois.length() == 0) { Log.w(TAG, "tianditu no pois for " + key); return null; }
            JSONObject p0 = pois.optJSONObject(0);
            String[] ll = p0 == null ? new String[0] : p0.optString("lonlat", "").split(",");
            if (ll.length != 2) return null;
            double lon = Double.parseDouble(ll[0].trim());
            double lat = Double.parseDouble(ll[1].trim());
            double[] out = {lat, lon};
            synchronized (CACHE) { CACHE.put(key, out); }
            if (prefs != null) prefs.edit().putString("geo:" + key, lat + "," + lon).apply();
            Log.i(TAG, "tianditu " + p0.optString("name", key) + " -> " + lat + "," + lon);
            return out;
        } catch (Throwable e) { Log.w(TAG, "tianditu failed: " + e); return null; }
        finally { if (c != null) try { c.disconnect(); } catch (Throwable ignored) {} }
    }

    /** WGS-84 → GCJ-02（火星坐标）。国内偏移 300~500m，必须自己转，
     *  高德车机版对 dev=1 并不做这个转换，直接传 WGS-84 会偏到隔壁小区。 */
    static double[] wgsToGcj(double lat, double lon) {
        final double a = 6378245.0, ee = 0.00669342162296594323;
        if (lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271) return new double[]{lat, lon};
        double dLat = transformLat(lon - 105.0, lat - 35.0);
        double dLon = transformLon(lon - 105.0, lat - 35.0);
        double radLat = lat / 180.0 * Math.PI;
        double magic = Math.sin(radLat);
        magic = 1 - ee * magic * magic;
        double sqrtMagic = Math.sqrt(magic);
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI);
        dLon = (dLon * 180.0) / (a / sqrtMagic * Math.cos(radLat) * Math.PI);
        return new double[]{lat + dLat, lon + dLon};
    }

    private static double transformLat(double x, double y) {
        double r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
        r += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
        r += (20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin(y / 3.0 * Math.PI)) * 2.0 / 3.0;
        r += (160.0 * Math.sin(y / 12.0 * Math.PI) + 320 * Math.sin(y * Math.PI / 30.0)) * 2.0 / 3.0;
        return r;
    }

    private static double transformLon(double x, double y) {
        double r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
        r += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
        r += (20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin(x / 3.0 * Math.PI)) * 2.0 / 3.0;
        r += (150.0 * Math.sin(x / 12.0 * Math.PI) + 300.0 * Math.sin(x / 30.0 * Math.PI)) * 2.0 / 3.0;
        return r;
    }
    /** 粗略校验：结果名里至少要包含查询词的核心（去掉行政区后缀后的前 3 个字）。 */
    private static boolean plausible(String query, String shownName) {
        if (shownName == null || shownName.isEmpty()) return true;
        String core = query.replaceAll("[市县区镇乡村省]$", "");
        if (core.length() > 3) core = core.substring(0, 3);
        if (core.isEmpty()) return true;
        return shownName.contains(core) || shownName.contains(query);
    }
    /** 返回 {lat, lon}，失败返回 null（调用方退回关键词导航）。 */
    static void attach(android.content.Context ctx, android.content.SharedPreferences p) {
        prefs = p;
        if (ctx == null) return;
    }

    static double[] locate(String name) {
        if (name == null || name.trim().isEmpty()) return null;
        String key = name.trim();
        synchronized (CACHE) {
            double[] hit = CACHE.get(key);
            if (hit != null) return hit;
        }
        // 先看磁盘缓存
        if (prefs != null) {
            String saved = prefs.getString("geo:" + key, "");
            if (saved != null && saved.contains(",")) {
                try {
                    String[] parts = saved.split(",");
                    double[] out = {Double.parseDouble(parts[0]), Double.parseDouble(parts[1])};
                    synchronized (CACHE) { CACHE.put(key, out); }
                    Log.i(TAG, "geocode(cache) " + key + " -> " + saved);
                    return out;
                } catch (Exception ignored) {}
            }
        }
        String tk = prefs == null ? DEFAULT_TK : prefs.getString("tiandituKey", DEFAULT_TK);
        double[] td = tianditu(key, tk);
        if (td != null) return td;
        HttpURLConnection conn = null;
        try {
            String q = URLEncoder.encode(key, "UTF-8");
            URL url = new URL("https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" + q);
            conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(2500);
            conn.setReadTimeout(2500);
            conn.setRequestProperty("User-Agent", "uni-launcher/1.0");
            if (conn.getResponseCode() != 200) return null;
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"))) {
                String line;
                while ((line = r.readLine()) != null) sb.append(line);
            }
            JSONArray arr = new JSONArray(sb.toString());
            if (arr.length() == 0) return null;
            JSONObject o = arr.getJSONObject(0);
            // 校验命中是否真的是我们要的地方：OSM 中文 POI 稀疏，
            // 「临泉市政府」会命中「土陂乡人民政府」这类同名尾巴的错误结果。
            // 要求 display_name 里包含查询词的主要部分（去掉「市/县/区」这类后缀比对）。
            String shown = o.optString("display_name", "");
            if (!plausible(key, shown)) {
                Log.w(TAG, "geocode 结果不可信，丢弃：" + key + " -> " + shown);
                return null;
            }
            double lat = Double.parseDouble(o.optString("lat", ""));
            double lon = Double.parseDouble(o.optString("lon", ""));
            double[] out = {lat, lon};
            synchronized (CACHE) { CACHE.put(key, out); }
            if (prefs != null) prefs.edit().putString("geo:" + key, lat + "," + lon).apply();
            Log.i(TAG, "geocode " + key + " -> " + lat + "," + lon);
            return out;
        } catch (Throwable e) {
            Log.w(TAG, "geocode failed for " + key + ": " + e);
            return null;
        } finally {
            if (conn != null) try { conn.disconnect(); } catch (Throwable ignored) {}
        }
    }
}
