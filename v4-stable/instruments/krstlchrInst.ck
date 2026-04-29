@import "smuck"

public class krstlchrInst extends ezInstrument {
    16 => int n_voices;

    KrstlChr choir[n_voices] => ADSR env[n_voices] => Gain bus => LPF lpf => outlet;
    for(int i; i < n_voices; i++) {
        choir[i].gain(0.35);
        env[i].set(800::ms, 5000::ms, 0, 50::ms);
    }
    lpf.freq(5000);

    numVoices(n_voices);

    // fun float lfoSpeed(float val)
    // {
    //     for(int i; i < n_voices; i++) val => choir[i].lfoSpeed;
    //     return val;
    // }

    // fun float gain(float val)
    // {
    //     for(int i; i < n_voices; i++) val => choir[i].gain;
    //     return val;
    // }

    fun void noteOn(ezNote note, int voice) {
        Std.mtof(note.pitch()) => choir[voice].freq;
        Std.clampf(note.velocity(), 0.0, 1.0) => choir[voice].noteOn;
        env[voice].keyOn();
    }

    fun void noteOff(ezNote note, int voice) {
        choir[voice].noteOff(1);
        env[voice].keyOff();
        env[voice].releaseTime() => now;
    }
}
