import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

/** Shell-only diagnostic helper: injects a swipe at 60 Hz, never a busy loop. */
public final class PacedInput {
    public static void main(String[] args) throws Exception {
        if (args.length != 5) throw new IllegalArgumentException("x0 y0 x1 y1 durationMs");
        float x0=Float.parseFloat(args[0]), y0=Float.parseFloat(args[1]);
        float x1=Float.parseFloat(args[2]), y1=Float.parseFloat(args[3]);
        int duration=Integer.parseInt(args[4]);
        if (duration<16 || duration>5000) throw new IllegalArgumentException("duration 16..5000");
        Class<?> type=Class.forName("android.hardware.input.InputManager");
        Object manager=type.getMethod("getInstance").invoke(null);
        Method inject=type.getMethod("injectInputEvent",InputEvent.class,int.class);
        long start=SystemClock.uptimeMillis();
        int frames=Math.max(1,Math.round(duration*60f/1000f));
        int sent=0;
        boolean down=false;
        System.out.println("BEGIN uptimeMs="+start+" plannedMoves="+frames);
        try {
            send(manager,inject,start,start,MotionEvent.ACTION_DOWN,x0,y0);down=true;
            for(int i=1;i<=frames;i++) {
                long target=start+Math.round(i*duration/(double)frames);
                long wait=target-SystemClock.uptimeMillis();
                if(wait>0) SystemClock.sleep(wait);
                float fraction=i/(float)frames;
                send(manager,inject,start,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,
                     x0+(x1-x0)*fraction,y0+(y1-y0)*fraction);sent++;
            }
            send(manager,inject,start,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x1,y1);down=false;
        } finally {
            if(down) send(manager,inject,start,SystemClock.uptimeMillis(),MotionEvent.ACTION_CANCEL,x1,y1);
        }
        System.out.println("END uptimeMs="+SystemClock.uptimeMillis()+" moves="+sent);
    }
    private static void send(Object manager,Method inject,long down,long when,int action,float x,float y) throws Exception {
        MotionEvent event=MotionEvent.obtain(down,when,action,x,y,0);
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        try {
            if (!Boolean.TRUE.equals(inject.invoke(manager,event,0)))
                throw new IllegalStateException("Input injection rejected");
        } finally {event.recycle();}
    }
}
