package xyz.i4o.uni.launcher;

import android.app.*;
import android.content.*;
import android.graphics.PixelFormat;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.view.*;
import org.json.JSONObject;
import io.flutter.FlutterInjector;
import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.*;
import xyz.i4o.uni.launcher.overlay.SystemNavigationPolicy;
import xyz.i4o.uni.launcher.overlay.OverscanPolicy;

/** A small, touch-bounded global window; expanded only while a dock panel is open.
 * One service/engine, the original Flutter BottomDock, and one shared native runtime.
 * Hidden on the launcher to avoid duplicate bars. No Accessibility service required.
 */
public final class GlobalDockService extends Service {
    private static final String STOP="xyz.i4o.uni.launcher.STOP_DOCK", RESTORE="xyz.i4o.uni.launcher.RESTORE_NAV";
    private static GlobalDockService active;
    private LauncherRuntime runtime;
    private WindowManager windows;
    private WindowManager.LayoutParams layout;
    private FlutterEngine engine;
    private FlutterView view;
    private MethodChannel methods;
    private EventChannel events;
    private EventChannel.EventSink sink;
    private boolean expanded, visible, cameraSuspended;
    private int bottomInset;
    private long expandedAt;
    private final android.os.Handler main=new android.os.Handler(android.os.Looper.getMainLooper());
    private int appliedX=-1, appliedY=-1, appliedW=-1, appliedH=-1;

