package xyz.i4o.uni.launcher.core;

/** Input boundary shared by the simulator and future verified vehicle adapter. */
public final class CommandPolicy {
    private CommandPolicy() {}
    public static boolean isClimateAction(String action) {
        return "temp-up".equals(action) || "temp-down".equals(action) || "fan-up".equals(action)
            || "fan-down".equals(action) || "climate-power".equals(action) || "climate-mode".equals(action);
    }
    public static boolean validZone(String zone) { return "left".equals(zone) || "right".equals(zone); }
    public static boolean validMode(String mode) {
        return "auto".equals(mode) || "ac".equals(mode) || "sync".equals(mode) || "recirc".equals(mode);
    }
    public static double temperature(double value) { return Math.max(16, Math.min(30, Math.round(value * 2) / 2.0)); }
    public static int fan(int value) { return Math.max(1, Math.min(7, value)); }
}
