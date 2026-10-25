package xyz.i4o.uni.launcher;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.widget.Toast;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import org.json.JSONObject;
import xyz.i4o.uni.launcher.integration.NavigationChrome;
import xyz.i4o.uni.launcher.overlay.SystemNavigationPolicy;
import xyz.i4o.uni.launcher.platform.EmbeddedNavigationFactory;

/** Home window and Flutter bridge; shared integrations live in LauncherRuntime. */
public final class MainActivity extends FlutterActivity {
    private static java.lang.ref.WeakReference<MainActivity> active=new java.lang.ref.WeakReference<>(null);
    private LauncherRuntime rt;
    private NavigationChrome chrome;
    private EmbeddedNavigationFactory mapFactory;
    private String cached="{}";
    private JSONObject flutterViewport=new JSONObject();
    private int reservedBottomPx;
    private boolean initialSettings;
    private EventChannel.EventSink sink;
    private EventChannel events;
    private MethodChannel channel;

    @Override public void configureFlutterEngine(FlutterEngine engine){
        super.configureFlutterEngine(engine);
        if(rt==null)rt=LauncherRuntime.get(this);
        mapFactory=new EmbeddedNavigationFactory(this,engine.getDartExecutor().getBinaryMessenger());
        engine.getPlatformViewsController().getRegistry().registerViewFactory("xyz.i4o.uni.launcher/navigation",mapFactory);
        channel=new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/platform");
        channel.setMethodCallHandler((call,result)->{
            try{
                if("snapshot".equals(call.method)){
                    updateSnapshot();result.success(cached);
                    // Bootstrap consumes the fallback once. Events must not consume
                    // it before Dart has installed its method handler.
                    initialSettings=false;
                }
                else if("saveDesign".equals(call.method))result.success(rt.saveDesign((String)call.arguments));
                else if("viewport".equals(call.method)){flutterViewport=new JSONObject((String)call.arguments);result.success(null);}
                else if("action".equals(call.method)){
                    String raw=(String)call.arguments;
                    if(raw==null||raw.length()>8192){result.error("invalid","Invalid request",null);return;}
                    handle(new JSONObject(raw));result.success(null);
                }
                else result.notImplemented();
            }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
        });
        events=new EventChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/events");
        events.setStreamHandler(new EventChannel.StreamHandler(){
            public void onListen(Object args,EventChannel.EventSink events){sink=events;publish();}
            public void onCancel(Object args){sink=null;}
        });
    }

    @Override protected void onCreate(Bundle saved){
        rt=LauncherRuntime.get(this);
        initialSettings=getIntent()!=null&&getIntent().getBooleanExtra("uniSettings",false);
        super.onCreate(saved);getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        // Android can create a separate HOME task after a regular app launch.
        // Keep one host/engine so hidden instances cannot retain map displays.
        MainActivity previous=active.get();active=new java.lang.ref.WeakReference<>(this);
        if(previous!=null&&previous!=this&&!previous.isFinishing())previous.finish();
        chrome=new NavigationChrome(this,rt.prefs());
        findViewById(android.R.id.content).addOnLayoutChangeListener((v,l,t,r,b,ol,ot,orr,ob)->{
            if(r-l!=orr-ol||b-t!=ob-ot)v.post(this::publish);
        });
        dispatchIntent(getIntent());publish();
    }

    private void updateSnapshot(){
        JSONObject state=rt.snapshot();
        try{
            View content=findViewById(android.R.id.content),decor=getWindow().getDecorView();
            WindowInsets insets=decor.getRootWindowInsets();
            boolean alreadyInset=content!=null&&insets!=null&&insets.getSystemWindowInsetBottom()>0&&content.getHeight()>0
                &&content.getHeight()+insets.getSystemWindowInsetBottom()<=decor.getHeight()+1;
            state.put("contentReservesSystemBars",alreadyInset);
            // This firmware sometimes expands content behind its persistent
            // 136px OEM bar after a virtual-display focus change. Stable insets
            // retain the reservation even when content/system insets become 0.
            if(insets!=null&&insets.getStableInsetBottom()>0)reservedBottomPx=insets.getStableInsetBottom();
            if(content!=null&&content.getHeight()>0){
                int usable=content.getHeight();
                if(!rt.prefs().getBoolean("hideNavigation",false)&&!rt.prefs().getBoolean("systemNavigationHidden",false)
                    &&decor.getHeight()>reservedBottomPx)
                    usable=Math.min(usable,decor.getHeight()-reservedBottomPx);
                state.put("contentHeightPx",content.getHeight()).put("viewportHeightPx",usable).put("reservedBottomPx",reservedBottomPx);
            }
            state.put("initialSettings",initialSettings)
                .put("systemNavigationHidden",rt.prefs().getBoolean("systemNavigationHidden",false))
                .put("systemNavigationGranted",SystemNavigationPolicy.granted(this))
                .put("globalDock",GlobalDockService.snapshot(this));
        }catch(Exception e){android.util.Log.e("UniState","Window snapshot failed",e);}
        cached=state.toString();
    }

