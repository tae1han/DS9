@import "smuck"
@import "../lib/agent.ck"
@import "../lib/SMIR.ck"

public class Peacock extends Agent
{
    2 => int minPitchClasses;
    36 => int pitchLow;
    96 => int pitchHigh;
    0.5 => float activationProb;
    1.5 => float timingScale;
    Event _playRequest;
    int _pendingHop;
    int _playTicket;
    ezNote _pendingNotes[0];
    int _liveVoices[0];
    int _livePitches[0];
    int _prevRh[4];
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

    fun Peacock()
    {
        "Peacock" => name;
        0 => cancelOnNewPhrase;
        0.0 => responseDelayMin;
        0.0 => responseDelayMax;
        60.0 => localBpm;
        for(0 => int i; i < _prevRh.size(); i++) -1 => _prevRh[i];
        spork ~ playbackWorker();
    }

    fun void setParam(string param, float val)
    {
        if(param == "minPitchClasses") val $ int => minPitchClasses;
        else if(param == "pitchLow") val $ int => pitchLow;
        else if(param == "pitchHigh") val $ int => pitchHigh;
        else if(param == "probability") val => activationProb;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "timingScale") val => timingScale;
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
        else if(param == "verbose") val $ int => verbose;
    }

    fun int shouldActivate()
    {
        if(source == null) return 0;
        return 1;
    }

    fun float _scale()
    {
        if(timingScale < 0.05) return 0.05;
        return timingScale;
    }

    fun float _msToBeats(float msVal)
    {
        (msVal * _scale() / 1000.0) * (localBpm / 60.0) => float beats;
        return beats;
    }

    fun float _secToBeats(float secVal)
    {
        secVal * _scale() * (localBpm / 60.0) => float beats;
        return beats;
    }

    fun float _secToBeatsHold(float secVal)
    {
        secVal * (localBpm / 60.0) => float beats;
        return beats;
    }

    // LH: ramp ~100 ms → RH blend (~45–65 ms) with per-step jitter.
    fun float _stepBeatsLH(int i, int n, int startMs, int endMs)
    {
        0 => int stepMs;
        if(n <= 1)
        {
            endMs + Math.random2(-10, 10) => stepMs;
        }
        else
        {
            i $ float / (n - 1) => float t;
            startMs + (endMs - startMs) * t => float target;
            target + Math.random2(-12, 12) => float jittered;
            if(jittered < 35.0) 35.0 => jittered;
            jittered $ int => stepMs;
        }
        if(stepMs < 30) 30 => stepMs;
        return _msToBeats(stepMs $ float);
    }

    fun float _stepBeatsRH()
    {
        Math.random2(75, 145) => int stepMs;
        return _msToBeats(stepMs $ float);
    }

    // Keep computed MIDI pitch in range (legacy helper).
    fun int _fitPitch(int p, int minAbove)
    {
        while(p < pitchLow) p + 12 => p;
        while(p > pitchHigh) p - 12 => p;
        if(p < pitchLow || p > pitchHigh) return -1;
        if(minAbove >= 0)
        {
            while(p <= minAbove)
            {
                p + 12 => p;
                if(p > pitchHigh) return -1;
            }
        }
        return p;
    }

    fun int _nextOrderedAbove(int last, int ordered[])
    {
        -1 => int best;
        for(0 => int i; i < ordered.size(); i++)
        {
            ordered[i] => int p;
            if(p > last)
            {
                if(best < 0 || p < best) p => best;
            }
        }
        return best;
    }

    // Nearest pitch in ordered[]; if minAbove set, next pool pitch strictly above it.
    fun int _pickFromOrdered(int raw, int minAbove, int ordered[])
    {
        if(ordered.size() == 0) return -1;
        SMIR.quantizeToOrderedMidi(raw, ordered) => int p;
        if(minAbove < 0) return p;
        if(p > minAbove) return p;
        return _nextOrderedAbove(minAbove, ordered);
    }

    fun int _rhDistinctFromPrev(int rh[], int prevRh[])
    {
        if(prevRh[0] < 0) return 1;
        0 => int matches;
        0 => int voices;
        for(0 => int i; i < rh.size(); i++)
        {
            if(rh[i] < 0) continue;
            voices++;
            if(i < prevRh.size() && rh[i] == prevRh[i]) matches++;
        }
        if(voices == 0) return 0;
        return voices - matches;
    }

    fun void _storeRh(int rh[], int prevRh[])
    {
        for(0 => int i; i < prevRh.size(); i++)
        {
            if(i < rh.size() && rh[i] >= 0) rh[i] => prevRh[i];
            else -1 => prevRh[i];
        }
    }

    // LH cluster in lower pool; RH spread in upper pool. Stays in ordered[].
    fun int _planRoll(int ordered[], int chordIdx, int attempt, int prevRh[],
        int lh[], int rh[])
    {
        while(lh.size() > 0) lh.popBack();
        for(0 => int i; i < 4; i++) -1 => rh[i];

        ordered.size() => int n;
        if(n < minPitchClasses) return 0;

        Math.max(2, (n * 0.55) $ int) => int lowEnd;
        if(lowEnd > n) n => lowEnd;

        Math.max(1, n - (n * 0.42) $ int) => int hiStart;
        if(hiStart >= n) n - 1 => hiStart;
        if(hiStart < 0) 0 => hiStart;

        (chordIdx * 3 + attempt * 2 + Math.random2(0, lowEnd - 1)) % lowEnd => int li;
        (chordIdx * 5 + attempt * 3 + Math.random2(0, Math.max(0, n - hiStart - 1)))
            % Math.max(1, n - hiStart) + hiStart => int rhi;

        Math.random2(4, 5) => int lhCount;
        Math.min(lhCount, n) => lhCount;
        if(lhCount < 2 && n >= 2) 2 => lhCount;
        li => int idx;
        ordered[idx] => int last;
        lh << last;

        for(1 => int k; k < lhCount; k++)
        {
            Math.random2(2, 4) => int stride;
            SMIR.nextOrderedIndex(idx, stride, 1, n) => idx;
            ordered[idx] => int p;
            if(p <= last)
            {
                _nextOrderedAbove(last, ordered) => int above;
                if(above < 0) break;
                above => p;
            }
            p => last;
            lh << p;
        }

        if(lh.size() < 2) return 0;

        ordered[rhi] => int rh0;
        if(rh0 <= last)
        {
            _nextOrderedAbove(last, ordered) => int above;
            if(above < 0) return 0;
            above => rh0;
        }
        rh0 => rh[0];

        rhi => int ridx;
        1 => int rhCount;
        for(1 => int i; i < 4; i++)
        {
            Math.random2(2, 5) => int skip;
            SMIR.nextOrderedIndex(ridx, skip, 1, n) => ridx;
            ordered[ridx] => int p;
            if(p <= rh[i - 1])
            {
                _nextOrderedAbove(rh[i - 1], ordered) => int above;
                if(above < 0) break;
                above => p;
            }
            p => rh[i];
            rhCount++;
        }

        if(rhCount < 1) return 0;
        if(n >= 4 && rhCount < 2) return 0;
        if(prevRh[0] >= 0 && n >= 5)
        {
            _rhDistinctFromPrev(rh, prevRh) => int diff;
            0 => int prevVoices;
            for(0 => int i; i < prevRh.size(); i++)
                if(prevRh[i] >= 0) prevVoices++;
            if(prevVoices >= 2 && diff < 2) return 0;
            if(prevVoices >= 1 && diff < 1) return 0;
        }
        return 1;
    }

    // Always succeeds when ordered has >= 2 pitches (fallback if strict plan fails).
    fun int _planRollSimple(int ordered[], int lh[], int rh[])
    {
        while(lh.size() > 0) lh.popBack();
        for(0 => int i; i < 4; i++) -1 => rh[i];

        ordered.size() => int n;
        if(n < 2) return 0;

        Math.random2(0, n - 1) => int li;
        li => int idx;
        ordered[idx] => int last;
        lh << last;

        1 => int got;
        while(got < Math.min(3, n) && lh.size() < 4)
        {
            (idx + 1) % n => idx;
            ordered[idx] => int p;
            if(p != last)
            {
                lh << p;
                p => last;
                got++;
            }
            if(idx == li && got >= 1) break;
        }
        if(lh.size() < 2)
        {
            for(0 => int i; i < n; i++)
            {
                ordered[i] => int p;
                if(p != lh[0]) { lh << p; break; }
            }
        }
        if(lh.size() < 2) return 0;

        Math.random2(0, n - 1) => int ridx;
        ordered[ridx] => int rh0;
        if(rh0 <= last)
            _nextOrderedAbove(last, ordered) => rh0;
        if(rh0 < 0) return 0;
        rh0 => rh[0];

        1 => int rhN;
        for(0 => int tries; tries < n && rhN < Math.min(3, n); tries++)
        {
            (ridx + 1) % n => ridx;
            ordered[ridx] => int p;
            if(p <= rh[rhN - 1])
                _nextOrderedAbove(rh[rhN - 1], ordered) => p;
            if(p > rh[rhN - 1])
            {
                p => rh[rhN];
                rhN++;
            }
        }
        return 1;
    }

    fun ezNote[] _rollFromPlan(int ordered[], int chordIdx, int prevRh[], int strict)
    {
        ezNote out[0];
        int lh[0];
        int rh[4];

        if(strict)
        {
            for(0 => int attempt; attempt < 6; attempt++)
            {
                if(_planRoll(ordered, chordIdx, attempt, prevRh, lh, rh))
                {
                    _storeRh(rh, prevRh);
                    _notesFromPlan(lh, rh) @=> ezNote notes[];
                    if(notes.size() > 0) return notes;
                }
            }
        }

        if(_planRollSimple(ordered, lh, rh))
        {
            _storeRh(rh, prevRh);
            _notesFromPlan(lh, rh) @=> ezNote notes[];
            if(notes.size() > 0) return notes;
        }
        return out;
    }

    fun ezNote[] _notesFromPlan(int lh[], int rh[])
    {
        ezNote out[0];
        Math.random2f(0.35, 0.85) => float durSec;
        _secToBeatsHold(durSec) => float durBeats;
        if(durBeats < 0.12) 0.12 => durBeats;
        if(durBeats > 0.9) 0.9 => durBeats;
        Math.random2(95, 110) => int lhStartMs;
        Math.random2(45, 65) => int lhEndMs;
        0.0 => float tBeats;

        for(0 => int i; i < lh.size(); i++)
        {
            ezNote n(tBeats, durBeats, lh[i], Math.random2f(0.72, 0.88));
            out << n;
            _stepBeatsLH(i, lh.size(), lhStartMs, lhEndMs) => float stepBeats;
            tBeats + stepBeats => tBeats;
        }
        -1 => int lastRh;
        for(0 => int i; i < rh.size(); i++)
        {
            if(rh[i] < 0) continue;
            rh[i] => int p;
            if(p <= lastRh) continue;
            p => lastRh;
            ezNote n(tBeats, durBeats, p, Math.random2f(0.68, 0.85));
            out << n;
            _stepBeatsRH() => float stepBeats;
            tBeats + stepBeats => tBeats;
        }
        return out;
    }

    fun int[] _orderedFromNotes(ezNote notes[])
    {
        int present[128];
        for(0 => int p; p < 128; p++) 0 => present[p];
        if(notes == null) return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].pitch() $ int => int p;
            if(SMIR.skipForPitchSet(p)) continue;
            if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
        }
        return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
    }

    // Agent listen: upstream phrase only. Human listen: completed phrase (+ rolling for sustain).
    fun int[] _orderedPitches()
    {
        if(listenTarget >= 0 && _agentOrdered.size() >= minPitchClasses)
            return _agentOrdered;

        int present[128];
        for(0 => int p; p < 128; p++) 0 => present[p];

        if(source == null)
            return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);

        source.completedPhrase.notes() @=> ezNote done[];
        for(0 => int i; i < done.size(); i++)
        {
            done[i].pitch() $ int => int p;
            if(SMIR.skipForPitchSet(p)) continue;
            if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
        }

        if(listenTarget < 0)
        {
            source.rollingBuffer.notes() @=> ezNote roll[];
            for(0 => int i; i < roll.size(); i++)
            {
                roll[i].pitch() $ int => int p;
                if(SMIR.skipForPitchSet(p)) continue;
                if(p >= pitchLow && p <= pitchHigh) 1 => present[p];
            }
        }

        return SMIR.orderedMidiInRange(present, pitchLow, pitchHigh);
    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled) return;
        if(srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        stopAll();
        _orderedFromNotes(phrase) @=> _agentOrdered;
        _tryPlayRolls(hopDepth + 1);
    }

    fun void onPhraseComplete()
    {
        if(!enabled) return;
        if(listenTarget != LISTEN_HUMAN) return;
        _tryPlayRolls(0);
    }

    fun void _tryPlayRolls(int hopDepth)
    {
        if(activationProb < 0.999 && Math.randomf() > activationProb)
        {
            _log("skipped (probability)");
            _idle();
            return;
        }

        _buildMultiRoll() @=> ezNote roll[];
        if(roll.size() == 0)
        {
            _orderedPitches() @=> int ordered[];
            <<< "[Peacock] skip roll: ordered=" + ordered.size() + " need>=" + minPitchClasses >>>;
            _idle();
            return;
        }
        _log("roll: " + roll.size() + " notes");
        <<< "[Peacock] roll:", roll.size(), "notes" >>>;
        _playRoll(roll, hopDepth);
    }

    fun ezNote[] _buildRollFromOrdered(int ordered[], int chordIdx, int prevRh[])
    {
        return _rollFromPlan(ordered, chordIdx, prevRh, 1);
    }

    // 1–4 rolled chords, 600–1200 ms apart; each chord uses a new LH/RH plan.
    fun ezNote[] _buildMultiRoll()
    {
        ezNote all[0];
        _orderedPitches() @=> int ordered[];
        if(ordered.size() < minPitchClasses) return all;

        for(0 => int i; i < _prevRh.size(); i++) -1 => _prevRh[i];

        ordered.size() => int n;
        listenTarget >= 0 => int agentListen;
        1 => int nChords;
        if(!agentListen && n >= 3) Math.random2(1, 2) => nChords;
        if(!agentListen && n >= 5) Math.random2(2, 4) => nChords;
        if(agentListen && n >= 5) 2 => nChords;

        0.0 => float offsetBeats;

        for(0 => int c; c < nChords; c++)
        {
            if(c > 0)
            {
                0.0 => float gapSec;
                if(agentListen) Math.random2f(0.2, 0.45) => gapSec;
                else Math.random2f(0.6, 1.2) => gapSec;
                offsetBeats + _secToBeats(gapSec) => offsetBeats;
            }
            _rollFromPlan(ordered, c, _prevRh, c > 0) @=> ezNote roll[];
            if(roll.size() == 0) continue;

            for(0 => int i; i < roll.size(); i++)
            {
                roll[i].onset() + offsetBeats => float o;
                ezNote n(o, roll[i].beats(), roll[i].pitch() $ int, roll[i].velocity());
                all << n;
            }
        }

        if(all.size() == 0)
            _rollFromPlan(ordered, 0, _prevRh, 0) @=> all;

        return all;
    }

    fun float _rollEndBeats(ezNote notes[])
    {
        0.0 => float end;
        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].onset() + notes[i].beats() => float e;
            if(e > end) e => end;
        }
        if(end < 0.25) 0.25 => end;
        return end;
    }

    fun void _playRoll(ezNote notes[], int hopDepth)
    {
        if(notes.size() == 0 || inst == null)
        {
            <<< "[Peacock] _playRoll: notes=" + notes.size() + " inst=" + (inst != null) >>>;
            return;
        }

        notes @=> _pendingNotes;
        hopDepth => _pendingHop;
        _playTicket++;
        _thinking("rolling chord");
        _playRequest.broadcast();
    }

    fun void _untrackVoice(int v)
    {
        int nv[0];
        int np[0];
        for(0 => int i; i < _liveVoices.size(); i++)
        {
            if(_liveVoices[i] != v)
            {
                _liveVoices[i] => int vv;
                _livePitches[i] => int pp;
                nv << vv;
                np << pp;
            }
        }
        nv @=> _liveVoices;
        np @=> _livePitches;
    }

    fun void _releaseVoice(int v, int pitch)
    {
        if(inst == null || v < 0) return;
        ezNote off(0, 0.01, pitch, 0);
        inst.noteOff(off, v);
        inst.release_voice(v);
        _untrackVoice(v);
    }

    fun void _silenceAllVoices()
    {
        while(_liveVoices.size() > 0)
        {
            _liveVoices[0] => int v;
            _livePitches[0] => int p;
            _releaseVoice(v, p);
        }
    }

    fun void stopAll()
    {
        _playTicket++;
        _silenceAllVoices();
        if(player.isPlaying()) player.stop();
        ezNote empty[0];
        empty @=> _pendingNotes;
    }

    fun void _noteHoldShred(ezNote n, int v, float holdBeats, int ticket)
    {
        if(holdBeats < 0.12) 0.12 => holdBeats;
        (holdBeats * 60.0 / localBpm)::second => now;
        // Always noteOff — old code skipped release when ticket changed (stuck SF2 notes).
        _releaseVoice(v, n.pitch() $ int);
    }

    fun void _playNotes(ezNote notes[], int hopDepth)
    {
        if(notes.size() == 0 || inst == null) return;

        _silenceAllVoices();

        _playing("Peacock roll");
        <<< "[Peacock] playing", notes.size(), "notes" >>>;

        -1.0 => float prevOnset;

        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].onset() => float atBeat;
            if(i > 0)
            {
                atBeat - prevOnset => float gap;
                if(gap > 0) (gap * 60.0 / localBpm)::second => now;
            }
            atBeat => prevOnset;

            notes[i].beats() => float b;
            if(b < 0.12) 0.12 => b;
            if(i + 1 < notes.size())
            {
                notes[i + 1].onset() - atBeat => float gapBeats;
                if(gapBeats > 0.05 && gapBeats < b) gapBeats => b;
            }
            if(b > 0.9) 0.9 => b;

            notes[i].pitch() $ int => int pitch;
            notes[i].velocity() => float vel;
            ezNote n(atBeat, b, pitch, vel);

            inst.allocate_voice(n) => int v;
            if(v < 0) continue;

            inst.noteOn(n, v);
            _liveVoices << v;
            _livePitches << pitch;
            _notifyPulse(vel);
            _playTicket => int ticket;
            spork ~ _noteHoldShred(n, v, b, ticket);
        }

        _rollEndBeats(notes) * 60.0 / localBpm => float tail;
        tail::second => now;

        notes @=> ezNote emitted[];
        _emitAgentPhrase(emitted, hopDepth);
        spork ~ _idleAfter(10::ms);
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(!enabled) continue;

            // Drain queue: if a new roll arrived during playback, play it too.
            while(true)
            {
                if(_pendingNotes.size() == 0 || inst == null) break;

                _playTicket => int ticket;
                _pendingHop => int hop;
                ezNote playNotes[0];
                for(0 => int i; i < _pendingNotes.size(); i++)
                {
                    ezNote n(_pendingNotes[i].onset(), _pendingNotes[i].beats(),
                        _pendingNotes[i].pitch() $ int, _pendingNotes[i].velocity());
                    playNotes << n;
                }
                _playNotes(playNotes, hop);

                if(_playTicket == ticket) break;
            }
        }
    }
}
