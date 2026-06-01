@import "smuck"

public class synthBassInst extends ezInstrument {
    16 => int n_voices;

    3 => int octave;
    .05 => float pulseWidthMin;
    .5 => float modDepth;

    PulseOsc osc[n_voices] => ADSR env[n_voices] => Gain bus => LPF lpf => HPF hpf => outlet;
    for(int i; i < n_voices; i++) {
        osc[i].gain(0.5);
        osc[i].width(.05);
        env[i].set(50::ms, 4000::ms, 0.0, 100::ms);
    }
    lpf.freq(180);
    hpf.freq(20);


    numVoices(n_voices);

    fun void noteOn(ezNote note, int voice) {
        note.pitch() % 12 + 12 * octave => float pitch;
        Std.mtof(pitch) => osc[voice].freq;
        Std.clampf(note.velocity(), 0.0, 1.0) => osc[voice].gain;
        env[voice].keyOn();
    }

    fun void noteOff(ezNote note, int voice) {
        env[voice].keyOff();
    }

}