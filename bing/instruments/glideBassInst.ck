@import "smuck"

// Downward glide bass for Emu glide mode.
public class glideBassInst extends ezInstrument
{
    2 => int n_voices;
    0 => int _abortGen;
    BlitSaw osc[n_voices] => LPF lpf[n_voices] => ADSR env[n_voices] => outlet;

    fun glideBassInst()
    {
        numVoices(n_voices);
        for(int i; i < n_voices; i++)
        {
            osc[i].gain(0.65);
            osc[i].harmonics(4);
            lpf[i].freq(800);
            env[i].set(800::ms, 3500::ms, 0.1, 500::ms);
        }
    }

    fun void noteOn(ezNote note, int voice)
    {
        Std.mtof(note.pitch() $ int) => osc[voice].freq;
        note.velocity() * 0.75 => env[voice].gain;
        env[voice].keyOn(1);
    }

    fun void noteOff(ezNote note, int voice) { env[voice].keyOff(1); }

    fun void allOff()
    {
        _abortGen++;
        for(int i; i < n_voices; i++)
        {
            env[i].keyOff(1);
            release_voice(i);
        }
    }

    fun int aborted(int startGen)
    {
        return (_abortGen != startGen);
    }

    fun void glideDescend(int fromPitch, int toPitch, float glideSec, float holdSec, float vel)
    {
        if(fromPitch < toPitch) fromPitch => toPitch;
        if(glideSec < 0.05) 0.05 => glideSec;
        if(glideSec > 2.5) 2.5 => glideSec;
        if(holdSec > 6.0) 6.0 => holdSec;
        ezNote n(0, holdSec, toPitch, vel);
        allocate_voice(n) => int v;
        if(v < 0) return;
        _abortGen => int g0;
        Std.mtof(fromPitch) => osc[v].freq;
        vel * 0.75 => env[v].gain;
        env[v].keyOn(1);
        Math.max(1, (glideSec * 1000) $ int) => int steps;
        (Std.mtof(toPitch) - Std.mtof(fromPitch)) / (steps $ float) => float step;
        for(int i; i < steps; i++)
        {
            if(aborted(g0)) { env[v].keyOff(1); release_voice(v); return; }
            osc[v].freq() + step => float f;
            f => osc[v].freq;
            (glideSec / (steps $ float))::second => now;
        }
        if(aborted(g0)) { env[v].keyOff(1); release_voice(v); return; }
        holdSec::second => now;
        if(aborted(g0)) { env[v].keyOff(1); release_voice(v); return; }
        env[v].keyOff(1);
        release_voice(v);
    }
}
