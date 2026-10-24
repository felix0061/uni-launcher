package xyz.i4o.uni.launcher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.os.Build;
import android.os.Bundle;
import android.widget.Toast;
import org.json.JSONObject;
import org.json.JSONArray;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
import xyz.i4o.uni.launcher.core.ClimateState;
import xyz.i4o.uni.launcher.core.CommandPolicy;
import xyz.i4o.uni.launcher.integration.*;
import xyz.i4o.uni.launcher.platform.EmbeddedNavigationFactory;

/** Flutter renderer, sharing the verified native integration classes with the baseline. */
public final class MainActivity extends FlutterActivity {
    private SharedPreferences prefs;
    private NavigationChrome chrome;
    private AppRepository apps;
    private OfficialCatalog catalog;
    private MediaAdapter media;
    private VehicleTelemetry vehicle;
    private NavigationApps navigation;
    private EmbeddedNavigationFactory mapFactory;
    private JSONArray installed=new JSONArray();
    private final ClimateState simulator=new ClimateState();
    private String cached="{}";
    private boolean demoPlaying=true;
    private int demoTrack=0;
    private long demoPositionMs=0,demoSampleAt=android.os.SystemClock.elapsedRealtime();
    private EventChannel.EventSink sink;
    private MethodChannel channel;
    private final BroadcastReceiver packages=new BroadcastReceiver(){public void onReceive(Context c,Intent i){installed=apps.refresh();publish();}};
    @Override public void configureFlutterEngine(FlutterEngine engine){
        super.configureFlutterEngine(engine);
        mapFactory=new EmbeddedNavigationFactory(this,engine.getDartExecutor().getBinaryMessenger());
        engine.getPlatformViewsController().getRegistry().registerViewFactory("xyz.i4o.uni.launcher/navigation",mapFactory);
        channel=new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/platform");
        channel.setMethodCallHandler((call,result)->{
            try{
                if("snapshot".equals(call.method)){if(prefs!=null)updateSnapshot();result.success(cached);}
                else if("saveDesign".equals(call.method))result.success(saveDesign((String)call.arguments));
                else if("action".equals(call.method)){String raw=(String)call.arguments;if(raw==null||raw.length()>8192){result.error("invalid","Invalid request",null);return;}handle(new JSONObject(raw));result.success(null);}
                else result.notImplemented();
            }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
        });
        new EventChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/events").setStreamHandler(new EventChannel.StreamHandler(){
            public void onListen(Object args,EventChannel.EventSink events){sink=events;if(prefs!=null)publish();}
            public void onCancel(Object args){sink=null;}
        });
    }
    @Override protected void onCreate(Bundle saved){
        super.onCreate(saved);getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN);
        prefs=getSharedPreferences("launcher",0);chrome=new NavigationChrome(this,prefs);
        if(!prefs.contains("demo"))prefs.edit().putBoolean("demo",Build.FINGERPRINT.contains("generic")||Build.MODEL.contains("sdk_gphone")||Build.MODEL.contains("Android SDK")).apply();
        apps=new AppRepository(this);catalog=new OfficialCatalog(this);vehicle=new VehicleTelemetry(this,()->publish());navigation=new NavigationApps(this,prefs);
        media=new MediaAdapter(this,()->publish());media.setPreferredPackage(prefs.getString("mediaPackage","auto"));installed=apps.refresh();
        IntentFilter filter=new IntentFilter();filter.addAction(Intent.ACTION_PACKAGE_ADDED);filter.addAction(Intent.ACTION_PACKAGE_REMOVED);filter.addAction(Intent.ACTION_PACKAGE_CHANGED);filter.addDataScheme("package");registerReceiver(packages,filter);
        publish();
    }
    private long demoPosition(){return demoPositionMs+(demoPlaying?Math.max(0,android.os.SystemClock.elapsedRealtime()-demoSampleAt):0);}
    private void updateSnapshot(){
        JSONObject state=new JSONObject();try{
            JSONObject climate=new JSONObject().put("left",simulator.left).put("right",simulator.right).put("fan",simulator.fan).put("power",simulator.power)
                .put("auto",simulator.auto).put("ac",simulator.ac).put("sync",simulator.sync).put("recirc",simulator.recirc)
                .put("driverHeat",simulator.driverHeat).put("driverVent",simulator.driverVent).put("passengerHeat",simulator.passengerHeat);
            JSONObject telemetry=vehicle.snapshot();
            if(!prefs.getBoolean("demo",false))climate=telemetry.optJSONObject("climate")==null?new JSONObject():telemetry.getJSONObject("climate");
            state.put("navigation",navigation.snapshot()).put("integrationPreferences",new JSONObject().put("mediaPackage",prefs.getString("mediaPackage","auto"))) ;
            state.put("demo",prefs.getBoolean("demo",false)).put("hideNavigation",prefs.getBoolean("hideNavigation",false))
                .put("globalNavigation",prefs.getBoolean("globalNavigation",false))
                .put("globalNavigationGranted",checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS")==android.content.pm.PackageManager.PERMISSION_GRANTED)
                .put("dark",(getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES)
                .put("apps",installed).put("climate",climate).put("vehicle",vehicle.snapshot()).put("media",media.snapshot()).put("version","0.4.0-flutter");
            state.put("savedDesign",prefs.getString("savedDesign", ""));
            if(prefs.getBoolean("demo",false))state.put("media",new JSONObject().put("available",true).put("playing",demoPlaying)
                .put("title",demoTrack%2==0?"向海而行":"山海之间").put("artist",demoTrack%2==0?"Coastline":"Northbound").put("collection","晨间驾驶歌单").put("source","simulator").put("canNext",true).put("canPrevious",true).put("canToggle",true)
                .put("lyrics","[00:00.00]晨光沿着海岸慢慢亮起\n[00:03.00]风把远方带进了呼吸\n[00:06.00]穿过山与海的交界\n[00:09.00]每一程都有新的风景\n[00:12.00]跟着潮声向前去\n[00:15.00]让今天从容开启")
                .put("lyricsSource","demo").put("durationMs",258000).put("positionMs",demoPosition()).put("positionKnown",true)
                .put("sampledAtMs",System.currentTimeMillis()).put("speed",1));
        }catch(Exception e){android.util.Log.e("UniState","Snapshot failed",e);}cached=state.toString();
    }
        private boolean saveDesign(String raw){
            if(raw==null||raw.length()>65536)return false;
            try{
                JSONObject data=new JSONObject(raw);JSONObject p=data.getJSONObject("preferences");
                if(data.optInt("version")!=4||!p.optString("custom").matches("#[0-9a-fA-F]{6}"))return false;
                String mode=p.optString("mode"),palette=p.optString("palette");
                String effect=p.optString("pageTransition","none");
                if(!"none".equals(effect)&&!"fade".equals(effect)&&!"slide".equals(effect))return false;
                if(!"system".equals(mode)&&!"dark".equals(mode)&&!"light".equals(mode))return false;
                if(!"mint".equals(palette)&&!"blue".equals(palette)&&!"violet".equals(palette)&&!"amber".equals(palette)&&!"rose".equals(palette)&&!"custom".equals(palette))return false;
                int radius=p.getInt("radius"),pages=data.getInt("pageCount");
                if(radius<0||radius>40||pages<1||pages>20)return false;
                JSONArray cards=data.getJSONArray("cards");if(cards.length()>200)return false;
                for(int i=0;i<cards.length();i++){
                    JSONObject c=cards.getJSONObject(i);int x=c.getInt("x"),y=c.getInt("y"),w=c.getInt("w"),h=c.getInt("h"),page=c.getInt("page");
                    if(x<0||y<0||w<1||h<1||x+w>12||y+h>6||page<0||page>=pages)return false;
                }
                return prefs.edit().putString("savedDesign",raw).commit();
            }catch(Exception e){return false;}
        }
    private void handle(JSONObject request)throws Exception{
        String action=request.optString("action"),value=request.optString("value");
        if("hide-navigation".equals(action)||"global-navigation".equals(action)||"demo-mode".equals(action)){
            if("global-navigation".equals(action)&&request.optBoolean("enabled",false)&&checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS")!=android.content.pm.PackageManager.PERMISSION_GRANTED){toast("全局隐藏需要系统授权，当前窗口隐藏仍可使用");return;}
            String key="hide-navigation".equals(action)?"hideNavigation":"global-navigation".equals(action)?"globalNavigation":"demo";
            prefs.edit().putBoolean(key,request.optBoolean("enabled",false)).commit();chrome.apply();publish();return;
        }
        if("select-player".equals(action)||"select-navigation".equals(action)){
            if(!"auto".equals(value)&&getPackageManager().getLaunchIntentForPackage(value)==null){toast("所选应用未安装或不可启动");return;}
            String key="select-player".equals(action)?"mediaPackage":"navigationPackage";
            prefs.edit().putString(key,value).commit();
            if("select-player".equals(action))media.setPreferredPackage(value);
            publish();return;
        }
        if("embed-navigation".equals(action)){prefs.edit().putBoolean("embedNavigation",request.optBoolean("enabled",true)).commit();publish();return;}
        if("launch-navigation".equals(action)){if(!apps.launchPackage(navigation.selected()))toast("请选择已安装的导航应用");return;}
        if("launch-player".equals(action)){
            String selected=prefs.getString("mediaPackage","auto");
            if("auto".equals(selected))selected=media.snapshot().optString("source","ecarx.xsf.mediacenter");
            if(!apps.launchPackage(selected))toast("请选择已安装的音乐播放器");return;
        }
        if("refresh".equals(action)){installed=apps.refresh();media.start();vehicle.stop();vehicle.start();publish();return;}
        if("launch-app".equals(action)){if(!apps.launch(value))toast("应用未安装或无法启动");return;}
        if("media-access".equals(action)){try{startActivity(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"));}catch(Exception e){toast("系统没有提供媒体授权入口");}return;}
        if("official-widget".equals(action)){
            if(catalog.providers(value).isEmpty()){toast("没有对应的原厂卡片");return;}
            startActivity(new Intent(this,OfficialWidgetActivity.class).putExtra("type",value));return;
        }
        if("open-official".equals(action)){
            if("camera".equals(value)){if(!apps.launchOfficialAvm())toast("原车 360 入口未安装、未启用或不可访问");return;}
            if(!apps.launchPackage(catalog.packageFor(value)))toast("此设备未安装对应原车应用");return;
        }
        if(CommandPolicy.isClimateAction(action)){
            boolean demo=prefs.getBoolean("demo",false);
            boolean ok=demo?simulator.apply(action,request.optString("zone"),value):vehicle.command(action,request.optString("zone"),value);
            if(!ok)toast("尚未连接空调，可从空调面板打开原车应用");publish();return;
        }
        if("toggle-play".equals(action)||"previous".equals(action)||"next".equals(action)){
            if(prefs.getBoolean("demo",false)){if("toggle-play".equals(action)){demoPositionMs=demoPosition();demoPlaying=!demoPlaying;}
                else {demoTrack+="previous".equals(action)?-1:1;demoPositionMs=0;}
                demoSampleAt=android.os.SystemClock.elapsedRealtime();publish();return;}
            if(!media.command(action))toast("当前音源不支持此操作，或尚未授权媒体访问");publish();
        }
    }

    private void publish(){if(prefs==null||media==null||vehicle==null)return;updateSnapshot();if(sink!=null)sink.success(cached);}
    private void toast(String text){Toast.makeText(this,text,Toast.LENGTH_SHORT).show();}
    @Override protected void onStart(){super.onStart();if(media!=null){media.start();vehicle.start();if(mapFactory!=null)mapFactory.setVisible(true);publish();}}
    @Override protected void onResume(){super.onResume();if(chrome!=null){chrome.apply();publish();}}
    @Override protected void onStop(){if(media!=null){media.stop();vehicle.stop();}if(mapFactory!=null)mapFactory.setVisible(false);super.onStop();}
    @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(focus&&chrome!=null)chrome.apply();}
    @Override public void onConfigurationChanged(Configuration c){super.onConfigurationChanged(c);publish();}
    @Override protected void onNewIntent(Intent intent){super.onNewIntent(intent);if(channel!=null)channel.invokeMethod("home",null);}
    @Override protected void onDestroy(){unregisterReceiver(packages);if(mapFactory!=null)mapFactory.close();media.stop();vehicle.close();if(channel!=null)channel.setMethodCallHandler(null);sink=null;super.onDestroy();}
}
