@import "smuck"

public class arpInst extends ezInstrument {
    16 => int n_voices;

    BlitSaw osc[n_voices] => ADSR env[n_voices] => Gain bus => LPF lpf => Echo a => Echo b => Echo c => outlet;
    for(int i; i < n_voices; i++) {
        osc[i].gain(0.35);
        osc[i].harmonics(5);
        env[i].set(30::ms, 300::ms, 0.0, 1::ms);
    }
    lpf.freq(2000);
    1000::ms => a.max => b.max => c.max;
    900::ms => a.delay => b.delay => c.delay;
    .05 => a.mix;
    .03 => b.mix;
    .015 => c.mix;

    numVoices(n_voices);

    fun void noteOn(ezNote note, int voice) {
        Std.mtof(note.pitch()) => osc[voice].freq;
        Std.clampf(note.velocity(), 0.0, 1.0) => osc[voice].gain;
        env[voice].keyOn();
    }

    fun void noteOff(ezNote note, int voice) {
        env[voice].keyOff();
    }
}