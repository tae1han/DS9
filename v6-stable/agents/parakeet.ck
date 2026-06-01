@import "smuck"
@import "../agent.ck"

// Parakeet: harmonize incoming notes in real-time

public class Parakeet extends Agent
{
    0.25 => float activationProb;
    1.0 => float windowDurMin;
    5.0 => float windowDurMax;
    3.0 => float silenceMin;
    8.0 => float silenceMax;
    0.8 => float harmonyVelScale;
    1.0 => float harmonyBeats;
    0.15 => float minInputVel;

    0.2 => float doubleVoiceProb; // kept for API compatibility (legacy knob)

    // Harmony model (+1 above melody, -1 below)
    1 => int harmonyDirection;
    100 => int intervalMin;
    0 => int intervalMax;
    1 => int polyphony;   // ceiling 1–4; each harmony window picks 1/2/3 voices at ~60%/35%/5%, then clamps to polyphony / span.

    0 => int _windowOpen;
    time _activeUntil;
    time _nextTryTime;

    int _voiceSemi[4];
    0 => int _voiceCount;
    "" => string _windowDesc;

    int _qOffs[0];

    fun Parakeet()
    {
        "Parakeet" => name;
        0 => cancelOnNewPhrase;
        // Modern defaults matching prior musical character.
        3 => intervalMin;
        9 => intervalMax;
        2 => polyphony;
        0.0 => responseDelayMin;
        0.0 => responseDelayMax;

        _qOffs << 0;
        for(1 => int d; d <= 11; d++)
        {
            _qOffs << d;
            _qOffs << -d;
        }
        _qOffs << 12;
        _qOffs << -12;
        _qOffs << 24;
        _qOffs << -24;
        _qOffs << 13;
        _qOffs << -13;
    }

    fun void setIntervals(int xs[])
    {
        // Compatibility shim: legacy callers can still pass interval lists.
        if(xs.size() == 0) return;

        127 => int lo;
        0 => int hi;
        for(int i; i < xs.size(); i++)
        {
            xs[i] => int v;
            if(v < 0) -v => v;
            if(v < 1) continue;
            if(v > 24) 24 => v;
            if(v < lo) v => lo;
            if(v > hi) v => hi;
        }
        if(lo > hi) return;

        lo => intervalMin;
        hi => intervalMax;
        Math.min(4, Math.max(1, xs.size())) => polyphony;
    }

    fun void __clampIntervals()
    {
        if(intervalMin < 1) 1 => intervalMin;
        if(intervalMax > 24) 24 => intervalMax;
        if(intervalMin > intervalMax)
        {
            intervalMax => int t;
            intervalMin => intervalMax;
            t => intervalMin;
        }
    }

    // Try quantized pitches near raw until unused (mask-aware); avoids doubled harmony notes.
    fun int _quantizeUniquePitch(int raw, int mask[], int used[])
    {
        for(int i; i < _qOffs.size(); i++)
        {
            raw + _qOffs[i] => int r;
            if(r < 0 || r > 127) continue;
            source.rollingSmir.quantizeToMask(r, mask) => int q;
            if(q >= 0 && q <= 127 && used[q] == 0)
                return q;
        }
        return -1;
    }

    fun void _openHarmonyVoicesModern()
    {
        __clampIntervals();
        if(harmonyDirection >= 0) 1 => harmonyDirection;
        else -1 => harmonyDirection;

        Math.max(1, intervalMax - intervalMin + 1) => int spanMax;
        Math.min(4, Math.max(1, polyphony)) => int cap;

        Math.randomf() => float pr;
        1 => int want;
        if(pr < 0.60) 1 => want;
        else if(pr < 0.95) 2 => want;
        else 3 => want;
        Math.min(want, Math.min(cap, spanMax)) => want;

        if(want == 1)
            (intervalMin + intervalMax) / 2 => _voiceSemi[0];
        else for(int vi; vi < want; vi++)
            intervalMin + (intervalMax - intervalMin) * vi / (want - 1) => _voiceSemi[vi];

        want => _voiceCount;

        "" => string w;
        w + _voiceCount + "v " => w;
        if(harmonyDirection > 0) w + "+" => w;
        else w + "-" => w;
        for(int j; j < _voiceCount; j++)
        {
            if(j > 0) w + "," => w;
            w + "" + _voiceSemi[j] => w;
        }
        w => _windowDesc;
    }

