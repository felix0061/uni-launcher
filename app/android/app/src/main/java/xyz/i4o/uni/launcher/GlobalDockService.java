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
import xyz.i4o.uni.launcher.overlay.WorkspacePolicy;
import xyz.i4o.uni.launcher.overlay.NavigationInsets;
import xyz.i4o.uni.launcher.overlay.EmbeddedTaskWindow;

/** A small, touch-bounded global window; expanded only while a dock panel is open.
 * One persistent dock engine, one lazy reusable panel engine, one native runtime.
 * A separate panel window never changes the dock surface. No Accessibility service required.
 */
public final class GlobalDockService extends Service {
    private static final String STOP="xyz.i4o.uni.launcher.STOP_DOCK", RESTORE="xyz.i4o.uni.launcher.RESTORE_NAV";
    private static GlobalDockService active;
    private LauncherRuntime runtime;
    private WindowManager windows;
    private WorkspacePolicy workspace;
    private OverlayWindow dockWindow, panelWindow;
    private EmbeddedTaskWindow recentsWindow;
    private boolean visible, cameraSuspended, nativeInsets;
    private String panel="";
    private int panelRevision;
    private byte[] panelBackdrop;
    private boolean panelReady;
    private final Handler main=new Handler(Looper.getMainLooper());

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
             .put("allowed",Settings.canDrawOverlays(c)).put("running",s!=null&&s.dockWindow!=null)
             .put("visible",s!=null&&s.visible).put("expanded",s!=null&&!s.panel.isEmpty())
             .put("nativeNavigationInsets",s!=null&&s.nativeInsets)
             .put("workspaceReserved",s!=null&&(s.nativeInsets||s.workspace!=null&&s.workspace.available()))
             .put("workspaceResizes",s==null||s.workspace==null?0:s.workspace.resized())
             .put("panelReady",s!=null&&s.panelReady)
             .put("recentsReady",s!=null&&s.recentsWindow!=null&&s.recentsWindow.ready())
             .put("recentsDisplayId",s==null||s.recentsWindow==null?-1:s.recentsWindow.displayId())
             .put("recentsClearSupported",s!=null&&s.recentsWindow!=null&&s.recentsWindow.clearSupported())
             .put("backdropAvailable",s!=null&&s.panelBackdrop!=null)
             .put("panel",s==null?"":s.panel).put("panelRevision",s==null?0:s.panelRevision)
             .put("rendering",s!=null&&s.dockWindow!=null&&s.dockWindow.engine.getRenderer().isDisplayingFlutterUi());
            if(s!=null&&s.dockWindow!=null){
                WindowManager.LayoutParams b=s.dockWindow.bounds;
                int[] location=new int[2];s.dockWindow.view.getLocationOnScreen(location);
                j.put("width",b.width).put("height",b.height).put("x",b.x).put("y",b.y)
                 .put("screenY",location[1]).put("viewHeight",s.dockWindow.view.getHeight())
                 .put("dockRelayouts",s.dockWindow.relayouts);
                if(s.panelWindow!=null)j.put("panelHeight",s.panelWindow.bounds.height)
                    .put("panelRendering",s.panelWindow.engine.getRenderer().isDisplayingFlutterUi());
            }
        }catch(Exception ignored){}return j;
    }
    public static boolean handleCommand(Context c,JSONObject r){
        String a=r.optString("action");SharedPreferences p=c.getSharedPreferences("launcher",0);
        LauncherRuntime rt=LauncherRuntime.get(c);
        if("global-dock".equals(a)){
            boolean on=r.optBoolean("enabled"),was=p.getBoolean("globalDockEnabled",false);
            SharedPreferences.Editor edit=p.edit().putBoolean("globalDockEnabled",on);
            if(on&&!was)edit.putBoolean("systemNavigationHidden",true);edit.commit();
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
            if(active!=null&&active.nativeInsets){
                if(r.optBoolean("enabled"))NavigationInsets.activate(c,p);
                else{active.dismissPanel();NavigationInsets.restore(c,p);}
            }
            if(!SystemNavigationPolicy.setHidden(c,p,r.optBoolean("enabled")))toast(c,"当前系统未允许管理原有导航栏");
            if(active!=null)active.update();rt.publish();return true;
        }
        if("show-dock-panel".equals(a)){
            if(active!=null)active.showPanel(r.optString("value"));return true;
        }
        if("panel-ready".equals(a)){
            if(active!=null&&!active.panel.isEmpty()&&r.optString("value").equals(""+active.panelRevision)){
                active.panelReady=true;active.publish();
            }return true;
        }
        if("dismiss-dock-panel".equals(a)){
            if(active!=null&&(r.optString("value").isEmpty()||r.optString("value").equals(""+active.panelRevision)))active.dismissPanel();
            return true;
        }
        if("system-back".equals(a)){
            if(active!=null&&!active.panel.isEmpty()){active.dismissPanel();return true;}
            new Thread(()->{
                try{new android.app.Instrumentation().sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);}
                catch(RuntimeException e){android.util.Log.w("UniBack","System back unavailable",e);new Handler(Looper.getMainLooper()).post(()->toast(c,"系统返回暂不可用"));}
            },"uni-system-back").start();return true;
        }
        if("show-recents".equals(a)){
            if(active!=null&&active.nativeInsets){active.toggleRecents();return true;}
            if(active!=null)active.dismissPanel();
            xyz.i4o.uni.launcher.overlay.SystemRecents.toggle(c);return true;
        }
        if("clear-system-recents".equals(a)){
            if(active!=null&&"recents".equals(active.panel)&&active.recentsWindow!=null)active.recentsWindow.clear();return true;
        }
        if("show-home".equals(a)||"show-desktop-settings".equals(a)){
            if(active!=null){active.dismissPanel();active.cameraSuspended=false;}
            c.startActivity(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                .putExtra("uniSettings","show-desktop-settings".equals(a)));return true;
        }
        if("open-official".equals(a)&&"camera".equals(r.optString("value"))&&active!=null){active.dismissPanel();active.cameraSuspended=true;active.update();}
        return false;
    }
    /** Hide the OEM bar; task bounds reserve the workspace without synthetic insets. */
    private static void enableBarModifications(Context c,SharedPreferences p){
        boolean hide=p.getBoolean("systemNavigationHidden",true);
        if(hide)NavigationInsets.activate(c,p);else NavigationInsets.restore(c,p);
        SystemNavigationPolicy.setHidden(c,p,hide);
        // Migrate the old overscan reservation: OEM apps consume it multiple times.
        if(OverscanPolicy.applied(c))OverscanPolicy.apply(c,p,false);
    }
    private static void disableBarModifications(Context c,SharedPreferences p){
        if(OverscanPolicy.applied(c))OverscanPolicy.apply(c,p,false);
        new WorkspacePolicy(c,p).stopAndRestore();
        SystemNavigationPolicy.setHidden(c,p,false);
        NavigationInsets.restore(c,p);
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
        windows=(WindowManager)getSystemService(WINDOW_SERVICE);
        NavigationInsets.prepare(this,()->{if(active==this)startWindows();});
    }
    private void startWindows(){
        if(dockWindow!=null)return;
        enableBarModifications(this,runtime.prefs());nativeInsets=NavigationInsets.applied(this);
        workspace=new WorkspacePolicy(this,runtime.prefs());
        if(nativeInsets)workspace.stopAndRestore();else workspace.start();
        try{dockWindow=new OverlayWindow(false);}catch(RuntimeException e){
            android.util.Log.e("UniDock","Cannot create dock",e);
            toast(this,"全局底栏无法显示，请检查悬浮显示授权");stopSelf();return;
        }
        runtime.addListener(this,this::update);update();
    }
    /** Each view retains its size for its entire lifetime. In particular a
     * dialog never reallocates the dock's Flutter texture or changes its focus. */
    private final class OverlayWindow {
        final boolean isPanel;
        final FlutterEngine engine;
        final FlutterView view;
        final WindowManager.LayoutParams bounds=new WindowManager.LayoutParams();
        final MethodChannel methods;
        final EventChannel events;
        EventChannel.EventSink sink;
        int relayouts;
        OverlayWindow(boolean isPanel){
            this.isPanel=isPanel;
            engine=new FlutterEngine(GlobalDockService.this,null,false);
            methods=new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/platform");
            methods.setMethodCallHandler((call,result)->{
                try{
                    if("snapshot".equals(call.method))result.success(state(isPanel).toString());
                    else if("panel-backdrop".equals(call.method))result.success(isPanel?panelBackdrop:null);
                    else if("saveDesign".equals(call.method))result.success(runtime.saveDesign((String)call.arguments));
                    else if("action".equals(call.method)){
                        String raw=(String)call.arguments;
                        if(raw==null||raw.length()>8192){result.error("invalid","操作无效",null);return;}
                        JSONObject request=new JSONObject(raw);
                        if(!handleCommand(GlobalDockService.this,request))runtime.handle(request);
                        publish();result.success(null);
                    }else result.notImplemented();
                }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
            });
            events=new EventChannel(engine.getDartExecutor().getBinaryMessenger(),"xyz.i4o.uni.launcher/events");
            events.setStreamHandler(new EventChannel.StreamHandler(){
                public void onListen(Object args,EventChannel.EventSink s){sink=s;publish();}
                public void onCancel(Object args){sink=null;}
            });
            installPlatformChannel(engine,isPanel);
            FlutterTextureView texture=new FlutterTextureView(GlobalDockService.this);texture.setOpaque(false);
            view=new FlutterView(GlobalDockService.this,texture){
                @Override public boolean dispatchKeyEvent(KeyEvent event){
                    if(event.getKeyCode()==KeyEvent.KEYCODE_BACK&&isPanel){
                        if(event.getAction()==KeyEvent.ACTION_UP)engine.getNavigationChannel().popRoute();return true;
                    }
                    return super.dispatchKeyEvent(event);
                }
            };
            view.setFocusableInTouchMode(isPanel);
            view.setVisibility(View.INVISIBLE);view.setBackgroundColor(android.graphics.Color.TRANSPARENT);
            // OEM stable insets include both its hidden 136px bar and overscan.
            // Neither belongs inside these physically positioned windows.
            view.setOnApplyWindowInsetsListener((v,insets)->insets.consumeSystemWindowInsets().consumeStableInsets());
            bounds.type=nativeInsets?2024:Build.VERSION.SDK_INT>=26?WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY:WindowManager.LayoutParams.TYPE_PHONE;
            bounds.format=PixelFormat.TRANSLUCENT;bounds.gravity=Gravity.TOP|Gravity.LEFT;
            bounds.setTitle(isPanel?"UNI Global Panel":"UNI Global Dock");
            bounds.flags=WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                |WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS|WindowManager.LayoutParams.FLAG_FULLSCREEN
                |WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
            if(!isPanel)bounds.flags|=WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            bounds.softInputMode=WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING;
            setBounds();windows.addView(view,bounds);
            view.attachToFlutterEngine(engine);
            String bundle=FlutterInjector.instance().flutterLoader().findAppBundlePath();
            engine.getDartExecutor().executeDartEntrypoint(new DartExecutor.DartEntrypoint(bundle,"package:uni_launcher/main.dart",isPanel?"globalPanelMain":"globalDockMain"));
        }
        private boolean setBounds(){
            DisplayMetrics real=new DisplayMetrics();windows.getDefaultDisplay().getRealMetrics(real);
            int bar=Math.round(real.widthPixels*96f/1920f);
            boolean footer=isPanel&&"recents".equals(panel)&&recentsWindow!=null&&recentsWindow.clearSupported();
            int h=isPanel?(footer?Math.round(real.widthPixels*120f/1920f):real.heightPixels-bar):bar;
            int y=isPanel?(footer?real.heightPixels-bar-h:0):real.heightPixels-bar;
            boolean changed=bounds.width!=real.widthPixels||bounds.height!=h||bounds.x!=0||bounds.y!=y;
            bounds.width=real.widthPixels;bounds.height=h;bounds.x=0;bounds.y=y;return changed;
        }
        void updateBounds(){if(setBounds()&&view.getParent()!=null){windows.updateViewLayout(view,bounds);relayouts++;}}
        void show(boolean show){
            if((view.getVisibility()==View.VISIBLE)==show)return;
            view.setVisibility(show?View.VISIBLE:View.INVISIBLE);
            if(show){engine.getLifecycleChannel().appIsResumed();if(isPanel)view.requestFocus();}
            else engine.getLifecycleChannel().appIsPaused();
        }
        void publish(){if(sink!=null)sink.success(state(isPanel).toString());}
        void close(){
            methods.setMethodCallHandler(null);sink=null;events.setStreamHandler(null);
            view.detachFromFlutterEngine();if(view.getParent()!=null)windows.removeViewImmediate(view);
            engine.destroy();
        }
    }
    private JSONObject state(boolean isPanel){
        JSONObject j=runtime.snapshot();try{
            j.put("hostMode",isPanel?"global-panel":"global-dock").put("globalDock",snapshot(this))
             .put("systemNavigationHidden",runtime.prefs().getBoolean("systemNavigationHidden",false))
             .put("systemNavigationGranted",SystemNavigationPolicy.granted(this));
        }catch(Exception ignored){}return j;
    }
    private void showPanel(String kind){
        if(!java.util.Arrays.asList("apps","climate","media","vehicle","navigation").contains(kind))return;
        // Tapping the same button again closes it; different buttons replace it.
        if(kind.equals(panel)){dismissPanel();return;}
        if(recentsWindow!=null)recentsWindow.hide();
        if(panel.isEmpty()||"recents".equals(panel))panelBackdrop=captureBackdrop();
        panel=kind;panelReady=false;panelRevision++;
        try{if(panelWindow==null)panelWindow=new OverlayWindow(true);}
        catch(RuntimeException e){panel="";android.util.Log.e("UniDock","Cannot create panel",e);toast(this,"面板暂不可用");}
        if(!panel.isEmpty())startForegroundCheck();
        update();
    }
    /** Ephemeral, in-memory backdrop only while a glass panel is open. Flutter
     * cannot blur another process's Surface; the platform build can capture it.
     * No image is written to storage or included in the periodic state stream. */
    private byte[] captureBackdrop(){
        android.graphics.Bitmap bitmap=null,crop=null;
        try{
            JSONObject design=new JSONObject(runtime.prefs().getString("savedDesign","{}"));
            JSONObject appearance=design.optJSONObject("preferences");
            if(appearance==null||!appearance.optBoolean("glass",false))return null;
            DisplayMetrics real=new DisplayMetrics();windows.getDefaultDisplay().getRealMetrics(real);
            bitmap=(android.graphics.Bitmap)Class.forName("android.view.SurfaceControl")
                .getDeclaredMethod("screenshot",android.graphics.Rect.class,int.class,int.class,int.class)
                .invoke(null,new android.graphics.Rect(),real.widthPixels,real.heightPixels,windows.getDefaultDisplay().getRotation());
            if(bitmap==null)return null;
            int h=real.heightPixels-Math.round(real.widthPixels*96f/1920f);
            crop=android.graphics.Bitmap.createBitmap(bitmap,0,0,bitmap.getWidth(),Math.min(h,bitmap.getHeight()));
            java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();
            crop.compress(android.graphics.Bitmap.CompressFormat.PNG,100,out);return out.toByteArray();
        }catch(Exception e){android.util.Log.w("UniDock","Glass backdrop unavailable",e);return null;}
        finally{if(crop!=null&&crop!=bitmap)crop.recycle();if(bitmap!=null)bitmap.recycle();}
    }
    private void dismissPanel(){
        if(panel.isEmpty())return;
        if(recentsWindow!=null)recentsWindow.hide();
        panel="";panelReady=false;panelBackdrop=null;panelRevision++;main.removeCallbacks(foregroundCheck);update();
    }
    private void toggleRecents(){
        if("recents".equals(panel)){dismissPanel();return;}
        dismissPanel();
        try{
            Intent intent=new Intent("ecarx.action.OPEN_RECENT_PANEL").setPackage("com.ecarx.recents");
            if(getPackageManager().resolveActivity(intent,0)==null){xyz.i4o.uni.launcher.overlay.SystemRecents.toggle(this);return;}
            if(recentsWindow==null)recentsWindow=new EmbeddedTaskWindow(this,
                intent,this::dismissPanel);
            panel="recents";panelRevision++;recentsWindow.show();startForegroundCheck();update();
            main.postDelayed(()->{if("recents".equals(panel)&&recentsWindow!=null&&recentsWindow.clearSupported()){
                try{if(panelWindow==null)panelWindow=new OverlayWindow(true);update();}
                catch(RuntimeException e){android.util.Log.w("UniDock","Task footer unavailable",e);}
            }},400);
        }catch(Exception e){android.util.Log.w("UniDock","Bounded system task list unavailable",e);toast(this,"系统任务列表暂不可用");}
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
        if(panel.isEmpty())return;
        String top=topTaskPackage();
        if(!top.isEmpty()&&!top.equals(getPackageName())&&!top.equals(expandedTopTask)){
            dismissPanel();
            return;
        }
        main.postDelayed(foregroundCheck,500);
    }
    private String topTaskPackage(){
        return xyz.i4o.uni.launcher.overlay.DisplayTasks.topPackage(this);
    }
    private void update(){
        if(dockWindow==null)return;
        if(!Settings.canDrawOverlays(this)){stopSelf();return;}
        if(runtime.homeVisible())cameraSuspended=false;
        visible=!cameraSuspended&&(!nativeInsets||runtime.prefs().getBoolean("systemNavigationHidden",false));
        dockWindow.updateBounds();dockWindow.show(visible);
        if(panelWindow!=null){panelWindow.updateBounds();panelWindow.show(visible&&!panel.isEmpty()
            &&(!"recents".equals(panel)||recentsWindow!=null&&recentsWindow.clearSupported()));}
        publish();
    }
    private void publish(){if(dockWindow!=null)dockWindow.publish();if(panelWindow!=null)panelWindow.publish();}
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
    private void installPlatformChannel(FlutterEngine engine,boolean isPanel){
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"flutter/platform",JSONMethodCodec.INSTANCE).setMethodCallHandler((call,result)->{
            try{
                ClipboardManager clipboard=(ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
                if("Clipboard.setData".equals(call.method)){JSONObject j=(JSONObject)call.arguments;clipboard.setPrimaryClip(ClipData.newPlainText("UNI",j.optString("text")));result.success(null);}
                else if("Clipboard.getData".equals(call.method)){JSONObject j=new JSONObject();if(clipboard.hasPrimaryClip())j.put("text",clipboard.getPrimaryClip().getItemAt(0).coerceToText(this));result.success(j);}
                else if("Clipboard.hasStrings".equals(call.method)){result.success(new JSONObject().put("value",clipboard.hasPrimaryClip()));}
                else if("SystemNavigator.pop".equals(call.method)){dismissPanel();result.success(null);}
                else result.success(null);
            }catch(Exception e){result.error("unavailable","操作暂不可用",null);}
        });
    }
    @Override public int onStartCommand(Intent intent,int flags,int id){
        if(intent!=null&&(STOP.equals(intent.getAction())||RESTORE.equals(intent.getAction()))){stopAndRestore(this);stopSelf();return START_NOT_STICKY;}
        return START_STICKY;
    }
    @Override public void onConfigurationChanged(android.content.res.Configuration config){super.onConfigurationChanged(config);update();}
    @Override public void onDestroy(){
        if(runtime!=null)runtime.removeListener(this);
        main.removeCallbacksAndMessages(null);
        if(workspace!=null)workspace.stopAndRestore();
        if(recentsWindow!=null){recentsWindow.close();recentsWindow=null;}
        if(panelWindow!=null){panelWindow.close();panelWindow=null;}
        if(dockWindow!=null){dockWindow.close();dockWindow=null;}
        active=null;
        if(runtime!=null)runtime.publish();super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
    @Override protected void dump(java.io.FileDescriptor fd,java.io.PrintWriter writer,String[] args){try{JSONObject report=snapshot(this),all=runtime.snapshot(),m=all.optJSONObject("media"),safe=new JSONObject();
        if(m!=null)for(String key:new String[]{"source","playing","canToggle","canNext","canPrevious","positionMs","durationMs"})safe.put(key,m.opt(key));
        report.put("media",safe).put("runtimeOwnerCount",all.optInt("runtimeOwnerCount"));writer.println("UNI_GLOBAL_DOCK="+report);
        }catch(Exception e){writer.println("UNI_GLOBAL_DOCK_UNAVAILABLE");}}
}
