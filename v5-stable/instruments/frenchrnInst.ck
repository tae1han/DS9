@import "smuck"

public class frenchrnInst extends ezInstrument {
    32 => int n_voices;

    Gain dry => outlet;
    Gain wet;
    DelayL delay => Gain fb => delay;
    fb => wet => outlet;

    FrencHrn horns[n_voices] => ADSR env[n_voices];

    numVoices(n_voices);

    fun frenchrnInst()
    {
        for(int i; i < n_voices; i++) {
            env[i] => dry;
            env[i] => delay;
            env[i].set(500::ms, 2500::ms, 0.1, 300::ms);
            0.0 => horns[i].controlOne;
            1.0 => horns[i].controlTwo;
            horns[i].gain(0.2);
        }
        delayTime(0.8);
        feedback(0.7);
        wetGain(0.6);
    }

    fun float delayTime(float s)
    {
        (s + 0.1)::second => delay.max;
        s::second => delay.delay;
        return s;
    }

    fun float feedback(float g) { g => fb.gain; return g; }
    fun float wetGain(float g)  { g => wet.gain; return g; }

    fun void noteOn(ezNote note, int voice) {
        Std.mtof(note.pitch()) => horns[voice].freq;
        Std.clampf(note.velocity(), 0.0, 1.0) => horns[voice].noteOn;
        env[voice].keyOn();
    }

    fun void noteOff(ezNote note, int voice) {
        horns[voice].noteOff(1);
        env[voice].keyOff();
    }
}
