@import "smuck"
@import "../lib/agent.ck"
@import "../lib/SMIR.ck"

// Parakeet: harmonize incoming notes in real-time

public class Parakeet extends Agent
{
    0.25 => float activationProb;
    1.0 => float windowDurMin;
    5.0 => float windowDurMax;
    3.0 => float silenceMin;
    8.0 => float silenceMax;
    0.95 => float harmonyVelScale;
    1.0 => float harmonyBeats;
    1 => int rtMode; // 0 mirror, 1 harmonize
    0.15 => float minInputVel; // kept for API compatibility (legacy knob)

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
    int _upstreamPc[12];
    0 => int _upstreamAny;

    fun void _clearUpstreamMask()
    {
        for(0 => int i; i < 12; i++) 0 => _upstreamPc[i];
        0 => _upstreamAny;
    }

    fun void _trackUpstreamPitch(int pitch)
    {
        if(pitch < 0 || pitch > 127) return;
        ((pitch % 12) + 12) % 12 => int pc;
        if(!_upstreamPc[pc])
        {
            1 => _upstreamPc[pc];
            1 => _upstreamAny;
        }
    }

    fun void setListenTarget(int tgt)
    {
        if(tgt != listenTarget) _clearUpstreamMask();
        if(tgt == mySlot && mySlot >= 0) return;
        tgt => listenTarget;
    }

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

    // Same pitch-class set as Parrot/Owl: rolling + completed + live human phrase.
    fun int _humanPitchMask(int mask[])
    {
        for(0 => int i; i < 12; i++) 0 => mask[i];
        if(source == null) return 0;

        0 => int any;

        source.rollingBuffer.notes() @=> ezNote rollNotes[];
        for(0 => int i; i < rollNotes.size(); i++)
        {
            rollNotes[i].pitch() $ int => int p;
            if(p < 0 || p > 127) continue;
            if(SMIR.skipForPitchSet(p)) continue;
            ((p % 12) + 12) % 12 => int pc;
            if(!mask[pc]) { 1 => mask[pc]; 1 => any; }
        }

        source.completedPhrase.notes() @=> ezNote doneNotes[];
        for(0 => int i; i < doneNotes.size(); i++)
        {
            doneNotes[i].pitch() $ int => int p;
            if(p < 0 || p > 127) continue;
            if(SMIR.skipForPitchSet(p)) continue;
            ((p % 12) + 12) % 12 => int pc;
            if(!mask[pc]) { 1 => mask[pc]; 1 => any; }
        }

        if(source.inPhrase())
        {
            source.phraseBuffer.notes() @=> ezNote liveNotes[];
            for(0 => int i; i < liveNotes.size(); i++)
            {
                liveNotes[i].pitch() $ int => int p;
                if(p < 0 || p > 127) continue;
                if(SMIR.skipForPitchSet(p)) continue;
                ((p % 12) + 12) % 12 => int pc;
                if(!mask[pc]) { 1 => mask[pc]; 1 => any; }
            }
        }
        return any;
    }

    // Agent listen: pitch classes from upstream notes only. Human listen: human buffers.
    fun int _activePitchMask(int mask[])
    {
        for(0 => int i; i < 12; i++) 0 => mask[i];
        if(listenTarget >= 0)
        {
            0 => int any;
            for(0 => int i; i < 12; i++)
            {
                if(_upstreamPc[i]) { 1 => mask[i]; 1 => any; }
            }
            return any;
        }
        return _humanPitchMask(mask);
    }

    fun int _quantizeToMask(int pitch, int mask[], int haveMask)
    {
        if(!haveMask) return pitch;
        source.rollingSmir.quantizeToMask(pitch, mask) => int q;
        return q;
    }

