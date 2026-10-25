package xyz.i4o.uni.launcher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.FutureTask;
import org.json.JSONObject;
import org.json.JSONArray;
import xyz.i4o.uni.launcher.core.ClimateState;
import xyz.i4o.uni.launcher.core.CommandPolicy;
import xyz.i4o.uni.launcher.integration.*;

/** One Application-scoped native data source for all Flutter engines.
 * Adapter access and listener delivery are serialized on Android's main thread.
 */
public final class LauncherRuntime {
    private static volatile LauncherRuntime instance;
    private static final Handler main=new Handler(Looper.getMainLooper());
    private final Context context;
    private final SharedPreferences prefs;
    private final AppRepository apps;
    private final OfficialCatalog catalog;
    private final MediaAdapter media;
    private final VehicleTelemetry vehicle;
    private final NavigationApps navigation;
    private final OfficialWeatherAdapter weather;
    private final SystemStatusAdapter systemStatus;
    private final SystemCalendarAdapter calendar;
    private final ClimateState simulator=new ClimateState();
    private final Map<Object,Runnable> listeners=new IdentityHashMap<>();
    private JSONArray installed;
    private boolean homeVisible;
    private boolean desktopContent=true;
    private boolean demoPlaying=true;
    private int demoTrack;
    private long demoPositionMs,demoSampleAt=android.os.SystemClock.elapsedRealtime();
    private final BroadcastReceiver packages=new BroadcastReceiver(){
        @Override public void onReceive(Context c,Intent i){installed=apps.refresh();publish();}
    };

    public static LauncherRuntime get(Context context){
        LauncherRuntime current=instance;
        if(current!=null)return current;
        Context application=context.getApplicationContext();
        if(application==null)throw new IllegalArgumentException("Application context required");
        return onMain(()->{
            if(instance==null)instance=new LauncherRuntime(application);
            return instance;
        });
    }

    private LauncherRuntime(Context application){
        context=application;
        prefs=context.getSharedPreferences("launcher",Context.MODE_PRIVATE);
        if(!prefs.contains("demo"))prefs.edit().putBoolean("demo",Build.FINGERPRINT.contains("generic")||Build.MODEL.contains("sdk_gphone")||Build.MODEL.contains("Android SDK")).apply();
        apps=new AppRepository(context);catalog=new OfficialCatalog(context);
        vehicle=new VehicleTelemetry(context,this::publish);navigation=new NavigationApps(context,prefs);
        media=new MediaAdapter(context,this::publish);weather=new OfficialWeatherAdapter(context,this::publish);systemStatus=new SystemStatusAdapter(context,this::publish);calendar=new SystemCalendarAdapter(context,this::publish);
        // setPreferredPackage() starts MediaAdapter; defer it until the first owner.
        installed=apps.refresh();
        IntentFilter filter=new IntentFilter();
        filter.addAction(Intent.ACTION_PACKAGE_ADDED);filter.addAction(Intent.ACTION_PACKAGE_REMOVED);filter.addAction(Intent.ACTION_PACKAGE_CHANGED);filter.addDataScheme("package");
        // One Application-lifetime package receiver/cache, independent of windows.
        context.registerReceiver(packages,filter);
    }

    public SharedPreferences prefs(){return prefs;}

    public JSONObject snapshot(){
        // Detach nested JSON so window geometry cannot mutate shared state.
        return onMain(()->new JSONObject(buildSnapshot().toString()));
    }

    public boolean saveDesign(String raw){return onMain(()->saveDesignOnMain(raw));}

    /** true means recognized, including input rejected by the original gates. */
    public boolean handle(JSONObject request)throws Exception{return callOnMain(()->handleOnMain(request));}

