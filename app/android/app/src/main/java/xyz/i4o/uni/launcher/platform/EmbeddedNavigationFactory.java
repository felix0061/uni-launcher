package xyz.i4o.uni.launcher.platform;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.hardware.display.VirtualDisplay;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.PixelCopy;
import android.view.Surface;
import android.view.SurfaceView;
import android.widget.FrameLayout;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import io.flutter.view.TextureRegistry;
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
    private final TextureRegistry textures;
    private final java.util.concurrent.ExecutorService previewWorker=java.util.concurrent.Executors.newSingleThreadExecutor();
    private final Map<Integer,EmbeddedView> views=new HashMap<>();
    private boolean hostVisible=true;
    public EmbeddedNavigationFactory(Activity activity,BinaryMessenger messenger,TextureRegistry textures){super(StandardMessageCodec.INSTANCE);this.activity=activity;this.messenger=messenger;this.textures=textures;}
    @Override public PlatformView create(Context context,int id,Object args){
        EmbeddedView view=new EmbeddedView(context,id);views.put(id,view);return view;
    }
    public void setVisible(boolean visible){hostVisible=visible;for(EmbeddedView view:views.values()){
        view.applyVisibility();
    }}
    public void preparePageChange(){for(EmbeddedView view:views.values()){
        view.requestedVisible=false;view.applyVisibility();
    }}
    public org.json.JSONArray snapshot(){org.json.JSONArray result=new org.json.JSONArray();for(EmbeddedView view:views.values())try{
        result.put(new org.json.JSONObject(view.status).put("viewId",view.id).put("displayId",view.displayId).put("hostVisible",hostVisible).put("cardVisible",view.requestedVisible));
    }catch(Exception ignored){}return result;}
    public void close(){for(EmbeddedView v:views.values().toArray(new EmbeddedView[0]))v.dispose();previewWorker.shutdownNow();}
    private final class EmbeddedView implements PlatformView {
        final FrameLayout root;
        final MethodChannel channel;
        final Handler handler=new Handler(Looper.getMainLooper());
        final int id;
        Object activityView;
        VirtualDisplay boundDisplay;
        boolean disposed,started,requestedVisible=true;
        Boolean appliedVisible;
        TextureRegistry.SurfaceTextureEntry preview;
        boolean copying,hasPreview;
        int frameAttempts,visibilityGeneration;
        final Handler copyHandler=new Handler(Looper.getMainLooper());
        final Runnable refreshPreview=()->captureFrame(false);
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
            if(view instanceof android.view.SurfaceView)view.setVisibility(visible?View.VISIBLE:View.INVISIBLE);
            if(view instanceof android.view.ViewGroup){android.view.ViewGroup group=(android.view.ViewGroup)view;for(int i=0;i<group.getChildCount();i++)surfaceVisibility(group.getChildAt(i),visible);}
        }
        void applyVisibility(){
            boolean show=visible();
            if(appliedVisible!=null&&appliedVisible==show)return;
            appliedVisible=show;visibilityGeneration++;
            handler.removeCallbacksAndMessages(null);
            if(activityView instanceof View)surfaceVisibility((View)activityView,false);
            // Retain the ActivityView and its display. Detaching/reparenting on
            // every page/modal transition races Surface reconstruction.
            root.setVisibility(View.INVISIBLE);
            if(visible()){
                state("loading","正在恢复地图画面");
                // Let the incoming Flutter workspace reach the compositor before
                // revealing Android's independent Surface at its final bounds.
                handler.postDelayed(()->{
                    if(!visible())return;
                    root.setVisibility(View.VISIBLE);
                    if(activityView==null)start();
                    else {surfaceVisibility((View)activityView,true);attempts=0;placementAttempts=0;frameAttempts=0;handler.postDelayed(this::awaitDisplay,80);}
                },180);
            }else state("paused","地图已隐藏");
        }
        void state(String phase,String reason){
            status=new HashMap<>();status.put("phase",phase);status.put("reason",reason);status.put("ready","ready".equals(phase));
            if(hasPreview&&preview!=null)status.put("previewTextureId",preview.id());
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
                    if(source==displayId){captureFrame(true);return;}
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
        SurfaceView mapSurface(View view){
            if(view instanceof SurfaceView)return (SurfaceView)view;
            if(view instanceof android.view.ViewGroup){
                android.view.ViewGroup group=(android.view.ViewGroup)view;
                for(int i=0;i<group.getChildCount();i++){SurfaceView found=mapSurface(group.getChildAt(i));if(found!=null)return found;}
            }return null;
        }
        boolean hasContent(Bitmap bitmap){
            // Reject an unfilled Surface, not a genuinely dark/night map.
            int colored=0;
            for(int y=1;y<8;y++)for(int x=1;x<12;x++){
                int color=bitmap.getPixel(bitmap.getWidth()*x/12,bitmap.getHeight()*y/8);
                if(((color>>16)&255)>3||((color>>8)&255)>3||(color&255)>3)colored++;
            }return colored>3;
        }
        void captureFrame(boolean restoring){
            if(disposed||!visible()||activityView==null)return;
            if(copying){if(restoring)handler.postDelayed(()->captureFrame(true),80);return;}
            SurfaceView surface=mapSurface((View)activityView);
            if(surface==null||!surface.getHolder().getSurface().isValid()||surface.getWidth()<2||surface.getHeight()<2){
                if(restoring&&++frameAttempts<30)handler.postDelayed(()->captureFrame(true),80);return;
            }
            int width=Math.min(960,surface.getWidth()),height=Math.max(2,width*surface.getHeight()/surface.getWidth());
            Bitmap frame=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);
            int generation=visibilityGeneration;copying=true;
            try{PixelCopy.request(surface,frame,result->{
                if(disposed||generation!=visibilityGeneration||!visible()){copying=false;frame.recycle();return;}
                if(result==PixelCopy.SUCCESS&&hasContent(frame)){
                    try{
                        if(preview==null)preview=textures.createSurfaceTexture();
                        preview.surfaceTexture().setDefaultBufferSize(width,height);
                        final Surface target=new Surface(preview.surfaceTexture());
                        // A Surface buffer queue may wait for Flutter to consume
                        // its previous texture. Never block the Android UI thread.
                        previewWorker.execute(()->{
                            boolean drawn=false;
                            try{
                                Canvas canvas=target.lockCanvas(null);
                                try{canvas.drawBitmap(frame,null,new Rect(0,0,canvas.getWidth(),canvas.getHeight()),null);}
                                finally{target.unlockCanvasAndPost(canvas);}
                                drawn=true;
                            }catch(RuntimeException e){android.util.Log.d("UniMap","Preview not ready: "+e.getClass().getSimpleName());}
                            finally{target.release();frame.recycle();}
                            final boolean success=drawn;
                            copyHandler.post(()->{
                                copying=false;
                                if(disposed||generation!=visibilityGeneration||!visible())return;
                                hasPreview=hasPreview||success;frameAttempts=0;state("ready","地图已进入卡片");
                                handler.removeCallbacks(refreshPreview);handler.postDelayed(refreshPreview,4000);
                            });
                        });
                    }catch(RuntimeException e){copying=false;frame.recycle();if(restoring)state("ready","地图已进入卡片");}
                }else{
                    copying=false;frame.recycle();
                    if(restoring&&++frameAttempts<30)handler.postDelayed(()->captureFrame(true),80);
                    else if(restoring)state("loading","等待地图绘制画面");
                }
            },copyHandler);}catch(RuntimeException e){copying=false;frame.recycle();if(restoring)state("ready","地图已进入卡片");}
        }
        void release(){
            handler.removeCallbacksAndMessages(null);visibilityGeneration++;started=false;displayId=-1;boundDisplay=null;
            if(preview!=null){preview.release();preview=null;}hasPreview=false;
            if(activityView!=null)try{activityView.getClass().getMethod("release").invoke(activityView);}catch(Throwable ignored){}
            root.removeAllViews();activityView=null;
        }
        @Override public View getView(){return root;}
        @Override public void dispose(){if(disposed)return;disposed=true;release();channel.setMethodCallHandler(null);views.remove(id);}
    }
}