    fun void setParam(string param, float val)
    {
        if(param == "probability") val => activationProb;
        else if(param == "windowDurMin") val => windowDurMin;
        else if(param == "windowDurMax") val => windowDurMax;
        else if(param == "silenceMin") val => silenceMin;
        else if(param == "silenceMax") val => silenceMax;
        else if(param == "doubleVoiceProb") val => doubleVoiceProb;
        else if(param == "harmonyDirection") val $ int => harmonyDirection;
        else if(param == "intervalMin") val $ int => intervalMin;
        else if(param == "intervalMax") val $ int => intervalMax;
        else if(param == "polyphony") val $ int => polyphony;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        return 1;
    }

    fun string playPhrase(int interval)
    {
        string options[0];
        options << "harmonizing +" + interval + " semitones";
        options << "me too!";
        options << "trying to fit the harmony with +" + interval + " semitones";
        options << "I'm playing harmony on top!";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string playPhrase(int interval1, int interval2)
    {
        string options[0];
        options << "harmonizing +" + interval1 + " & +" + interval2 + " semitones";
        options << "I'm trying two harmony parts!";
        options << "trying to fit the harmony with +" + interval1 + " & +" + interval2 + " semitones";
        options << "I'm playing TWO harmonies on top!";
        options << "the more the merrier";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun void onNote(ezNote incoming)
    {
        if(incoming == null) return;
        if(incoming.velocity() < minInputVel) return;

        // Window expired
        if(_windowOpen && now >= _activeUntil)
        {
            0 => _windowOpen;
            now + Math.random2f(silenceMin, silenceMax)::second => _nextTryTime;
            _log("window closed");
            _idle();
            return;
        }

        if(!_windowOpen && now < _nextTryTime) return;

        if(!_windowOpen)
        {
            if(Math.randomf() > activationProb) return;
            _openHarmonyVoicesModern();
            if(_voiceCount < 1) return;

            now + Math.random2f(windowDurMin, windowDurMax)::second => _activeUntil;
            1 => _windowOpen;
            _playing(_windowDesc);
        }

        incoming.pitch() $ int => int p;

        source.rollingSmir.pitchNormSet() @=> float w[];
        int mask[12];
        for(int mi; mi < 12; mi++)
        {
            if(w[mi] > 0) 1 => mask[mi];
        }

        incoming.velocity() * harmonyVelScale => float v;
        if(v > 1.0) 1.0 => v;

        int used[128];
        for(int ui; ui < 128; ui++) 0 => used[ui];
        1 => used[p];

        int qPitches[4];
        int raw;
        0 => int nPlayed;
        for(int vi; vi < _voiceCount; vi++)
        {
            p + harmonyDirection * _voiceSemi[vi] => raw;
            if(raw < 0 || raw > 127) continue;
            _quantizeUniquePitch(raw, mask, used) => int q;
            if(q < 0) continue;
            1 => used[q];
            q => qPitches[nPlayed];
            nPlayed++;
        }
        if(nPlayed == 0) return;

        if(_voiceCount <= 1) _playing(playPhrase(_voiceSemi[0]));
        else _playing(playPhrase(_voiceSemi[0], _voiceSemi[1]));

        ezNote harmonies[4];
        for(int k; k < nPlayed; k++)
        {
            ezNote h(0.0, harmonyBeats, qPitches[k], v);
            h @=> harmonies[k];
            inst.noteOn(harmonies[k], k);
        }

        harmonyBeats::second => now;

        for(int k; k < nPlayed; k++)
            inst.noteOff(harmonies[k], k);
        _idle();
    }
}