    private long demoPosition(){return demoPositionMs+(demoPlaying?Math.max(0,android.os.SystemClock.elapsedRealtime()-demoSampleAt):0);}
    private JSONObject buildSnapshot(){
        JSONObject state=new JSONObject();try{
            JSONObject climate=new JSONObject().put("left",simulator.left).put("right",simulator.right).put("fan",simulator.fan).put("power",simulator.power)
                .put("auto",simulator.auto).put("ac",simulator.ac).put("sync",simulator.sync).put("recirc",simulator.recirc)
                .put("driverHeat",simulator.driverHeat).put("driverVent",simulator.driverVent).put("passengerHeat",simulator.passengerHeat);
            JSONObject telemetry=vehicle.snapshot();
            if(!prefs.getBoolean("demo",false))climate=telemetry.optJSONObject("climate")==null?new JSONObject():telemetry.getJSONObject("climate");
            state.put("systemStatus",systemStatus.snapshot()).put("weather",weather.snapshot()).put("calendar",calendar.snapshot()).put("navigation",navigation.snapshot()).put("integrationPreferences",new JSONObject().put("mediaPackage",prefs.getString("mediaPackage","auto"))) ;
            state.put("demo",prefs.getBoolean("demo",false)).put("hideNavigation",prefs.getBoolean("hideNavigation",false))
                .put("globalNavigation",prefs.getBoolean("globalNavigation",false))
                .put("globalNavigationGranted",context.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS")==android.content.pm.PackageManager.PERMISSION_GRANTED)
                .put("dark",(context.getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES)
                .put("apps",installed).put("climate",climate).put("vehicle",telemetry).put("media",media.snapshot().put("preferredPackage",prefs.getString("mediaPackage","auto"))).put("version",xyz.i4o.uni.launcher.BuildConfig.VERSION_NAME+"-flutter");
            state.put("desktopSelected",homeVisible&&desktopContent);
            state.put("savedDesign",prefs.getString("savedDesign", "")).put("runtimeOwnerCount",listeners.size());
            if(prefs.getBoolean("demo",false))state.put("media",new JSONObject().put("available",true).put("playing",demoPlaying)
                .put("title",demoTrack%2==0?"向海而行":"山海之间").put("artist",demoTrack%2==0?"Coastline":"Northbound").put("collection","晨间驾驶歌单").put("source","simulator").put("canNext",true).put("canPrevious",true).put("canToggle",true).put("canSeek",true)
                .put("lyrics","[00:00.00]晨光沿着海岸慢慢亮起\n[00:03.00]风把远方带进了呼吸\n[00:06.00]穿过山与海的交界\n[00:09.00]每一程都有新的风景\n[00:12.00]跟着潮声向前去\n[00:15.00]让今天从容开启")
                .put("lyricsSource","demo").put("durationMs",258000).put("positionMs",demoPosition()).put("positionKnown",true)
                .put("sampledAtMs",System.currentTimeMillis()).put("speed",1));
        }catch(Exception e){android.util.Log.e("UniState","Snapshot failed",e);}return state;
    }
    private boolean saveDesignOnMain(String raw){
            if(raw==null||raw.length()>65536)return false;
            try{
                JSONObject data=new JSONObject(raw);JSONObject p=data.getJSONObject("preferences");
                int version=data.optInt("version");
                if((version<4||version>5)||!p.optString("custom").matches("#[0-9a-fA-F]{6}"))return false;
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
                if(version>=5&&data.has("appNames")){
                    JSONObject names=data.getJSONObject("appNames");
                    if(names.length()>300)return false;
                    java.util.Iterator<String> keys=names.keys();
                    while(keys.hasNext()){
                        String key=keys.next(),name=names.optString(key,"");
                        if(key.length()==0||key.length()>255||name.length()>96||name.indexOf('\n')>=0||name.indexOf('\r')>=0)return false;
                    }
                }
                if(!prefs.edit().putString("savedDesign",raw).commit())return false;
            }catch(Exception e){return false;}
            publish();return true;
        }
    private boolean handleOnMain(JSONObject request)throws Exception{
        String action=request.optString("action"),value=request.optString("value");
        if("demo-mode".equals(action)){
            prefs.edit().putBoolean("demo",request.optBoolean("enabled",false)).commit();publish();return true;
        }
        if("select-player".equals(action)||"select-navigation".equals(action)){
            if(!"auto".equals(value)&&context.getPackageManager().getLaunchIntentForPackage(value)==null){toast("所选应用未安装或不可启动");return true;}
            String key="select-player".equals(action)?"mediaPackage":"navigationPackage";
            prefs.edit().putString(key,value).commit();
            if("select-player".equals(action)&&!listeners.isEmpty())media.setPreferredPackage(value);
            publish();return true;
        }
        if("embed-navigation".equals(action)){prefs.edit().putBoolean("embedNavigation",request.optBoolean("enabled",true)).commit();publish();return true;}
        if("calendar-refresh".equals(action)){calendar.refresh();publish();return true;}
        if("launch-navigation".equals(action)){if(!navigation.launchFullscreen())toast("请选择已安装的导航应用");return true;}
        if("launch-player".equals(action)){
            String selected=prefs.getString("mediaPackage","auto");
            if("auto".equals(selected))selected=media.snapshot().optString("source","ecarx.xsf.mediacenter");
            if(!apps.launchPackage(selected))toast("请选择已安装的音乐播放器");return true;
        }
        if("refresh".equals(action)){installed=apps.refresh();if(!listeners.isEmpty()){media.start();vehicle.stop();vehicle.start();}publish();return true;}
        if("app-info".equals(action)){if(!apps.showInfo(value))toast("无法打开应用信息");return true;}
        if("request-uninstall".equals(action)){if(!apps.requestUninstall(value))toast("该应用不可卸载");return true;}
        if("launch-app".equals(action)){if(!apps.launch(value))toast("应用未安装或无法启动");return true;}
        if("media-access".equals(action)){try{context.startActivity(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));}catch(Exception e){toast("系统没有提供媒体授权入口");}return true;}
        if("official-widget".equals(action)){
            if(catalog.providers(value).isEmpty()){toast("没有对应的原厂卡片");return true;}
            context.startActivity(new Intent(context,OfficialWidgetActivity.class).putExtra("type",value).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));return true;
        }
        if("open-official".equals(action)){
            if("camera".equals(value)){
                if(!apps.launchOfficialCamera(vehicle.cameraCapability())){
                    toast("当前车辆未提供原车全景入口");GlobalDockService.resumeAfterCameraLaunchFailure();
                }
                return true;
            }
            if(!apps.launchPackage(catalog.packageFor(value)))toast("此设备未安装对应原车应用");return true;
        }
        if(CommandPolicy.isClimateAction(action)){
            boolean demo=prefs.getBoolean("demo",false);
            boolean ok=demo?simulator.apply(action,request.optString("zone"),value):vehicle.command(action,request.optString("zone"),value);
            if(!ok)toast("尚未连接空调，可从空调面板打开原车应用");publish();return true;
        }
        if("seek".equals(action)){
            long position;try{position=Long.parseLong(value);}catch(NumberFormatException e){return true;}
            if(position<0)return true;
            if(prefs.getBoolean("demo",false)){demoPositionMs=Math.min(258000,position);demoSampleAt=android.os.SystemClock.elapsedRealtime();}
            else if(!media.command(action,position))toast("当前音源不支持调整进度");
            publish();return true;
        }
        if("toggle-play".equals(action)||"previous".equals(action)||"next".equals(action)){
            if(prefs.getBoolean("demo",false)){if("toggle-play".equals(action)){demoPositionMs=demoPosition();demoPlaying=!demoPlaying;}
                else {demoTrack+="previous".equals(action)?-1:1;demoPositionMs=0;}
                demoSampleAt=android.os.SystemClock.elapsedRealtime();publish();return true;}
            if(!media.command(action))toast("当前音源不支持此操作，或尚未授权媒体访问");publish();return true;
        }
        return false;
    }

