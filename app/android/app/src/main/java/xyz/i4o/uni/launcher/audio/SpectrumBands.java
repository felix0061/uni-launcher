package xyz.i4o.uni.launcher.audio;

/** Android Visualizer FFT is interleaved signed real/imaginary bytes (DC and
 * Nyquist occupy bytes 0/1). Only normalized logarithmic band energies escape. */
public final class SpectrumBands {
    public static final int COUNT=24;
    private SpectrumBands(){}
    public static double[] decode(byte[] fft,int sampleRateMilliHz){
        double[] result=new double[COUNT];
        if(fft==null||fft.length<8||sampleRateMilliHz<=0)return result;
        double hz=sampleRateMilliHz/1000d,top=Math.min(14000d,hz/2),bottom=Math.min(60d,top/2);
        int bins=fft.length/2;
        for(int band=0;band<COUNT;band++){
            double lo=bottom*Math.pow(top/bottom,band/(double)COUNT);
            double hi=bottom*Math.pow(top/bottom,(band+1d)/COUNT);
            int first=Math.max(1,Math.min(bins-1,(int)Math.floor(lo*fft.length/hz)));
            int last=Math.max(first+1,Math.min(bins,(int)Math.ceil(hi*fft.length/hz)));
            double power=0;
            for(int k=first;k<last;k++){
                double re=fft[k*2],im=fft[k*2+1];
                power=Math.max(power,re*re+im*im);
            }
            if(power>0){
                double db=10*Math.log10(power/(128d*128d*2));
                result[band]=Math.max(0,Math.min(1,(db+54)/54));
            }
        }
        return result;
    }
}
