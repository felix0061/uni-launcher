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
    public void setVisible(boolean visible){hostVisible=visible;for(EmbeddedView view:views.values()){view.root.setVisibility(visible?View.VISIBLE:View.GONE);if(visible&&view.activityView==null&&!view.disposed)view.handler.post(view::start);}}
    public void close(){for(EmbeddedView v:views.values().toArray(new EmbeddedView[0]))v.dispose();}
    private final class EmbeddedView implements PlatformView {
        final FrameLayout root;
        final MethodChannel channel;
        final Handler handler=new Handler(Looper.getMainLooper());
        final int id;
        Object activityView;
        boolean disposed,started;
        int attempts,slotAttempts;
        Map<String,Object> status=new HashMap<>();
        EmbeddedView(Context context,int id){
            this.id=id;root=new FrameLayout(context);
            root.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,orr,ob)->{
                if(activityView!=null&&started)try{activityView.getClass().getMethod("onLocationChanged").invoke(activityView);}catch(Exception ignored){}
            });
            channel=new MethodChannel(messenger,"xyz.i4o.uni.launcher/map/"+id);
            channel.setMethodCallHandler((call,result)->{
                if("status".equals(call.method))result.success(status);
                else if("retry".equals(call.method)){release();attempts=0;start();result.success(null);}
                else result.notImplemented();
            });
            handler.post(this::start);
        }
        void state(String phase,String reason){
            status=new HashMap<>();status.put("phase",phase);status.put("reason",reason);status.put("ready",started);
            if(!disposed)channel.invokeMethod("status",status);
        }
        void start(){
            if(disposed||activityView!=null)return;
            if(!hostVisible){state("paused","桌面恢复后载入地图");return;}
            NavigationApps apps=new NavigationApps(activity,activity.getSharedPreferences("launcher",0));
            if(!apps.snapshot().optBoolean("canEmbed")){state("unavailable",apps.snapshot().optString("reason"));return;}
            for(EmbeddedView other:views.values())if(other!=this&&other.activityView!=null){
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
                state("loading","正在载入高德地图");handler.postDelayed(this::awaitDisplay,150);
            }catch(Throwable e){fail(e);}
        }
        void awaitDisplay(){
            if(disposed||activityView==null)return;
            try{
                Field field=activityView.getClass().getDeclaredField("mVirtualDisplay");field.setAccessible(true);
                VirtualDisplay display=(VirtualDisplay)field.get(activityView);
                if(display==null){if(++attempts<40){handler.postDelayed(this::awaitDisplay,150);return;}throw new IllegalStateException("Display timeout");}
                Intent intent=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).launchIntent();
                if(intent==null)throw new IllegalStateException("Navigation removed");
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activityView.getClass().getMethod("startActivity",Intent.class).invoke(activityView,intent);
                started=true;state("ready","地图已发送至卡片容器；画面与触摸待核对");
            }catch(Throwable e){fail(e);}
        }
        void fail(Throwable error){
            android.util.Log.i("UniMap","Embedding unavailable: "+error.getClass().getSimpleName());
            release();state("failed","地图无法嵌入，请使用全屏入口或核对系统授权");
        }
        void release(){
            handler.removeCallbacksAndMessages(null);root.removeAllViews();started=false;
            if(activityView!=null)try{activityView.getClass().getMethod("release").invoke(activityView);}catch(Throwable ignored){}
            activityView=null;
        }
        @Override public View getView(){return root;}
        @Override public void dispose(){if(disposed)return;disposed=true;release();channel.setMethodCallHandler(null);views.remove(id);}
    }
}
