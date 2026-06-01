@import "smuck"
@import "../agent.ck"

public class Swan extends Agent
{
    3 => int minOrdered;
    36 => int pitchLow;
    96 => int pitchHigh;
    0.72 => float rootVel;
    0.58 => float harmonyVel;
    0 => int repeatExtraMin; // extra repeats → 1–3 total passes
    3 => int repeatExtraMax;
    0.5 => float repeatSpeed;
    0.25 => float repeatGapBeats;
    0.3 => float timingScale;
    0.5 => float activationProb;
    Event _playRequest;
    int _pendingHop;
    int _playTicket;
    int _agentOrdered[0];

    fun void setListenTarget(int tgt)
    {
        if(tgt != listenTarget)
        {
            int empty[0];
            empty @=> _agentOrdered;
        }
        if(tgt == mySlot && mySlot >= 0) return;
        tgt => listenTarget;
    }
    fun Swan()
    {
        "Swan" => name;
        0 => cancelOnNewPhrase;
        0.0 => responseDelayMin;
        0.0 => responseDelayMax;
        60.0 => localBpm;
        spork ~ playbackWorker();
    }

    fun void setParam(string param, float val)
    {
        if(param == "minOrdered") val $ int => minOrdered;
        else if(param == "pitchLow") val $ int => pitchLow;
        else if(param == "pitchHigh") val $ int => pitchHigh;
        else if(param == "rootVel") val => rootVel;
        else if(param == "harmonyVel") val => harmonyVel;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "verbose") val $ int => verbose;
        else if(param == "repeatExtraMin") val $ int => repeatExtraMin;
        else if(param == "repeatExtraMax") val $ int => repeatExtraMax;
        else if(param == "repeatSpeed") val => repeatSpeed;
        else if(param == "timingScale") val => timingScale;
        else if(param == "probability") val => activationProb;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
    }

    fun void stopAll()
    {
        _playTicket++;
        _releaseAllInstrumentVoices();
        if(player.isPlaying()) player.stop();
    }

    fun int _passesProbability()
    {
        if(activationProb >= 0.999) return 1;
        if(Math.randomf() <= activationProb) return 1;
        _log("skipped (probability)");
        _idle();
        return 0;
    }

    fun void _phraseWithRepeats(ezNote phrase[], ezNote out[])
    {
        if(phrase.size() == 0) return;

        Math.random2(repeatExtraMin, repeatExtraMax) => int extra;
        extra + 1 => int passes;

        0.0 => float sectionStart;
        1.0 => float speed;
        for(0 => int pass; pass < passes; pass++)
        {
            if(pass > 0) speed * repeatSpeed => speed;

            0.0 => float passEnd;
            for(0 => int i; i < phrase.size(); i++)
            {
                phrase[i].onset() * speed + sectionStart => float on;
                phrase[i].beats() * speed => float b;
                if(b < 0.08) 0.08 => b;
                phrase[i].pitch() $ int => int pitch;
                phrase[i].velocity() => float vel;
                ezNote n(on, b, pitch, vel);
                out << n;
                on + b => float end;
                if(end > passEnd) end => passEnd;
            }
            passEnd + repeatGapBeats * timingScale => sectionStart;
        }

        _log("Swan " + passes + " passes (speed " + repeatSpeed + "/repeat)");
    }

    fun int[] _orderedFromNotes(ezNote notes[])
    {
        int present[128];
        for(0 => int p; p < 128; p++) 0 => present[p];
        if(notes == null) return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].pitch() $ int => int p;
            if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
        }
        return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
    }

    fun int[] _orderedPitches()
    {
        if(listenTarget >= 0 && _agentOrdered.size() >= minOrdered)
            return _agentOrdered;

        int present[128];
        for(0 => int p; p < 128; p++) 0 => present[p];

        if(source != null)
        {
            source.completedPhrase.notes() @=> ezNote done[];
            for(0 => int i; i < done.size(); i++)
            {
                done[i].pitch() $ int => int p;
                if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
            }
            if(listenTarget < 0)
            {
                source.rollingBuffer.notes() @=> ezNote roll[];
                for(0 => int i; i < roll.size(); i++)
                {
                    roll[i].pitch() $ int => int p;
                    if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
                }
            }
        }

        return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        return 1;
    }

    fun void onPhraseComplete()
    {
        if(!enabled) return;
        if(listenTarget != LISTEN_HUMAN) return;
        if(!_passesProbability()) return;
        _activate(0);
    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        if(!_passesProbability()) return;
        _orderedFromNotes(phrase) @=> _agentOrdered;
        _activate(hopDepth + 1);
    }

    fun void _activate(int hopDepth)
    {
        _orderedPitches() @=> int ordered[];
        if(ordered.size() < minOrdered)
        {
            _log("skip: only " + ordered.size() + " pitches (need " + minOrdered + ")");
            return;
        }

        Math.random2(0, 1) * 2 - 1 => int dir;
        Math.random2(3, 6) => int melLen;
        Math.random2(1, 2) => int stepK;

        int mel[0];
        Math.random2(0, ordered.size() - 1) => int idx;
        ordered[idx] => int cur;
        mel << cur;
        for(1 => int i; i < melLen; i++)
        {
            SMIR.nextOrderedIndex(idx, stepK, dir, ordered.size()) => idx;
            ordered[idx] => int p;
            if(dir > 0 && p <= cur) p + 12 => p;
            if(dir < 0 && p >= cur) p - 12 => p;
            p => cur;
            mel << p;
        }

        ezNote phrase[0];
        0.0 => float t;
        for(int i; i < mel.size(); i++)
        {
            Math.random2f(250, 1000) => float baseMs;
            if(Math.randomf() < 0.25) baseMs * 2.0 => baseMs;
            baseMs + Math.random2f(-75, 75) => float durMs;
            Math.max(100, durMs) * timingScale => durMs;
            durMs / 1000.0 => float beats;
            mel[i] => int root;
            Math.random2(1, 2) => int nv;
            ezNote chord[0];
            ezNote rootN(t / 1000.0, beats, root, rootVel);
            chord << rootN;
            for(int v; v < nv; v++)
            {
                Math.random2(3, 7) * (Math.random2(0,1)*2-1) => int semi;
                SMIR.quantizeToOrderedMidi(root + semi, ordered) => int hp;
                if(hp != root)
                {
                    ezNote h(t / 1000.0, beats, hp, harmonyVel);
                    chord << h;
                }
            }
            for(int c; c < chord.size(); c++)
                phrase << chord[c];
            t + durMs => t;
        }

        if(phrase.size() == 0) return;

        ezNote playNotes[0];
        _phraseWithRepeats(phrase, playNotes);
        if(playNotes.size() == 0) return;

        _thinking("Swan phrase");
        ezMeasure m(playNotes); ezPart p; p.add(m);
        ezPart parts[1]; p @=> parts[0];
        ezScore s(parts); s.bpm(localBpm); s @=> currentScore;
        hopDepth => _pendingHop;
        _log("play " + playNotes.size() + " notes from " + ordered.size() + " pitches");
        _playRequest.broadcast();
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(!enabled) continue;
            if(currentScore == null || inst == null) continue;

            _playTicket => int ticket;
            _playing("Swan");
            swapScore(currentScore);
            if(_playTicket != ticket || !enabled) continue;
            currentScore.parts()[0].measures()[0].notes() @=> ezNote sn[];
            _emitAgentPhrase(sn, _pendingHop);
            _scorePlayEndBeats(currentScore) * 60.0 / localBpm => float durSec;
            _waitPlayback(durSec, ticket);
            if(_playTicket != ticket || !enabled) continue;
            spork ~ _idleAfter(durSec::second);
        }
    }

    fun void _waitPlayback(float durSec, int ticket)
    {
        0.0 => float elapsed;
        while(elapsed < durSec)
        {
            if(_playTicket != ticket || !enabled) return;
            25::ms => now;
            elapsed + 0.025 => elapsed;
        }
    }
}
