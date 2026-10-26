package xyz.i4o.uni.launcher;

import android.content.Context;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;

/** Application-scoped factory; engines share GPU/font/snapshot resources.
 * Owners still destroy their own engines. The group removes dead engines.
 */
final class LauncherEngines {
    private static FlutterEngineGroup group;
    private static int live;
    private LauncherEngines(){}
    static synchronized FlutterEngine create(Context context,String entrypoint,boolean plugins){
        Context app=context.getApplicationContext();
        if(group==null)group=new FlutterEngineGroup(app);
        DartExecutor.DartEntrypoint dart="main".equals(entrypoint)?DartExecutor.DartEntrypoint.createDefault():
            new DartExecutor.DartEntrypoint(FlutterInjector.instance().flutterLoader().findAppBundlePath(),"package:uni_launcher/main.dart",entrypoint);
        FlutterEngine engine=group.createAndRunEngine(new FlutterEngineGroup.Options(app)
            .setDartEntrypoint(dart).setAutomaticallyRegisterPlugins(plugins));
        live++;
        engine.addEngineLifecycleListener(new FlutterEngine.EngineLifecycleListener(){
            public void onPreEngineRestart(){}
            public void onEngineWillDestroy(){synchronized(LauncherEngines.class){live--;}}
        });
        return engine;
    }
    static synchronized int liveCount(){return live;}
}
