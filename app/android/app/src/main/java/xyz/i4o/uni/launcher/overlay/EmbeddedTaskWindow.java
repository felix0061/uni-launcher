package xyz.i4o.uni.launcher.overlay;

import android.app.ActivityOptions;
import android.content.*;
import android.graphics.PixelFormat;
import android.hardware.display.VirtualDisplay;
import android.os.*;
import android.util.DisplayMetrics;
import android.view.*;
import android.widget.FrameLayout;
import java.lang.reflect.Field;
import java.util.List;

/** Runs an unchanged, fullscreen-only system task in a bounded display. The
 * original Activity owns its rendering and task-card actions, not the launcher.
 * Hidden hosts retain their display to avoid destroying OEM initialization. */
public final class EmbeddedTaskWindow {
    private final Context context;
    private final WindowManager windows;
    private final Intent intent;
    private final String packageName;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final FrameLayout root;
    private final Object activityView;
    private final boolean customFooter;
    private final int visibleContentHeight;
    private VirtualDisplay display;
    private int displayId=-1,attempts;
    private boolean visible,closed,ready;
    public EmbeddedTaskWindow(Context context,Intent intent,Runnable dismiss)throws Exception{
        this.context=context;this.intent=intent;this.packageName=intent.getPackage();
        windows=(WindowManager)context.getSystemService(Context.WINDOW_SERVICE);
        root=new FrameLayout(context){@Override public boolean dispatchKeyEvent(KeyEvent event){
            if(event.getKeyCode()==KeyEvent.KEYCODE_BACK){if(event.getAction()==KeyEvent.ACTION_UP)dismiss.run();return true;}
            return super.dispatchKeyEvent(event);
        }};
        root.setBackgroundColor(android.graphics.Color.BLACK);
        root.setFocusableInTouchMode(true);
        root.setOnApplyWindowInsetsListener((v,i)->i.consumeSystemWindowInsets().consumeStableInsets());
        DisplayMetrics real=new DisplayMetrics();windows.getDefaultDisplay().getRealMetrics(real);
        int bar=Math.round(real.widthPixels*96f/1920f),workspace=real.heightPixels-bar;
        customFooter=knownFooterVersion()&&real.widthPixels==1920&&workspace==984;
        visibleContentHeight=customFooter?workspace-Math.round(real.widthPixels*120f/1920f):workspace;
        activityView=Class.forName("android.app.ActivityView").getConstructor(Context.class).newInstance(context);
        ((View)activityView).setBackgroundColor(android.graphics.Color.BLACK);
        if(customFooter){
            FrameLayout clip=new FrameLayout(context);clip.setClipChildren(true);clip.setClipToPadding(true);
            clip.setBackgroundColor(android.graphics.Color.BLACK);
            root.addView(clip,new FrameLayout.LayoutParams(-1,visibleContentHeight));
            clip.addView((View)activityView,new FrameLayout.LayoutParams(real.widthPixels,workspace));
        }else root.addView((View)activityView,new FrameLayout.LayoutParams(-1,-1));
        root.addOnLayoutChangeListener((v,l,t,r,b,ol,ot,rr,bb)->{
            if(visible){locationChanged();cropOriginalFooter();}
        });
        WindowManager.LayoutParams p=new WindowManager.LayoutParams(real.widthPixels,
            workspace,WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                |WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS|WindowManager.LayoutParams.FLAG_FULLSCREEN
                |WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,PixelFormat.OPAQUE);
        p.gravity=Gravity.TOP|Gravity.LEFT;p.setTitle("UNI System Task Workspace");
        root.setVisibility(View.INVISIBLE);windows.addView(root,p);
    }
    public void show(){
        visible=true;attempts=0;root.setVisibility(View.VISIBLE);surfaceVisibility(root,true);root.requestFocus();
        main.removeCallbacksAndMessages(null);main.post(this::cropOriginalFooter);main.postDelayed(this::attach,150);
    }
    public void hide(){visible=false;main.removeCallbacksAndMessages(null);surfaceVisibility(root,false);root.setVisibility(View.INVISIBLE);}
    public boolean ready(){return ready;}
    public int displayId(){return displayId;}
    public boolean clearSupported(){
        return customFooter;
    }
    private boolean knownFooterVersion(){
        try{android.content.pm.PackageInfo info=context.getPackageManager().getPackageInfo(packageName,0);
            return info.versionCode==25&&"V2023-08-16_793096d".equals(info.versionName);}
        catch(Exception e){return false;}
    }
    /** XCRecent V2023-08-16_793096d (25): btn_clear=[108,874,380,934]
     * in the 1920x984 display. Forward to that original button, not a separate
     * task-killing implementation. Never apply the coordinates to other builds. */
    public void clear(){
        if(!visible||!ready||!clearSupported())return;
        long down=SystemClock.uptimeMillis();
        MotionEvent press=MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,244,904,0);
        press.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);((View)activityView).dispatchTouchEvent(press);press.recycle();
        main.postDelayed(()->{
            if(!visible||closed)return;
            MotionEvent release=MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,244,904,0);
            release.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);((View)activityView).dispatchTouchEvent(release);release.recycle();
        },80);
    }
    private void surfaceVisibility(View view,boolean visible){
        if(view instanceof SurfaceView)view.setVisibility(visible?View.VISIBLE:View.GONE);
        if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++)surfaceVisibility(((ViewGroup)view).getChildAt(i),visible);
    }
    /** ActivityView renders through a separately composed SurfaceView. Parent
     * clipChildren alone therefore cannot hide XCRecent's legacy footer. Apply
     * the same crop to that surface so only the task-card area is composed. */
    private void cropOriginalFooter(){
        if(!customFooter)return;
        cropView((View)activityView,visibleContentHeight);
    }
    private void cropView(View view,int bottom){
        int width=Math.max(1,view.getWidth()),height=Math.max(1,view.getHeight());
        int cropped=Math.max(1,Math.min(bottom,height));
        view.setClipBounds(new android.graphics.Rect(0,0,width,cropped));
        if(view instanceof SurfaceView)cropSurface((SurfaceView)view,width,cropped);
        if(view instanceof ViewGroup){
            ViewGroup group=(ViewGroup)view;
            for(int i=0;i<group.getChildCount();i++){
                View child=group.getChildAt(i);
                cropView(child,Math.max(1,bottom-child.getTop()));
            }
        }
    }
    @android.annotation.SuppressLint("BlockedPrivateApi")
    private void cropSurface(SurfaceView surface,int width,int height){
        try{
            Field f=SurfaceView.class.getDeclaredField("mSurfaceControl");f.setAccessible(true);
            Object control=f.get(surface);if(control==null)return;
            Class<?> surfaceControl=Class.forName("android.view.SurfaceControl");
            Class<?> transaction=Class.forName("android.view.SurfaceControl$Transaction");
            Object tx=transaction.getConstructor().newInstance();
            try{
                transaction.getMethod("setWindowCrop",surfaceControl,android.graphics.Rect.class)
                    .invoke(tx,control,new android.graphics.Rect(0,0,width,height));
            }catch(NoSuchMethodException missing){
                transaction.getMethod("setWindowCrop",surfaceControl,int.class,int.class)
                    .invoke(tx,control,width,height);
            }
            transaction.getMethod("apply").invoke(tx);
            try{transaction.getMethod("close").invoke(tx);}catch(Exception ignored){}
        }catch(Exception e){android.util.Log.w("UniTaskWorkspace","Unable to crop system task surface",e);}
    }
    private void locationChanged(){try{activityView.getClass().getMethod("onLocationChanged").invoke(activityView);}catch(Exception ignored){}}
    private void attach(){
        if(closed||!visible)return;
        try{
            Field field=activityView.getClass().getDeclaredField("mVirtualDisplay");field.setAccessible(true);
            VirtualDisplay current=(VirtualDisplay)field.get(activityView);
            if(current==null||!current.getDisplay().isValid()||root.getWidth()==0){retry();return;}
            int id=current.getDisplay().getDisplayId();
            Object manager=Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);
            Class<?> api=Class.forName("android.app.IActivityManager");
            boolean found=false;
            for(Object stack:(List<?>)api.getMethod("getAllStackInfos").invoke(manager)){
                Class<?> type=stack.getClass();String[] names=(String[])type.getField("taskNames").get(stack);
                if(names==null)continue;
                for(String name:names)if(name!=null&&name.startsWith(packageName+"/")){
                    int old=type.getField("displayId").getInt(stack);
                    if(old!=id)api.getMethod("moveStackToDisplay",int.class,int.class).invoke(manager,type.getField("stackId").getInt(stack),id);
                    found=true;break;
                }
                if(found)break;
            }
            boolean launch=display!=current||displayId!=id||!ready||!found;
            display=current;displayId=id;locationChanged();
            cropOriginalFooter();
            if(launch){
                ActivityOptions options=ActivityOptions.makeBasic();options.setLaunchDisplayId(id);
                context.startActivity(new Intent(intent).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),options.toBundle());
            }
            ready=true;
        }catch(Exception e){android.util.Log.w("UniTaskWorkspace","Unable to attach system task",e);retry();}
    }
    private void retry(){if(++attempts<40)main.postDelayed(this::attach,150);}
    public void close(){
        if(closed)return;closed=true;main.removeCallbacksAndMessages(null);
        try{activityView.getClass().getMethod("release").invoke(activityView);}catch(Exception ignored){}
        if(root.getParent()!=null)windows.removeViewImmediate(root);
    }
}
