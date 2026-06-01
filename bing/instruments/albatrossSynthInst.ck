@import "smuck"

// Sustained synth with ascending portamento for Albatross.
public class albatrossSynthInst extends ezInstrument
{
    4 => int n_voices;
    Blit osc[n_voices] => LPF lpf[n_voices] => ADSR env[n_voices] => outlet;
    int _voicePitch[4];
    int _active[4];
    0 => int _abortGen;

    fun albatrossSynthInst()
    {
        numVoices(n_voices);
        for(int i; i < n_voices; i++)
        {
            -1 => _voicePitch[i];
            0 => _active[i];
            osc[i].gain(1.0);
            osc[i].harmonics(4);
            lpf[i].freq(3200);
            env[i].set(800::ms, 3600::ms, 0.1, 150::ms);
        }
    }

    fun void _silence(int v)
    {
        0 => _active[v];
        -1 => _voicePitch[v];
        env[v].keyOff(1);
    }

    fun void allOff()
    {
        _abortGen++;
        for(int i; i < n_voices; i++)
            if(_active[i]) _silence(i);
    }

    fun int aborted(int startGen)
    {
        return (_abortGen != startGen);
    }

    fun void noteOn(ezNote note, int voice)
    {
        note.pitch() $ int => int p;
        p => _voicePitch[voice];
        1 => _active[voice];
        Std.mtof(p) => osc[voice].freq;
        note.velocity() * 0.35 => env[voice].gain;
        env[voice].keyOn(1);
    }

    fun void noteOff(ezNote note, int voice) { _silence(voice); }

    // Glide up to target, hold, then release.
    fun void glideAscend(int fromPitch, int toPitch, float glideSec, float holdSec, float vel)
    {
        if(fromPitch > toPitch) fromPitch => toPitch;
        if(glideSec > 0.5) 0.5 => glideSec;
        if(holdSec > 4.0) 4.0 => holdSec;
        ezNote n(0, holdSec, toPitch, vel);
        allocate_voice(n) => int v;
        if(v < 0) return;
        _abortGen => int g0;
        Std.mtof(fromPitch) => osc[v].freq;
        vel * 0.35 => env[v].gain;
        env[v].keyOn(1);
        Math.max(1, (glideSec * 1000) $ int) => int steps;
        (Std.mtof(toPitch) - Std.mtof(fromPitch)) / (steps $ float) => float step;
        for(int i; i < steps; i++)
        {
            if(aborted(g0)) { _silence(v); release_voice(v); return; }
            osc[v].freq() + step => float f;
            f => osc[v].freq;
            (glideSec / (steps $ float))::second => now;
        }
        if(aborted(g0)) { _silence(v); release_voice(v); return; }
        Std.mtof(toPitch) => osc[v].freq;
        holdSec::second => now;
        if(aborted(g0)) { _silence(v); release_voice(v); return; }
        _silence(v);
        release_voice(v);
    }

    fun void trillHold(int pitchA, int pitchB, float holdSec, float vel, float rateHz)
    {
        if(holdSec > 4.0) 4.0 => holdSec;
        ezNote n(0, 0.25, pitchA, vel);
        allocate_voice(n) => int v;
        if(v < 0) return;
        vel * 0.35 => env[v].gain;
        0 => int which;
        0 => float elapsed;
        Math.max(4.0, rateHz) => float hz;
        (1.0 / hz)::second => dur step;
        _abortGen => int g0;
        env[v].keyOn(1);
        while(elapsed < holdSec)
        {
            if(aborted(g0)) { _silence(v); release_voice(v); return; }
            if(which == 0) Std.mtof(pitchA) => osc[v].freq;
            else Std.mtof(pitchB) => osc[v].freq;
            1 - which => which;
            step => now;
            elapsed + step / second => elapsed;
        }
        _silence(v);
        release_voice(v);
    }

    // Trill with linearly-ramped rate (hzStart -> hzEnd) over holdSec.
    fun void trillHoldRamp(int pitchA, int pitchB, float holdSec, float vel, float hzStart, float hzEnd)
    {
        if(holdSec > 4.0) 4.0 => holdSec;
        ezNote n(0, 0.25, pitchA, vel);
        allocate_voice(n) => int v;
        if(v < 0) return;
        vel * 0.35 => env[v].gain;
        _abortGen => int g0;
        env[v].keyOn(1);

        0 => int which;
        0.0 => float elapsed;
        Math.max(3.5, hzStart) => hzStart;
        Math.max(3.5, hzEnd) => hzEnd;

        while(elapsed < holdSec)
        {
            if(aborted(g0)) { _silence(v); release_voice(v); return; }
            if(which == 0) Std.mtof(pitchA) => osc[v].freq;
            else Std.mtof(pitchB) => osc[v].freq;
            1 - which => which;

            (elapsed / holdSec) => float t;
            (hzStart + (hzEnd - hzStart) * t) => float hz;
            (1.0 / hz)::second => dur step;
            step => now;
            elapsed + step / second => elapsed;
        }

        _silence(v);
        release_voice(v);
    }
}
