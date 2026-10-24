package xyz.i4o.uni.launcher.integration;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.json.JSONObject;

/** Bounded-rate background polling: no synchronous Binder getter in Flutter builds. */
public final class VehicleTelemetry implements VehicleAdapter {
    private final Context context;
    private final Runnable changed;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ScheduledExecutorService executor=Executors.newSingleThreadScheduledExecutor();
    private java.util.concurrent.ScheduledFuture<?> task;
    private volatile JSONObject state=new JSONObject();
    private volatile int generation;
    public VehicleTelemetry(Context context,Runnable changed){this.context=context.getApplicationContext();this.changed=changed;}
    public synchronized void start(){
        if(task!=null)return;
        final int epoch=++generation;
        state=unavailable("正在读取车辆状态");
        main.postDelayed(new Runnable(){public void run(){if(epoch!=generation)return;changed.run();main.postDelayed(this,1000);}},1000);
        task=executor.scheduleWithFixedDelay(new Runnable(){
            final LegacyVehicleReader legacy=new LegacyVehicleReader(context);
            JSONObject official;long lastProbe;
            public void run(){
                if(epoch!=generation)return;
                try{
                    if(official==null||System.currentTimeMillis()-lastProbe>30000){official=new OfficialVehicleAdapter(context).snapshot();lastProbe=System.currentTimeMillis();}
                    JSONObject next=legacy.read();next.put("official",official);
                    if(epoch==generation)state=next;
                }catch(Throwable e){if(epoch==generation)state=unavailable("车辆读取暂不可用");}
            }
        },0,1000,TimeUnit.MILLISECONDS);
    }
    private JSONObject unavailable(String reason){JSONObject j=new JSONObject();try{j.put("connected",false).put("writable",false).put("reason",reason).put("climate",new JSONObject()).put("fields",new JSONObject()).put("seatCapabilities",new JSONObject());}catch(Exception ignored){}return j;}
    public JSONObject snapshot(){JSONObject current=state;long at=current.optLong("updatedAtMs");return at>0&&System.currentTimeMillis()-at>5000?unavailable("车辆数据已过期，等待服务恢复"):current;}
    public boolean command(String action,String zone,String mode){return false;}
    public synchronized void stop(){generation++;main.removeCallbacksAndMessages(null);if(task!=null){task.cancel(false);task=null;}state=unavailable("车辆数据读取已暂停");}
    public void close(){stop();executor.shutdownNow();}
}
