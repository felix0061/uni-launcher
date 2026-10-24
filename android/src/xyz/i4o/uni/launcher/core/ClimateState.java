package xyz.i4o.uni.launcher.core;

/** Explicit simulator state. Never treated as a vehicle observation. */
public final class ClimateState {
    public double left = 22.5, right = 22.5;
    public int fan = 3;
    public boolean power = true, auto = true, ac = true, sync = false, recirc = false;
    public boolean apply(String action, String zone, String mode) {
        if ("temp-up".equals(action) || "temp-down".equals(action)) {
            if (!CommandPolicy.validZone(zone)) return false;
            double next = CommandPolicy.temperature(("left".equals(zone) ? left : right) + ("temp-up".equals(action) ? .5 : -.5));
            if ("left".equals(zone)) left = next; else right = next;
            if (sync) left = right = next;
        } else if ("fan-up".equals(action) || "fan-down".equals(action)) {
            fan = CommandPolicy.fan(fan + ("fan-up".equals(action) ? 1 : -1));
        } else if ("climate-power".equals(action)) power = !power;
        else if ("climate-mode".equals(action)) {
            if (!CommandPolicy.validMode(mode)) return false;
            if ("auto".equals(mode)) auto = !auto;
            if ("ac".equals(mode)) ac = !ac;
            if ("recirc".equals(mode)) recirc = !recirc;
            if ("sync".equals(mode)) { sync = !sync; if (sync) right = left; }
        } else return false;
        return true;
    }
}
