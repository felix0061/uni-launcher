package xyz.i4o.uni.launcher.voice;

/** 纯命令规划：识别文本 → {action, value, zone, reply}，无 Android 依赖。
 * 车控类指令只在这里产出，云端大模型不参与车控（§9.5）。
 * 规则的顺序即优先级：更具体的意图排在更宽泛的前面。 */
public final class VoiceCommand {
    private VoiceCommand() {}

    public static final class Result {
        public final boolean recognized;
        public final String action, value, zone, reply;
        private Result(boolean recognized, String action, String value, String zone, String reply) {
            this.recognized = recognized; this.action = action; this.value = value;
            this.zone = zone; this.reply = reply;
        }
        static Result command(String action, String value, String zone, String reply) {
            return new Result(true, action, value, zone, reply);
        }
        static Result miss() { return new Result(false, null, null, null, null); }
    }

    public static Result parse(String raw) {
        if (raw == null) return Result.miss();
        final String t = normalize(raw);
        if (t.isEmpty()) return Result.miss();
        final String zone = zone(t);

        // ---- 音乐（§3.2 复用 MediaAdapter 动作） ----
        if (containsAny(t, "下一首", "下一曲", "切歌", "换一首", "再听一首")) return Result.command("next", null, null, "好的，下一首");
        if (containsAny(t, "上一首", "上一曲", "前一首")) return Result.command("previous", null, null, "好的，上一首");
        if (containsAny(t, "暂停", "停一下")) return Result.command("toggle-play", null, null, "已切换播放状态");
        if (containsAny(t, "继续播放", "接着放", "播放", "放歌", "放音乐", "来首歌")) return Result.command("toggle-play", null, null, "好的");

        // ---- 音量（LauncherRuntime 新增 AudioManager 通道） ----
        if (containsAny(t, "音量调大", "大点声", "声音大", "音量大", "响一点", "大声")) return Result.command("volume-up", null, null, "音量调大了");
        if (containsAny(t, "音量调小", "小点声", "声音小", "音量小", "轻一点", "小声")) return Result.command("volume-down", null, null, "音量调小了");
        if (containsAny(t, "静音", "别出声")) return Result.command("volume-mute", null, null, "已静音");

        // ---- 空调温度（语义：觉得热→降温，觉得冷→升温） ----
        if (containsAny(t, "太热", "好热", "热死", "很热", "热得")) return Result.command("temp-down", null, zone, "帮您降温");
        if (containsAny(t, "太冷", "好冷", "很冷", "冷死", "冷得")) return Result.command("temp-up", null, zone, "帮您升温");
        if (containsAny(t, "温度调高", "温度升高", "升高温度", "升温", "调热", "热一点", "温度高", "高一点温度")) return Result.command("temp-up", null, zone, "温度调高了");
        if (containsAny(t, "温度调低", "温度降低", "降低温度", "降温", "调冷", "冷一点", "温度低")) return Result.command("temp-down", null, zone, "温度调低了");

        // ---- 风量 ----
        if (containsAny(t, "风量调大", "风量升高", "风大", "风量大", "风量大一点", "加大风")) return Result.command("fan-up", null, null, "风量调大了");
        if (containsAny(t, "风量调小", "风量降低", "风小", "风量小", "风量小一点", "减小风")) return Result.command("fan-down", null, null, "风量调小了");

        // ---- 空调开关/模式 ----
        if (containsAny(t, "打开空调", "开空调", "空调打开", "空调开启")) return Result.command("climate-power", null, null, "好的，已为您调整空调");
        if (containsAny(t, "关闭空调", "关空调", "空调关闭", "空调关掉")) return Result.command("climate-power", null, null, "好的，已为您调整空调");
        if (containsAny(t, "自动空调", "空调自动", "打开自动")) return Result.command("climate-mode", "auto", null, "已切换自动空调");
        if (containsAny(t, "制冷", "冷气", "开冷气", "打开ac", "打开a/c")) return Result.command("climate-mode", "ac", null, "已切换制冷");
        if (containsAny(t, "内循环", "开内循环")) return Result.command("climate-mode", "recirc", null, "已切换循环模式");

        // ---- 座椅 ----
        if (containsAny(t, "座椅加热", "座椅加温", "加热座椅")) {
            int level = seatLevel(t);
            if (level >= 0) return Result.command("seat-heat", String.valueOf(level), zone, "座椅加热" + (level == 0 ? "已关闭" : level + "档"));
            return Result.command("seat-heat", "1", zone, "座椅加热已开启");
        }
        if (containsAny(t, "座椅通风", "通风座椅", "座椅吹风")) {
            int level = seatLevel(t);
            if (level >= 0) return Result.command("seat-vent", String.valueOf(level), "left", "座椅通风" + (level == 0 ? "已关闭" : level + "档"));
            return Result.command("seat-vent", "1", "left", "座椅通风已开启");
        }

        // ---- 氛围灯（车辆契约未验证前由服务回退 open-official） ----
        if (containsAny(t, "氛围灯", "环境灯", "车内灯光")) return Result.command("ambient-light", "toggle", null, "已为您打开氛围灯设置");

        // ---- 返回桌面 / 打开应用（复用现有动作） ----
        if (containsAny(t, "回桌面", "回主页", "返回桌面", "桌面")) return Result.command("show-home", null, null, "好的");

        return Result.miss();
    }

    private static String zone(String t) {
        if (containsAny(t, "副驾", "副驾驶", "右边", "乘客", "右侧")) return "right";
        return "left"; // 默认主驾
    }

    /** 提取 0..3 档位；「关/关闭」为 0，找不到为 -1（用默认值）。 */
    private static int seatLevel(String t) {
        if (containsAny(t, "关闭", "关掉", "关")) return 0;
        for (int i = 3; i >= 1; i--) if (t.contains(String.valueOf(i))) return i;
        return -1;
    }

    private static boolean containsAny(String t, String... words) {
        for (String w : words) if (t.contains(w)) return true;
        return false;
    }

    /** 去除标点与空白，统一小写，供关键词匹配使用。 */
    private static String normalize(String raw) {
        StringBuilder b = new StringBuilder(raw.length());
        for (int i = 0; i < raw.length(); i++) {
            char c = raw.charAt(i);
            if (Character.isWhitespace(c) || isPunct(c)) continue;
            b.append(Character.toLowerCase(c));
        }
        return b.toString();
    }

    private static boolean isPunct(char c) {
        return c == '，' || c == '。' || c == '！' || c == '？' || c == '、' || c == '；'
            || c == ',' || c == '.' || c == '!' || c == '?' || c == ';' || c == '：' || c == ':';
    }
}