    public void addListener(Object owner,Runnable listener){
        if(owner==null||listener==null)throw new IllegalArgumentException("Owner and listener required");
        onMain(()->{
            boolean first=listeners.isEmpty();
            listeners.put(owner,listener);
            if(first){media.setPreferredPackage(prefs.getString("mediaPackage","auto"));vehicle.start();weather.start();systemStatus.start();calendar.start();}
            publish();return null;
        });
    }

    public void removeListener(Object owner){
        onMain(()->{
            if(listeners.remove(owner)!=null&&listeners.isEmpty()){media.stop();vehicle.stop();systemStatus.stop();calendar.stop();}
            return null;
        });
    }

    public void publish(){
        onMain(()->{
            // An owner may remove itself/another owner during notification.
            for(Map.Entry<Object,Runnable> entry:new IdentityHashMap<>(listeners).entrySet()){
                if(listeners.get(entry.getKey())!=entry.getValue())continue;
                try{entry.getValue().run();}
                catch(RuntimeException e){android.util.Log.w("UniState","Listener failed",e);}
            }
            return null;
        });
    }

    public void setDesktopContent(boolean selected){
        onMain(()->{if(desktopContent!=selected){desktopContent=selected;publish();}return null;});
    }
    public boolean homeVisible(){return onMain(()->homeVisible);}

    public void setHomeVisible(boolean visible){
        onMain(()->{if(homeVisible!=visible){homeVisible=visible;publish();}return null;});
    }

    private void toast(String text){Toast.makeText(context,text,Toast.LENGTH_SHORT).show();}

    private static <T> T callOnMain(Callable<T> call)throws Exception{
        if(Looper.myLooper()==Looper.getMainLooper())return call.call();
        FutureTask<T> task=new FutureTask<>(call);
        if(!main.post(task))throw new IllegalStateException("Main looper unavailable");
        try{return task.get();}
        catch(InterruptedException e){Thread.currentThread().interrupt();throw e;}
        catch(ExecutionException e){
            Throwable cause=e.getCause();
            if(cause instanceof Exception)throw (Exception)cause;
            if(cause instanceof Error)throw (Error)cause;
            throw new IllegalStateException(cause);
        }
    }

    private static <T> T onMain(Callable<T> call){
        try{return callOnMain(call);}
        catch(RuntimeException e){throw e;}
        catch(Exception e){throw new IllegalStateException(e);}
    }
}
