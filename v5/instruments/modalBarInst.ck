@import "smuck"

public class modalBarInst extends ezInstrument {
    32 => int n_voices;

    ModalBar modalBar[n_voices] => Echo a => Echo b => Echo c => outlet;
    1000::ms => a.max => b.max => c.max;
    750::ms => a.delay => b.delay => c.delay;
    .075 => a.mix => b.mix => c.mix;

    numVoices(n_voices);

    fun modalBarInst(int p)
    {
        preset(p);
        strikePosition(0.5);
        stickHardness(0.5);
    }

    fun int preset(int p)
    {
        for(int i; i < n_voices; i++) {
            p => modalBar[i].preset;
        }
        return p;
    }

    fun float strikePosition(float val)
    {
        for(int i; i < n_voices; i++) {
            val => modalBar[i].strikePosition;
        }
        return val;
    }

    fun float echoMix(float val)
    {
        val => a.mix => b.mix => c.mix;
        return val;
    }

    fun float stickHardness(float val)
    {
        for(int i; i < n_voices; i++) {
            val => modalBar[i].stickHardness;
        }
        return val;
    }

    fun void noteOn(ezNote note, int voice) {
        Std.mtof(note.pitch()) => modalBar[voice].freq;
        Std.clampf(note.velocity(), 0.0, 1.0) => modalBar[voice].strike;
    }

    fun void noteOff(ezNote note, int voice) { modalBar[voice].noteOff(1); }
}
