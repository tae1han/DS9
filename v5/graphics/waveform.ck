public class Waveform extends GGen
{
    1024 => int WINDOW_SIZE;
    .5 => float x_width;

    GLines lines --> this;
    lines.width(.01);

    Gain inlet => Flip accum => blackhole;
    WINDOW_SIZE => accum.size;
    Windowing.hann(WINDOW_SIZE) @=> float window[];

    float samples[0];

    fun void map2waveform(float in[], vec2 out[])
    {
        if( in.size() != out.size() )
        {
            <<< "size mismatch in map2waveform()", "" >>>;
            return;
        }

        DISPLAY_WIDTH => float width;
        for(int i; i < in.size(); i++)
        {
            // space evenly in X
            -width/2 + width/WINDOW_SIZE*i => out[i].x;
            // map y, using window function to taper the ends
            in[i] * 2 * window[i] => out[i].y;
        }
    }

    fun void doAudio()
    {
        while(true)
        {
            accum.upchuck();
            accum.output(samples);
            WINDOW_SIZE::samp/2 => now;
        }
    }
    spork ~ doAudio();

    fun void doGraphics()
    {
        while(true)
        {
            GG.nextFrame() => now;
            map2waveform(samples, positions);
            lines.positions(positions);
        }
    }
    spork ~ doGraphics();
}