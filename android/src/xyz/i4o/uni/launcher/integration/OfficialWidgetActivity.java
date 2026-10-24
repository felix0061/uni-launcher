package xyz.i4o.uni.launcher.integration;

import android.app.Activity;
import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.widget.LinearLayout;
import android.widget.Button;
import android.widget.TextView;
import java.util.List;

/** Own host IDs only; never modifies the official Launcher's database or host. */
public final class OfficialWidgetActivity extends Activity {
    private AppWidgetHost host;
    private AppWidgetManager manager;
    private AppWidgetProviderInfo info;
    private int widgetId=-1;
    private String type;
    private boolean bound;
    private SharedPreferences prefs;
    private LinearLayout root;
    protected void onCreate(Bundle saved){
        super.onCreate(saved);host=new AppWidgetHost(this,75301);manager=AppWidgetManager.getInstance(this);
        prefs=getSharedPreferences("widgets",0);type=getIntent().getStringExtra("type");
        root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(32,16,32,16);setContentView(root);
        Button back=new Button(this);back.setText("‹ 返回桌面");back.setOnClickListener(new android.view.View.OnClickListener(){public void onClick(android.view.View v){finish();}});root.addView(back);
        List<ComponentName> candidates=new OfficialCatalog(this).providers(type);
        for(AppWidgetProviderInfo provider:manager.getInstalledProviders())if(candidates.contains(provider.provider)){info=provider;break;}
        if(info==null){message("此设备未安装对应原厂卡片。返回后仍可编辑桌面。");return;}
        widgetId=prefs.getInt(type,-1);
        if(widgetId!=-1){
            AppWidgetProviderInfo old=manager.getAppWidgetInfo(widgetId);
            if(old!=null&&info.provider.equals(old.provider)){bound=true;showWidget();return;}
            host.deleteAppWidgetId(widgetId);prefs.edit().remove(type).apply();widgetId=-1;
        }
        if(saved!=null)widgetId=saved.getInt("pendingId",-1);
        if(widgetId!=-1){
            AppWidgetProviderInfo restored=manager.getAppWidgetInfo(widgetId);
            if(restored!=null){bound=true;showWidget();}else message("等待系统授权后显示原厂卡片。");
            return;
        }
        widgetId=host.allocateAppWidgetId();
        try{
            if(manager.bindAppWidgetIdIfAllowed(widgetId,info.provider)){bound=true;showWidget();}
            else startActivityForResult(new Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,widgetId).putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER,info.provider),10);
        }catch(Exception e){cleanup();message("系统不允许绑定此原厂卡片。");}
    }
    private void message(String text){TextView t=new TextView(this);t.setText(text);t.setTextSize(24);root.addView(t);}
    private void showWidget(){
        prefs.edit().putInt(type,widgetId).apply();
        AppWidgetHostView view=host.createView(this,widgetId,info);view.setAppWidget(widgetId,info);
        root.addView(view,new LinearLayout.LayoutParams(-1,0,1));
        view.updateAppWidgetSize(null,600,320,1200,700);
    }
    protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==10){if(result==RESULT_OK&&manager.getAppWidgetInfo(widgetId)!=null){bound=true;showWidget();}else{cleanup();message("未授权。原厂卡片未绑定。");}}
    }
    private void cleanup(){if(!bound&&widgetId!=-1){host.deleteAppWidgetId(widgetId);widgetId=-1;}}
    protected void onSaveInstanceState(Bundle out){super.onSaveInstanceState(out);out.putInt("pendingId",widgetId);}
    protected void onStart(){super.onStart();try{host.startListening();}catch(Exception e){message("卡片服务暂不可用");}}
    protected void onStop(){host.stopListening();super.onStop();}
    protected void onDestroy(){if(isFinishing())cleanup();super.onDestroy();}
}