    fun void _mirrorNote(ezNote incoming, int hopDepth, int mask[], int haveMask)
    {
        incoming.pitch() $ int => int p;
        _quantizeToMask(p, mask, haveMask) => int q;
        ezNote n(0.0, Math.max(0.25, incoming.beats()), q, incoming.velocity());
        playDirect(n);
        _emitAgentNote(n, hopDepth);
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
        if(param == "probability")
        {
            if(val < 0.0) 0.0 => val;
            if(val > 1.0) 1.0 => val;
            val => activationProb;
        }
        else if(param == "windowDurMin") val => windowDurMin;
        else if(param == "windowDurMax") val => windowDurMax;
        else if(param == "silenceMin") val => silenceMin;
        else if(param == "silenceMax") val => silenceMax;
        else if(param == "harmonyDirection") val $ int => harmonyDirection;
        else if(param == "intervalMin") val $ int => intervalMin;
        else if(param == "intervalMax") val $ int => intervalMax;
        else if(param == "polyphony") val $ int => polyphony;
        else if(param == "harmonyVelScale") val => harmonyVelScale;
        else if(param == "minInputVel") val => minInputVel;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "rtMode") val $ int => rtMode;
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
        else if(param == "phraseOnlyEddies") val $ int => _phraseOnlyEddies;
        else if(param == "clearPitchSet") _clearUpstreamMask();
        else if(param == "maxHopDepth") val $ int => _maxHopDepth;
        else if(param == "eddiesEnabled") val $ int => _eddiesEnabled;
        else if(param == "verbose") val $ int => verbose;
    }

    fun void enable()
    {
        0 => _windowOpen;
        now => _nextTryTime;
        _clearUpstreamMask();
        if(!enabled) 1 => enabled;
        0 => _instConnected;
        _connectInst();
        spork ~ _liveKick(0::ms);
        spork ~ _liveKick(250::ms);
        spork ~ _liveKick(600::ms);
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

    fun void onAgentNote(int srcSlot, int pitch, float vel, float durBeats, int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        _trackUpstreamPitch(pitch);
        ezNote n(0.0, durBeats, pitch, vel);
        _handleRt(n, hopDepth + 1);
    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        if(phrase == null || phrase.size() == 0) return;
        // Seed pitch pool only — playback comes from timed onAgentNote (owl bus stream).
        // Replaying the phrase here fires every note at onset 0 (buffer dump artifact).
        _clearUpstreamMask();
        for(int i; i < phrase.size(); i++)
            _trackUpstreamPitch(phrase[i].pitch() $ int);
    }

    fun void onNote(ezNote incoming)
    {
        if(incoming == null) return;
        if(listenTarget != LISTEN_HUMAN) return;
        _handleRt(incoming, 0);
    }

    fun void _handleRt(ezNote incoming, int hopDepth)
    {
        if(incoming.velocity() < minInputVel) return;
        if(_phraseOnlyEddies && hopDepth > 0) return;

        if(listenTarget >= 0)
            _trackUpstreamPitch(incoming.pitch() $ int);

        int mask[12];
        _activePitchMask(mask) => int haveMask;

        if(rtMode == 0)
        {
            _mirrorNote(incoming, hopDepth, mask, haveMask);
            return;
        }

        // No pitch set from upstream yet — mirror instead of off-scale harmonize.
        if(!haveMask)
        {
            _mirrorNote(incoming, hopDepth, mask, haveMask);
            return;
        }

        // Window expired
        if(_windowOpen && now >= _activeUntil)
        {
            0 => _windowOpen;
            if(activationProb >= 0.999) now => _nextTryTime;
            else now + Math.random2f(silenceMin, silenceMax)::second => _nextTryTime;
            _log("window closed");
            _idle();
        }

        if(!_windowOpen && now < _nextTryTime) return;

        if(!_windowOpen)
        {
            if(activationProb < 0.999 && Math.randomf() > activationProb) return;
            _openHarmonyVoicesModern();
            if(_voiceCount < 1) return;

            now + Math.random2f(windowDurMin, windowDurMax)::second => _activeUntil;
            1 => _windowOpen;
            _playing(_windowDesc);
        }

        incoming.pitch() $ int => int p;
        _quantizeToMask(p, mask, haveMask) => p;

        incoming.velocity() * harmonyVelScale => float v;
        if(v > 1.15) 1.15 => v;

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
        if(nPlayed == 0)
        {
            _mirrorNote(incoming, hopDepth, mask, haveMask);
            return;
        }

        if(_voiceCount <= 1) _playing(playPhrase(_voiceSemi[0]));
        else _playing(playPhrase(_voiceSemi[0], _voiceSemi[1]));

        for(int k; k < nPlayed; k++)
        {
            ezNote h(0.0, harmonyBeats, qPitches[k], v);
            playDirect(h);
            _emitAgentNote(h, hopDepth);
        }
    }
}