    public static void ensureStarted(Context c){
        SharedPreferences p=c.getSharedPreferences("launcher",0);
        if(!p.getBoolean("globalDockEnabled",false)||!Settings.canDrawOverlays(c))return;
        try{Intent i=new Intent(c,GlobalDockService.class);if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i);else c.startService(i);}
        catch(RuntimeException e){android.util.Log.w("UniDock","Unable to start global dock",e);}
    }
    public static JSONObject snapshot(Context c){
        JSONObject j=new JSONObject();try{
            GlobalDockService s=active;
            j.put("enabled",c.getSharedPreferences("launcher",0).getBoolean("globalDockEnabled",false))
             .put("allowed",Settings.canDrawOverlays(c)).put("running",s!=null&&s.view!=null)
             .put("visible",s!=null&&s.visible).put("expanded",s!=null&&s.expanded)
             .put("rendering",s!=null&&s.engine!=null&&s.engine.getRenderer().isDisplayingFlutterUi());
            if(s!=null&&s.layout!=null)j.put("width",s.layout.width).put("height",s.layout.height).put("x",s.layout.x).put("y",s.layout.y);
        }catch(Exception ignored){}return j;
    }
    public static boolean handleCommand(Context c,JSONObject r){
        String a=r.optString("action");SharedPreferences p=c.getSharedPreferences("launcher",0);
        LauncherRuntime rt=LauncherRuntime.get(c);
        if("global-dock".equals(a)){
            boolean on=r.optBoolean("enabled");p.edit().putBoolean("globalDockEnabled",on).commit();
            if(on){
                if(!Settings.canDrawOverlays(c)){try{c.startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:"+c.getPackageName())).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));}catch(RuntimeException e){toast(c,"请在系统设置允许 UNI 显示在其他应用上层");}}
                else ensureStarted(c);
            }else{
                c.stopService(new Intent(c,GlobalDockService.class));
                disableBarModifications(c,p);
            }
            rt.publish();return true;
        }
        if("system-navigation-hidden".equals(a)){
            if(!SystemNavigationPolicy.setHidden(c,p,r.optBoolean("enabled")))toast(c,"当前系统未允许管理原有导航栏");
            if(active!=null)active.update();rt.publish();return true;
        }
        if("show-home".equals(a)||"show-desktop-settings".equals(a)){
            if(active!=null){active.setExpanded(false);active.cameraSuspended=false;}
            c.startActivity(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                .putExtra("uniSettings","show-desktop-settings".equals(a)));return true;
        }
        if("open-official".equals(a)&&"camera".equals(r.optString("value"))&&active!=null){active.cameraSuspended=true;active.update();}
        return false;
    }
    /** Global dock requires hiding the OEM bar (immersive.full — XCSystemUI
     * ignores immersive.navigation) and reserving 96px via display overscan so
     * external apps end above our dock instead of underneath it. */
    private static void enableBarModifications(Context c,SharedPreferences p){
        SystemNavigationPolicy.setHidden(c,p,true);
        if(!OverscanPolicy.apply(c,p,true))android.util.Log.w("UniDock","wm overscan unavailable; overlay covers external app bottoms");
    }
    private static void disableBarModifications(Context c,SharedPreferences p){
        OverscanPolicy.apply(c,p,false);
        SystemNavigationPolicy.setHidden(c,p,false);
    }
    private static void stopAndRestore(Context c){
        SharedPreferences p=c.getSharedPreferences("launcher",0);
        p.edit().putBoolean("globalDockEnabled",false).commit();
        c.stopService(new Intent(c,GlobalDockService.class));
        disableBarModifications(c,p);
    }
    /** A refused camera launch must not leave the dock hidden on the next app. */
    public static void resumeAfterCameraLaunchFailure(){
        GlobalDockService s=active;
        if(s!=null&&s.cameraSuspended){s.cameraSuspended=false;s.update();}
    }
    private static void toast(Context c,String text){android.widget.Toast.makeText(c,text,android.widget.Toast.LENGTH_SHORT).show();}
    @Override public void onCreate(){
        super.onCreate();active=this;runtime=LauncherRuntime.get(this);
        if(!Settings.canDrawOverlays(this)||!runtime.prefs().getBoolean("globalDockEnabled",false)){stopSelf();return;}
        startForeground(753,notification());
        enableBarModifications(this,runtime.prefs());
        windows=(WindowManager)getSystemService(WINDOW_SERVICE);
        engine=new FlutterEngine(this,null,false);
        methods=new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/platform");
        methods.setMethodCallHandler((call,result)->{
            try{
                if("snapshot".equals(call.method)){result.success(state().toString());}
                else if("saveDesign".equals(call.method)){result.success(runtime.saveDesign((String)call.arguments));}
                else if("overlay-expanded".equals(call.method)){setExpanded(Boolean.TRUE.equals(call.arguments));result.success(null);}
                else if("action".equals(call.method)){
                    String raw=(String)call.arguments;if(raw==null||raw.length()>8192){result.error("invalid","操作无效",null);return;}
                    JSONObject request=new JSONObject(raw);
                    if(!handleCommand(this,request))runtime.handle(request);
                    publish();result.success(null);
                }else result.notImplemented();
            }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
        });
        events=new EventChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/events");
        events.setStreamHandler(new EventChannel.StreamHandler(){
            public void onListen(Object args,EventChannel.EventSink s){sink=s;publish();}
            public void onCancel(Object args){sink=null;}
        });
        installPlatformChannel();
        FlutterTextureView texture=new FlutterTextureView(this);texture.setOpaque(false);
        view=new FlutterView(this,texture){
            @Override public boolean dispatchKeyEvent(KeyEvent event){
                if(event.getKeyCode()==KeyEvent.KEYCODE_BACK&&expanded){
                    if(event.getAction()==KeyEvent.ACTION_UP)engine.getNavigationChannel().popRoute();return true;
                }
                return super.dispatchKeyEvent(event);
            }
        };view.setFocusableInTouchMode(true);view.setVisibility(View.GONE);view.setBackgroundColor(android.graphics.Color.TRANSPARENT);
        view.setOnApplyWindowInsetsListener((v,insets)->{
            int inset=insets.getStableInsetBottom();if(inset>0&&inset!=bottomInset){bottomInset=inset;v.post(this::update);}
            return insets;
        });
        // A launch from anywhere else (OEM voice, notifications, adb) takes
        // window focus; a focusable expanded panel would otherwise pin that
        view.setOnKeyListener((v,key,event)->{
            if(key==KeyEvent.KEYCODE_BACK&&expanded){if(event.getAction()==KeyEvent.ACTION_UP)engine.getNavigationChannel().popRoute();return true;}return false;
        });
        layout=new WindowManager.LayoutParams();layout.type=Build.VERSION.SDK_INT>=26?WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY:WindowManager.LayoutParams.TYPE_PHONE;
        layout.format=PixelFormat.TRANSLUCENT;layout.gravity=Gravity.TOP|Gravity.LEFT;layout.setTitle("UNI Global Dock");
        configureBounds();
        try{windows.addView(view,layout);}catch(RuntimeException e){toast(this,"全局底栏无法显示，请检查悬浮显示授权");stopSelf();return;}
        view.attachToFlutterEngine(engine);
        String bundle=FlutterInjector.instance().flutterLoader().findAppBundlePath();
        engine.getDartExecutor().executeDartEntrypoint(new DartExecutor.DartEntrypoint(bundle,"package:uni_launcher/main.dart","globalDockMain"));
        runtime.addListener(this,this::update);update();
    }
    private JSONObject state(){
        JSONObject j=runtime.snapshot();try{
            j.put("hostMode","global-dock").put("globalDock",snapshot(this))
             .put("systemNavigationHidden",runtime.prefs().getBoolean("systemNavigationHidden",false))
             .put("systemNavigationGranted",SystemNavigationPolicy.granted(this));
        }catch(Exception ignored){}return j;
    }
    private void configureBounds(){
        if(layout==null)return;
        DisplayMetrics real=new DisplayMetrics();windows.getDefaultDisplay().getRealMetrics(real);
        int width=real.widthPixels;
        int bar=Math.round(width*96f/1920f);
        // The dock always owns the physical bottom strip: the OEM bar is hidden
        // and display overscan keeps external app content above it.
        layout.flags=WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            |WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            |WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
        if(!expanded)layout.flags|=WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
        layout.softInputMode=WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;
        layout.width=width;layout.height=expanded?real.heightPixels:bar;
        layout.x=0;layout.y=expanded?0:real.heightPixels-bar;
    }
    private void setExpanded(boolean value){
        if(expanded==value)return;expanded=value;configureBounds();
        if(value)expandedAt=android.os.SystemClock.elapsedRealtime();
        if(value)startForegroundCheck();else main.removeCallbacks(foregroundCheck);
        if(view!=null&&view.getParent()!=null){windows.updateViewLayout(view,layout);if(value)view.requestFocus();}
        publish();
    }
    /** Panel must follow the front task: record the top task at expansion and
     * collapse when a different external task replaces it (REAL_GET_TASKS is a
     * signature permission granted to this platform-signed package). */
    private String expandedTopTask;
    private final Runnable foregroundCheck=this::checkForegroundTask;
    private void startForegroundCheck(){
        expandedTopTask=topTaskPackage();
        main.removeCallbacks(foregroundCheck);
        main.postDelayed(foregroundCheck,500);
    }
    private void checkForegroundTask(){
        if(!expanded)return;
        String top=topTaskPackage();
        if(!top.isEmpty()&&!top.equals(getPackageName())&&!top.equals(expandedTopTask)){
            setExpanded(false);
            if(engine!=null)engine.getNavigationChannel().popRoute();
            return;
        }
        main.postDelayed(foregroundCheck,500);
    }
    private String topTaskPackage(){
        try{
            android.app.ActivityManager am=(android.app.ActivityManager)getSystemService(ACTIVITY_SERVICE);
            java.util.List<android.app.ActivityManager.RunningTaskInfo> tasks=am.getRunningTasks(1);
            if(tasks!=null&&!tasks.isEmpty()&&tasks.get(0).topActivity!=null)
                return tasks.get(0).topActivity.getPackageName();
        }catch(Exception ignored){}
        return "";
    }
    private void update(){
        if(view==null)return;
        if(!Settings.canDrawOverlays(this)){stopSelf();return;}
        if(runtime.homeVisible())cameraSuspended=false;
        boolean show=!cameraSuspended;
        configureBounds();
        // Republish storms must not relayout the window (dock jump/flicker).
        if(view.getParent()!=null&&(layout.width!=appliedW||layout.height!=appliedH
                ||layout.x!=appliedX||layout.y!=appliedY)){
            windows.updateViewLayout(view,layout);
            appliedX=layout.x;appliedY=layout.y;appliedW=layout.width;appliedH=layout.height;
        }
        if(visible!=show){
            visible=show;view.setVisibility(show?View.VISIBLE:View.GONE);
            if(show)engine.getLifecycleChannel().appIsResumed();else engine.getLifecycleChannel().appIsPaused();
        }
        publish();
    }
    private void publish(){if(sink!=null)sink.success(state().toString());}
    private Notification notification(){
        NotificationManager n=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        if(Build.VERSION.SDK_INT>=26)n.createNotificationChannel(new NotificationChannel("uni_global_dock","全局底栏",NotificationManager.IMPORTANCE_LOW));
        PendingIntent home=PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,GlobalDockService.class).setAction(STOP),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        PendingIntent restore=PendingIntent.getService(this,2,new Intent(this,GlobalDockService.class).setAction(RESTORE),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b=Build.VERSION.SDK_INT>=26?new Notification.Builder(this,"uni_global_dock"):new Notification.Builder(this);
        return b.setSmallIcon(xyz.i4o.uni.launcher.R.drawable.uni_icon).setContentTitle("UNI 全局底栏")
            .setContentText("跨应用使用首页、空调与音乐控制").setOngoing(true).setContentIntent(home)
            .addAction(0,"关闭全局底栏",stop).addAction(0,"显示系统导航栏",restore).build();
    }
    private void installPlatformChannel(){
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"flutter/platform",JSONMethodCodec.INSTANCE).setMethodCallHandler((call,result)->{
            try{
                ClipboardManager clipboard=(ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
                if("Clipboard.setData".equals(call.method)){JSONObject j=(JSONObject)call.arguments;clipboard.setPrimaryClip(ClipData.newPlainText("UNI",j.optString("text")));result.success(null);}
                else if("Clipboard.getData".equals(call.method)){JSONObject j=new JSONObject();if(clipboard.hasPrimaryClip())j.put("text",clipboard.getPrimaryClip().getItemAt(0).coerceToText(this));result.success(j);}
                else if("Clipboard.hasStrings".equals(call.method)){result.success(new JSONObject().put("value",clipboard.hasPrimaryClip()));}
                else if("SystemNavigator.pop".equals(call.method)){setExpanded(false);result.success(null);}
                else result.success(null);
            }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
        });
    }
    @Override public int onStartCommand(Intent intent,int flags,int id){
        if(view==null)return START_NOT_STICKY;
        if(intent!=null&&(STOP.equals(intent.getAction())||RESTORE.equals(intent.getAction()))){stopAndRestore(this);stopSelf();return START_NOT_STICKY;}
        return START_STICKY;
    }
    @Override public void onConfigurationChanged(android.content.res.Configuration config){super.onConfigurationChanged(config);update();}
    @Override public void onDestroy(){
        if(runtime!=null)runtime.removeListener(this);
        if(view!=null){view.detachFromFlutterEngine();if(view.getParent()!=null)windows.removeViewImmediate(view);view=null;}
        if(methods!=null)methods.setMethodCallHandler(null);sink=null;if(events!=null)events.setStreamHandler(null);
        if(engine!=null){engine.destroy();engine=null;}active=null;
        if(runtime!=null)runtime.publish();super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
    @Override protected void dump(java.io.FileDescriptor fd,java.io.PrintWriter writer,String[] args){try{JSONObject report=snapshot(this),all=runtime.snapshot(),m=all.optJSONObject("media"),safe=new JSONObject();
        if(m!=null)for(String key:new String[]{"source","playing","canToggle","canNext","canPrevious","positionMs","durationMs"})safe.put(key,m.opt(key));
        report.put("media",safe).put("runtimeOwnerCount",all.optInt("runtimeOwnerCount"));writer.println("UNI_GLOBAL_DOCK="+report);
        }catch(Exception e){writer.println("UNI_GLOBAL_DOCK_UNAVAILABLE");}}
}