    private void handle(JSONObject request)throws Exception{
        if(GlobalDockService.handleCommand(this,request)){
            if(chrome!=null)chrome.apply();
            publish();return;
        }
        String action=request.optString("action");
        if("hide-navigation".equals(action)||"global-navigation".equals(action)){
            if("global-navigation".equals(action)&&request.optBoolean("enabled",false)
                &&checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS")!=PackageManager.PERMISSION_GRANTED){
                toast("全局隐藏需要系统授权，当前窗口隐藏仍可使用");return;
            }
            String key="hide-navigation".equals(action)?"hideNavigation":"globalNavigation";
            rt.prefs().edit().putBoolean(key,request.optBoolean("enabled",false)).commit();
            chrome.apply();rt.publish();return;
        }
        rt.handle(request);
    }

    private void publish(){if(rt==null)return;updateSnapshot();if(sink!=null)sink.success(cached);}

    @Override public void dump(String prefix,java.io.FileDescriptor fd,java.io.PrintWriter writer,String[] args){
        if(args!=null)for(String arg:args)if("--uni-state".equals(arg)){
            // dumpsys is already restricted to Android DUMP callers. Exclude
            // artwork, song text and app icons from this read-only diagnostic.
            try{
                updateSnapshot();JSONObject full=new JSONObject(cached),report=new JSONObject();
                for(String key:new String[]{"version","demo","hideNavigation","systemNavigationHidden","systemNavigationGranted","contentReservesSystemBars","contentHeightPx","viewportHeightPx","reservedBottomPx","navigation","vehicle"})report.put(key,full.opt(key));
                JSONObject m=full.optJSONObject("media"),safe=new JSONObject();
                if(m!=null)for(String key:new String[]{"available","authorized","playing","source","preferredPackage","sessions","reason","canToggle","canNext","canPrevious","canSeek","controlSource","lyricsSource","durationMs","positionMs"})safe.put(key,m.opt(key));
                if(m!=null)safe.put("lyricsAvailable",!m.optString("lyrics").isEmpty()).put("artworkAvailable",!m.optString("artwork").isEmpty());
                report.put("media",safe).put("flutterViewport",flutterViewport).put("globalDock",GlobalDockService.snapshot(this));
                if(mapFactory!=null)report.put("mapViews",mapFactory.snapshot());
                writer.println("UNI_STATE="+report.toString());
            }catch(Exception e){writer.println("UNI_STATE_UNAVAILABLE");}return;
        }
        super.dump(prefix,fd,writer,args);
    }

    private void toast(String text){Toast.makeText(this,text,Toast.LENGTH_SHORT).show();}

    @Override protected void onStart(){
        super.onStart();rt.setHomeVisible(true);rt.addListener(this,this::publish);
        if(mapFactory!=null)mapFactory.setVisible(true);
        publish();
    }

    @Override protected void onResume(){
        super.onResume();if(chrome!=null)chrome.apply();
        GlobalDockService.ensureStarted(this);publish();
    }

    @Override protected void onStop(){
        if(rt!=null){
            // A superseded HOME activity must not hide its replacement's dock.
            if(active.get()==this)rt.setHomeVisible(false);
            rt.removeListener(this);
        }
        if(mapFactory!=null)mapFactory.setVisible(false);
        super.onStop();
    }

    @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(focus&&chrome!=null)chrome.apply();}
    @Override public void onConfigurationChanged(Configuration c){super.onConfigurationChanged(c);publish();}

    private void dispatchIntent(Intent intent){
        if(channel!=null)channel.invokeMethod(intent!=null&&intent.getBooleanExtra("uniSettings",false)?"open-settings":"home",null);
    }

    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);setIntent(intent);
        initialSettings=intent!=null&&intent.getBooleanExtra("uniSettings",false);
        dispatchIntent(intent);publish();
    }

    @Override protected void onDestroy(){
        if(rt!=null)rt.removeListener(this);
        if(mapFactory!=null)mapFactory.close();
        if(channel!=null)channel.setMethodCallHandler(null);
        if(events!=null)events.setStreamHandler(null);
        sink=null;if(active.get()==this)active.clear();
        super.onDestroy();
    }
}
