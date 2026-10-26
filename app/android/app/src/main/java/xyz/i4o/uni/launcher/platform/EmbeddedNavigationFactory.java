package xyz.i4o.uni.launcher.platform;

import android.app.Activity;
import android.content.Context;
import android.content.ComponentName;
import android.content.ComponentCallbacks2;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.hardware.display.VirtualDisplay;
import android.graphics.Bitmap;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.PixelCopy;
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
    private static final int PREVIEW_MAX_EDGE=640;
    // At most one drawing task and one queued task across all cards.
    private final java.util.concurrent.ExecutorService previewWorker=new java.util.concurrent.ThreadPoolExecutor(
            1,1,0L,java.util.concurrent.TimeUnit.MILLISECONDS,
            new java.util.concurrent.ArrayBlockingQueue<>(1));
    private boolean closed;
    private final Map<Integer,EmbeddedView> views=new HashMap<>();
    private boolean hostVisible=true;
    public EmbeddedNavigationFactory(Activity activity,BinaryMessenger messenger,TextureRegistry textures){super(StandardMessageCodec.INSTANCE);this.activity=activity;this.messenger=messenger;this.textures=textures;}
    @Override public PlatformView create(Context context,int id,Object args){
        if(closed)throw new IllegalStateException("Map factory is closed");
        EmbeddedView view=new EmbeddedView(context,id);views.put(id,view);return view;
    }
    public void setVisible(boolean visible){hostVisible=visible;for(EmbeddedView view:views.values()){
        view.applyVisibility();
        if(!visible)view.dropPreview();
    }}
    public void preparePageChange(){for(EmbeddedView view:views.values()){
        view.requestedVisible=false;view.applyVisibility();
    }}
    /** Called on the Android main thread, like create/setVisible/close. Never releases ActivityView. */
    public void trimMemory(int level){
        boolean highPressure=level==ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW
                ||level==ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL
                ||level>=ComponentCallbacks2.TRIM_MEMORY_BACKGROUND;
        for(EmbeddedView view:views.values()){
            if(highPressure){view.previewSuppressed=true;view.dropPreview();}
            else if(!hostVisible||!view.visible())view.dropPreview();
        }
    }
    public org.json.JSONArray snapshot(){org.json.JSONArray result=new org.json.JSONArray();for(EmbeddedView view:views.values())try{
        java.util.Map<String,Object> safe=new HashMap<>(view.status);safe.remove("previewBytes");
        result.put(new org.json.JSONObject(safe).put("previewJpegBytes",view.previewJpeg==null?0:view.previewJpeg.length).put("viewId",view.id).put("displayId",view.displayId).put("hostVisible",hostVisible).put("cardVisible",view.requestedVisible)
                .put("previewWidth",view.previewWidth).put("previewHeight",view.previewHeight)
                .put("previewBitmapBytes",view.sample==null?0:view.sample.getAllocationByteCount())
                .put("sampleWidth",view.sample==null?0:view.sample.getWidth())
                .put("sampleHeight",view.sample==null?0:view.sample.getHeight())
                .put("copyInFlight",view.copying).put("previewReleasePending",view.previewReleasePending)
                .put("previewSuppressed",view.previewSuppressed).put("activationCount",view.activationCount));
    }catch(Exception ignored){}return result;}
    public void close(){
        if(closed)return;closed=true;
        for(EmbeddedView v:views.values().toArray(new EmbeddedView[0]))v.dispose();
        // Drain cancelled jobs so their completion returns Bitmap ownership.
        previewWorker.shutdown();
    }
    private final class EmbeddedView implements PlatformView {
        final FrameLayout root;
        final MethodChannel channel;
        final Handler handler=new Handler(Looper.getMainLooper());
        final int id;
        Object activityView;
        VirtualDisplay boundDisplay;
        boolean disposed,started,requestedVisible=true;
        Boolean appliedVisible;
        byte[] previewJpeg;
        int previewRevision;
        boolean copying,hasPreview,previewReleasePending,previewSuppressed;
        Bitmap sample;
        int previewWidth,previewHeight,previewGeneration;
        PreviewDraw activeDraw;
        int frameAttempts,visibilityGeneration;
        final Handler copyHandler=new Handler(Looper.getMainLooper());
        final Runnable refreshPreview=()->captureFrame(false);
        int attempts,slotAttempts,placementAttempts,displayId=-1,activationCount;
        int activatedGeneration=-1;
        long firstFrameAt;
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
            if(activeDraw!=null)activeDraw.cancelled=true;
            if(show)previewSuppressed=false;
            handler.removeCallbacksAndMessages(null);
            if(activityView instanceof View)surfaceVisibility((View)activityView,false);
            // Retain the ActivityView and its display. Detaching/reparenting on
            // every page/modal transition races Surface reconstruction.
            root.setVisibility(View.INVISIBLE);
            if(visible()){
                state("loading","正在恢复地图画面");
                // Flutter sends visible only after workspace motion settles.
                // Wait for the next traversal, not another fixed 180ms. Fence
                // callbacks because postOnAnimation is not on our Handler.
                final int generation=visibilityGeneration;
                root.postOnAnimation(()->{
                    if(generation!=visibilityGeneration||!visible())return;
                    root.setVisibility(View.VISIBLE);
                    if(activityView==null)start();
                    else {
                        surfaceVisibility((View)activityView,true);
                        attempts=0;placementAttempts=0;frameAttempts=0;
                        // Surface visibility takes effect during traversal. Check
                        // on the following frame so we cannot accept its old Surface.
                        root.postOnAnimation(()->{
                            if(generation==visibilityGeneration&&visible())awaitDisplay();
                        });
                    }
                });
            }else state("paused","地图已隐藏");
        }
        void state(String phase,String reason){
            Map<String,Object> next=new HashMap<>();next.put("phase",phase);next.put("reason",reason);next.put("ready","ready".equals(phase));
            if(hasPreview&&previewJpeg!=null){next.put("previewBytes",previewJpeg);next.put("previewRevision",previewRevision);}
            if(next.equals(status))return;
            status=next;
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
                // Do not move a visible full-screen map before HOME has drawn.
                // Its pending stop must finish first, otherwise Android 9 can
                // retain the old transparent UI Surface next to the resized one.
                if(textures instanceof io.flutter.embedding.engine.renderer.FlutterRenderer){
                    io.flutter.embedding.engine.renderer.FlutterRenderer renderer=(io.flutter.embedding.engine.renderer.FlutterRenderer)textures;
                    if(!renderer.isDisplayingFlutterUi()){
                        if(++attempts<80){handler.postDelayed(this::awaitDisplay,50);return;}
                        throw new IllegalStateException("Launcher frame timeout");
                    }
                }
                if(firstFrameAt==0)firstFrameAt=android.os.SystemClock.uptimeMillis();
                if(android.os.SystemClock.uptimeMillis()-firstFrameAt<200){handler.postDelayed(this::awaitDisplay,50);return;}
                if(started&&boundDisplay==display&&displayId==actualId){
                    activityView.getClass().getMethod("onLocationChanged").invoke(activityView);
                    activateMap();
                    verifyPlacement();return;
                }
                started=false;boundDisplay=display;displayId=actualId;
                activateMap();
                started=true;placementAttempts=0;state("loading","正在连接地图画面");handler.postDelayed(this::verifyPlacement,250);
            }catch(Throwable e){fail(e);}
        }
        void activateMap()throws Exception{
                if(activatedGeneration==visibilityGeneration)return;
                Intent intent=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).displayIntent();
                if(intent==null)throw new IllegalStateException("Navigation removed");
                // Reusing AMap's singleTask through startActivity can first
                // foreground its old default-display task and stop this host,
                // cancelling placement. Move an existing task before launching.
                String pkg=new NavigationApps(activity,activity.getSharedPreferences("launcher",0)).selected();
                ComponentName existing=placeExistingTask(pkg);
                // Some AMap builds advertise UsbFillActivity as their launcher.
                // It redirects via the default display. Deliver to the actual
                // task component we just moved instead of launching that proxy.
                if(existing!=null)intent.setComponent(existing);
                // Moving an existing stack alone can leave AMap paused with
                // stale guidance UI. Activate it on its target display once,
                // after moving, so singleTask receives its normal intent.
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activityView.getClass().getMethod("startActivity",Intent.class).invoke(activityView,intent);
                activationCount++;activatedGeneration=visibilityGeneration;
        }
        ComponentName placeExistingTask(String pkg)throws Exception{
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
                return ComponentName.unflattenFromString(names[0]);
            }
            return null;
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
        // Main-thread ownership: sample cannot be reused or released until
        // PixelCopy AND the worker have handed ownership back in finishCopy().
        void dropPreview(){
            handler.removeCallbacks(refreshPreview);
            previewGeneration++;hasPreview=false;previewReleasePending=true;
            if(activeDraw!=null)activeDraw.cancelled=true;
            if(!copying)freePreview();
            state(String.valueOf(status.getOrDefault("phase","paused")),
                    String.valueOf(status.getOrDefault("reason","地图已隐藏")));
        }
        void freePreview(){
            previewJpeg=null;
            if(sample!=null){sample.recycle();sample=null;}
            previewWidth=previewHeight=0;previewReleasePending=false;
        }
        void finishCopy(int generation,int previewEpoch,boolean restoring,boolean content,byte[] encoded){
            copying=false;activeDraw=null;
            boolean stale=disposed||generation!=visibilityGeneration||previewEpoch!=previewGeneration||!visible();
            if(previewReleasePending||disposed)freePreview();
            if(stale){
                // A trim may invalidate the only restoration sample. Keep the
                // readiness probe alive without keeping a preview buffer.
                if(!disposed&&visible()&&restoring&&generation==visibilityGeneration)
                    handler.postDelayed(()->captureFrame(true),80);
                return;
            }
            if(previewSuppressed&&sample!=null){sample.recycle();sample=null;}
            if(content){
                if(encoded!=null){previewJpeg=encoded;previewRevision++;hasPreview=true;}
                frameAttempts=0;state("ready","地图已进入卡片");
                handler.removeCallbacks(refreshPreview);
                if(!previewSuppressed)handler.postDelayed(refreshPreview,4000);
                else freePreview();
            }else if(restoring&&++frameAttempts<30)handler.postDelayed(()->captureFrame(true),80);
            else if(restoring)state("unavailable","地图未恢复画面，请重试或全屏打开");
            else if(!previewSuppressed)handler.postDelayed(refreshPreview,4000);
        }
        final class PreviewDraw implements Runnable {
            final Bitmap frame;
            final int generation,previewEpoch;
            final boolean restoring;
            volatile boolean cancelled;
            PreviewDraw(Bitmap frame,int generation,int previewEpoch,boolean restoring){
                this.frame=frame;this.generation=generation;
                this.previewEpoch=previewEpoch;this.restoring=restoring;
            }
            @Override public void run(){
                byte[] encoded=null;
                try{
                    if(!cancelled){
                        java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();
                        if(frame.compress(Bitmap.CompressFormat.JPEG,82,out)&&!cancelled)encoded=out.toByteArray();
                    }
                }catch(RuntimeException e){android.util.Log.d("UniMap","Preview encoding: "+e.getClass().getSimpleName());}
                finally{
                    final byte[] result=cancelled?null:encoded;
                    copyHandler.post(()->finishCopy(generation,previewEpoch,restoring,true,result));
                }
            }
        }
        void captureFrame(boolean restoring){
            if(disposed||!visible()||activityView==null||(!restoring&&previewSuppressed))return;
            if(copying){if(restoring)handler.postDelayed(()->captureFrame(true),80);return;}
            SurfaceView surface=mapSurface((View)activityView);
            if(surface==null||!surface.getHolder().getSurface().isValid()||surface.getWidth()<2||surface.getHeight()<2){
                if(restoring&&++frameAttempts<30)handler.postDelayed(()->captureFrame(true),80);return;
            }
            float scale=Math.min(1f,(float)PREVIEW_MAX_EDGE/Math.max(surface.getWidth(),surface.getHeight()));
            int width=Math.max(2,Math.round(surface.getWidth()*scale));
            int height=Math.max(2,Math.round(surface.getHeight()*scale));
            if(sample!=null&&(sample.getWidth()!=width||sample.getHeight()!=height)){
                sample.recycle();sample=null;
            }
            if(sample==null)sample=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);
            final Bitmap frame=sample;
            final int generation=visibilityGeneration,previewEpoch=previewGeneration;
            copying=true;
            try{PixelCopy.request(surface,frame,result->{
                if(disposed||generation!=visibilityGeneration||previewEpoch!=previewGeneration||!visible()){
                    finishCopy(generation,previewEpoch,restoring,false,null);return;
                }
                boolean content=result==PixelCopy.SUCCESS&&hasContent(frame);
                if(!content||previewSuppressed){finishCopy(generation,previewEpoch,restoring,content,null);return;}
                try{
                    previewWidth=width;previewHeight=height;
                    PreviewDraw draw=new PreviewDraw(frame,generation,previewEpoch,restoring);
                    activeDraw=draw;previewWorker.execute(draw);
                }catch(RuntimeException e){finishCopy(generation,previewEpoch,restoring,true,null);}
            },copyHandler);}catch(RuntimeException e){finishCopy(generation,previewEpoch,restoring,false,null);}
        }
        void release(){
            handler.removeCallbacksAndMessages(null);visibilityGeneration++;started=false;displayId=-1;boundDisplay=null;
            activatedGeneration=-1;firstFrameAt=0;
            dropPreview();
            if(activityView!=null)try{activityView.getClass().getMethod("release").invoke(activityView);}catch(Throwable ignored){}
            root.removeAllViews();activityView=null;
        }
        @Override public View getView(){return root;}
        @Override public void dispose(){if(disposed)return;disposed=true;release();channel.setMethodCallHandler(null);views.remove(id);}
    }
}
