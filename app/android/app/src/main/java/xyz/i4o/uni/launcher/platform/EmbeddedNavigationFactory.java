package xyz.i4o.uni.launcher.platform;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.hardware.display.VirtualDisplay;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.FrameLayout;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;
import xyz.i4o.uni.launcher.integration.NavigationApps;

/** Android 9 ActivityView, as used by the analyzed Dudu Pip28View.
 * Permission preflight happens BEFORE attaching SurfaceView: Android may throw
 * from its asynchronous surface callback if INJECT_EVENTS is absent.
 */
public final class EmbeddedNavigationFactory extends PlatformViewFactory {
    private final Activity activity;
    private final BinaryMessenger messenger;
    private final Map<Integer,EmbeddedView> views=new HashMap<>();
    private boolean hostVisible=true;
    public EmbeddedNavigationFactory(Activity activity,BinaryMessenger messenger){super(StandardMessageCodec.INSTANCE);this.activity=activity;this.messenger=messenger;}
    @Override public PlatformView create(Context context,int id,Object args){
        EmbeddedView view=new EmbeddedView(context,id);views.put(id,view);return view;
    }
    public void setVisible(boolean visible){hostVisible=visible;for(EmbeddedView view:views.values()){
        view.applyVisibility();
    }}
    public org.json.JSONArray snapshot(){org.json.JSONArray result=new org.json.JSONArray();for(EmbeddedView view:views.values())try{
        result.put(new org.json.JSONObject(view.status).put("viewId",view.id).put("displayId",view.displayId).put("hostVisible",hostVisible).put("cardVisible",view.requestedVisible));
    }catch(Exception ignored){}return result;}
    public void close(){for(EmbeddedView v:views.values().toArray(new EmbeddedView[0]))v.dispose();}
    private final class EmbeddedView implements PlatformView {
        final FrameLayout root;
        final MethodChannel channel;
        final Handler handler=new Handler(Looper.getMainLooper());
        final int id;
        Object activityView;
        VirtualDisplay boundDisplay;
        boolean disposed,started,requestedVisible=true;
        int attempts,slotAttempts,placementAttempts,displayId=-1;
        Map<String,Object> status=new HashMap<>();
        EmbeddedView(Context context,int id){
            this.id=id;root=new FrameLayout(context);
            root.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,orr,ob)->{
                if(activityView!=null&&started&&visible())try{activityView.getClass().getMethod("onLocationChanged").invoke(activityView);}catch(Exception ignored){}
            });
            channel=new MethodChannel(messenger,"xyz.i4o.uni.launcher/map/"+id);
            channel.setMethodCallHandler((call,result)->{
                if("status".equals(call.method))result.success(status);
                else if("visible".equals(call.method)){requestedVisible=Boolean.TRUE.equals(call.arguments);applyVisibility();result.success(null);}
                else if("retry".equals(call.method)){release();attempts=0;start();result.success(null);}
                else result.notImplemented();
            });
            handler.post(this::start);
        }
        boolean visible(){return hostVisible&&requestedVisible&&!disposed;}
        void surfaceVisibility(View view,boolean visible){
            // On this Android 9 firmware, hiding only the parent leaves the
            // SurfaceControl visible at unscaled coordinates above Flutter.
            if(view instanceof android.view.SurfaceView)view.setVisibility(visible?View.VISIBLE:View.GONE);
            if(view instanceof android.view.ViewGroup){android.view.ViewGroup group=(android.view.ViewGroup)view;for(int i=0;i<group.getChildCount();i++)surfaceVisibility(group.getChildAt(i),visible);}
        }
        void applyVisibility(){
            handler.removeCallbacksAndMessages(null);
            if(activityView instanceof View){
                View embedded=(View)activityView;
                surfaceVisibility(embedded,visible());
            }
            // Retain the ActivityView and its display. Detaching/reparenting on
            // every page/modal transition races Surface reconstruction.
            root.setVisibility(visible()?View.VISIBLE:View.INVISIBLE);
            if(visible()){
                if(activityView==null)handler.post(this::start);
                else {attempts=0;placementAttempts=0;state("loading","正在恢复地图画面");handler.postDelayed(this::awaitDisplay,150);}
            }else state("paused","地图已隐藏");
        }
        void state(String phase,String reason){
            status=new HashMap<>();status.put("phase",phase);status.put("reason",reason);status.put("ready","ready".equals(phase));
            if(!disposed)channel.invokeMethod("status",status);
        }
        void start(){
            if(disposed||activityView!=null)return;
            if(!visible()){state("paused","桌面恢复后载入地图");return;}
            NavigationApps apps=new NavigationApps(activity,activity.getSharedPreferences("launcher",0));
            if(!apps.snapshot().optBoolean("canEmbed")){state("unavailable",apps.snapshot().optString("reason"));return;}
            for(EmbeddedView other:views.values())if(other!=this&&other.activityView!=null){
                if(!other.visible()){other.release();other.state("paused","地图已隐藏");continue;}
                // A page fade briefly keeps the outgoing card alive. Wait for
                // its display to release instead of permanently failing the new card.
                if(++slotAttempts<15){state("loading","正在切换地图卡片");handler.postDelayed(this::start,150);}
                else state("unavailable","导航已在另一张卡片显示");
                return;
            }
            slotAttempts=0;attempts=0;
            try{
                Class<?> type=Class.forName("android.app.ActivityView");
                activityView=type.getConstructor(Context.class).newInstance(activity);
                root.addView((View)activityView,new FrameLayout.LayoutParams(-1,-1));
                state("loading","正在载入导航应用");handler.postDelayed(this::awaitDisplay,150);
            }catch(Throwable e){fail(e);}
        }
        void awaitDisplay(){
            if(disposed||activityView==null||!visible())return;
            try{
                Field field=activityView.getClass().getDeclaredField("mVirtualDisplay");field.setAccessible(true);
                VirtualDisplay display=(VirtualDisplay)field.get(activityView);
                if(display==null||!display.getDisplay().isValid()||!surfaceReady((View)activityView)){
                    if(++attempts<40){handler.postDelayed(this::awaitDisplay,150);return;}throw new IllegalStateException("Display/surface timeout");
                }
                int actualId=display.getDisplay().getDisplayId();
                if(started&&boundDisplay==display&&displayId==actualId){
                    activityView.getClass().getMethod("onLocationChanged").invoke(activityView);
                    handler.postDelayed(this::verifyPlacement,150);return;
                }
                started=false;boundDisplay=display;displayId=actualId;
                Intent intent=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).launchIntent();
                if(intent==null)throw new IllegalStateException("Navigation removed");
                // Reusing AMap's singleTask through startActivity can first
                // foreground its old default-display task and stop this host,
                // cancelling placement. Move an existing task before launching.
                String pkg=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).selected();
                if(!placeExistingTask(pkg)){
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activityView.getClass().getMethod("startActivity",Intent.class).invoke(activityView,intent);
                }
                started=true;placementAttempts=0;state("loading","正在连接地图画面");handler.postDelayed(this::verifyPlacement,250);
            }catch(Throwable e){fail(e);}
        }
        boolean placeExistingTask(String pkg)throws Exception{
            Object manager=Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);
            java.lang.reflect.Method all=manager.getClass().getMethod("getAllStackInfos");all.setAccessible(true);
            java.util.List<?> stacks=(java.util.List<?>)all.invoke(manager);
            for(Object stack:stacks){
                Class<?> type=stack.getClass();String[] names=(String[])type.getField("taskNames").get(stack);
                if(names==null||names.length!=1||names[0]==null||!names[0].startsWith(pkg+"/"))continue;
                if(type.getField("displayId").getInt(stack)!=displayId){
                    java.lang.reflect.Method move=manager.getClass().getMethod("moveStackToDisplay",int.class,int.class);move.setAccessible(true);
                    move.invoke(manager,type.getField("stackId").getInt(stack),displayId);
                }
                return true;
            }
            return false;
        }
        boolean surfaceReady(View view){
            if(view.getWidth()<=0||view.getHeight()<=0)return false;
            if(view instanceof android.view.SurfaceView)return ((android.view.SurfaceView)view).getHolder().getSurface().isValid();
            if(view instanceof android.view.ViewGroup){android.view.ViewGroup group=(android.view.ViewGroup)view;for(int i=0;i<group.getChildCount();i++)if(!surfaceReady(group.getChildAt(i)))return false;}
            return true;
        }
        void verifyPlacement(){
            if(disposed||activityView==null||!started||!visible())return;
            try{
                Field displayField=activityView.getClass().getDeclaredField("mVirtualDisplay");displayField.setAccessible(true);
                VirtualDisplay actual=(VirtualDisplay)displayField.get(activityView);
                if(actual!=boundDisplay||actual==null||!actual.getDisplay().isValid()||!surfaceReady((View)activityView)){
                    attempts=0;state("loading","正在恢复地图画面");handler.postDelayed(this::awaitDisplay,150);return;
                }
                String pkg=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).selected();
                Object manager=Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);
                java.lang.reflect.Method all=manager.getClass().getMethod("getAllStackInfos");all.setAccessible(true);
                java.util.List<?> stacks=(java.util.List<?>)all.invoke(manager);
                Integer candidate=null;
                for(Object stack:stacks){
                    Class<?> type=stack.getClass();
                    String[] names=(String[])type.getField("taskNames").get(stack);
                    int source=type.getField("displayId").getInt(stack);
                    if(names==null)continue;
                    boolean matches=false;for(String name:names)if(name!=null&&name.startsWith(pkg+"/"))matches=true;
                    if(!matches)continue;
                    if(source==displayId){state("ready","地图已进入卡片");return;}
                    // Only move the selected app's own single-task stack.
                    // Never move a stack that also contains another app.
                    if(names.length==1)candidate=type.getField("stackId").getInt(stack);
                }
                if(candidate!=null){
                    java.lang.reflect.Method move=manager.getClass().getMethod("moveStackToDisplay",int.class,int.class);move.setAccessible(true);
                    move.invoke(manager,candidate,displayId);
                }
                if(++placementAttempts<24)handler.postDelayed(this::verifyPlacement,250);
                else fail(new IllegalStateException("Navigation task did not enter the display"));
            }catch(Throwable e){fail(e);}
        }
        void fail(Throwable error){
            android.util.Log.i("UniMap","Embedding unavailable",error);
            release();state("failed","地图无法嵌入，请使用全屏入口或核对系统授权");
        }
        void release(){
            handler.removeCallbacksAndMessages(null);started=false;displayId=-1;boundDisplay=null;
            if(activityView!=null)try{activityView.getClass().getMethod("release").invoke(activityView);}catch(Throwable ignored){}
            root.removeAllViews();activityView=null;
        }
        @Override public View getView(){return root;}
        @Override public void dispose(){if(disposed)return;disposed=true;release();channel.setMethodCallHandler(null);views.remove(id);}
    }
}
