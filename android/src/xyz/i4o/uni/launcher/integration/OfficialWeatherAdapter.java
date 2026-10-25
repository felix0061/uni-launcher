package xyz.i4o.uni.launcher.integration;

import android.content.*;
import android.os.*;
import org.json.JSONObject;
import java.util.Calendar;
import java.util.regex.*;

/** Read-only XCHome V2023-08-03 callback contract, verified from installed APK.
 * No external weather API, fabricated sample or writes to the source's data. */
public final class OfficialWeatherAdapter {
    private static final String SERVICE="ecarx.home.IWeatherCallback", CALLBACK="ecarx.home.IWeatherInfo";
    private static final String[] CONDITIONS={"晴","多云","阴","阵雨","雷阵雨","雷阵雨伴冰雹","雨夹雪","小雨","中雨","大雨","暴雨","大暴雨","特大暴雨","阵雪","小雪","中雪","大雪","暴雪","雾","冻雨","沙尘暴","小到中雨","中到大雨","大到暴雨","暴雨到大暴雨","大暴雨到特大暴雨","小到中雪","中到大雪","大到暴雪","浮尘","扬沙","强沙尘暴"};
    private final Context context;
    private final Runnable changed;
    private final Handler main=new Handler(Looper.getMainLooper());
    private boolean bound,connected;
    private String reason="等待原车天气服务";
    private JSONObject data=new JSONObject();
    private final Binder callback=new Binder(){
        @Override protected boolean onTransact(int code,Parcel in,Parcel out,int flags)throws RemoteException{
            if(code==INTERFACE_TRANSACTION){if(out!=null)out.writeString(CALLBACK);return true;}
            if(code==1){
                in.enforceInterface(CALLBACK);final String raw=in.readString();
                if(raw!=null&&raw.length()<=8192)main.post(()->receive(raw));
                if(out!=null)out.writeNoException();return true;
            }return super.onTransact(code,in,out,flags);
        }
    };
    private final ServiceConnection connection=new ServiceConnection(){
        public void onServiceConnected(ComponentName name,IBinder service){
            Parcel in=Parcel.obtain(),out=Parcel.obtain();
            try{
                if(!SERVICE.equals(service.getInterfaceDescriptor()))throw new IllegalStateException("Weather service identity mismatch");
                in.writeInterfaceToken(SERVICE);in.writeStrongBinder(callback);
                if(!service.transact(1,in,out,0))throw new IllegalStateException("Weather callback unsupported");
                out.readException();connected=out.readInt()!=0;
                reason=connected?"等待原车天气回调":"原车天气注册未完成";
            }catch(Exception e){connected=false;reason="原车天气连接暂不可用";android.util.Log.w("UniWeather","Unable to register OEM weather callback",e);}
            finally{in.recycle();out.recycle();}
            changed.run();
        }
        public void onServiceDisconnected(ComponentName name){connected=false;reason="原车天气服务已断开";changed.run();}
    };
    public OfficialWeatherAdapter(Context context,Runnable changed){this.context=context;this.changed=changed;}
    public void start(){
        if(bound)return;
        try{
            context.getPackageManager().getApplicationInfo("com.ecarx.smartcloud",0);
            Intent intent=new Intent("ecarx.intent.action.smartcloud.core.service")
                .setComponent(new ComponentName("com.ecarx.smartcloud","ecarx.home.service.CoreService"));
            bound=context.bindService(intent,connection,Context.BIND_AUTO_CREATE);
            if(!bound)reason="原车天气服务未就绪";
        }catch(Exception e){reason="此设备未提供原车天气服务";}
    }
    private void receive(String raw){
        try{
            JSONObject packet=new JSONObject(raw);String temp=packet.optString("temprature","").replace('−','-').trim();
            Matcher match=Pattern.compile("^[+-]?[0-9]+(?:\\.[0-9]+)?").matcher(temp);
            String city=packet.optString("city",""),area=packet.optString("area",""),code=packet.optString("code","");
            if(!match.find()||(city.isEmpty()&&area.isEmpty())||code.isEmpty()){reason="原车天气暂未返回当前城市数据";changed.run();return;}
            double degrees=Double.parseDouble(match.group());
            if(degrees< -90||degrees>70||city.length()>80||area.length()>80||code.length()>8)return;
            int numeric=-1;try{numeric=Integer.parseInt(code);}catch(NumberFormatException ignored){}
            String description=numeric>=0&&numeric<CONDITIONS.length?CONDITIONS[numeric]:numeric==53?"霾":"未知";
            data=new JSONObject().put("available",true).put("city",area.isEmpty()?city:area).put("region",city)
                .put("temperature",degrees==Math.rint(degrees)?(Object)(int)degrees:degrees)
                .put("code",code).put("condition",description).put("description",description)
                .put("source","原车天气").put("sourcePackage","com.ecarx.smartcloud")
                .put("syncedAtMs",System.currentTimeMillis());
            reason="";changed.run();
        }catch(Exception e){reason="原车天气数据格式暂不支持";changed.run();}
    }
    public JSONObject snapshot(){
        try{
            Calendar time=Calendar.getInstance();int minute=time.get(Calendar.HOUR_OF_DAY)*60+time.get(Calendar.MINUTE);
            return new JSONObject(data.toString()).put("connected",connected).put("reason",reason)
                .put("night",minute<360||minute>1080).put("available",data.optBoolean("available",false));
        }catch(Exception e){return new JSONObject();}
    }
}
