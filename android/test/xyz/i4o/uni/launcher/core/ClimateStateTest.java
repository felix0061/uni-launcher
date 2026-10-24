package xyz.i4o.uni.launcher.core;

public final class ClimateStateTest {
    private static int checks;
    private static void check(boolean b,String message){checks++;if(!b)throw new AssertionError(message);}
    public static void main(String[] args){
        ClimateState c=new ClimateState();
        for(int i=0;i<100;i++)c.apply("temp-up","left","");
        check(c.left==30,"upper limit");check(c.right==22.5,"independent zones");
        for(int i=0;i<100;i++)c.apply("temp-down","left","");
        check(c.left==16,"lower limit");
        c.apply("climate-mode","","sync");check(c.right==16,"sync aligns right");
        c.apply("temp-up","right","");check(c.left==16.5&&c.right==16.5,"sync both directions");
        for(int i=0;i<30;i++)c.apply("fan-up","","");check(c.fan==7,"fan upper bound");
        for(int i=0;i<30;i++)c.apply("fan-down","","");check(c.fan==1,"fan lower bound");
        check(!c.apply("temp-up","rear",""),"reject unknown zone");
        check(!c.apply("climate-mode","","defrost"),"reject unverified modes");
        check(!c.apply("write-property","",""),"reject unknown command");
        check(!CommandPolicy.isClimateAction("set-can"),"no arbitrary transport");
        System.out.println("ClimateState: "+checks+" checks passed");
    }
}
