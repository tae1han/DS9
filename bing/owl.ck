@import "smuck"
@import "../agent.ck"
@import "../phraseMemory.ck"
@import "../SMIR.ck"

public class Owl extends Agent
{
    PhraseMemory @ _mem;
    0 => int _mode; // 0 echo, 1 memory seed
    0 => int _quantizeRecall; // off by default; seeds play as stored
    0.5 => float _seedProb;
    2.0 => float postSeedQuietMin;
    4.0 => float postSeedQuietMax;
    Event _playRequest;
    int _pendingHop;
    int _playTicket;
    int _seeding;
    int _canTrySilenceSeed;
    time _seedAllowedAfter;

    fun Owl()
    {
        "Owl" => name;
        0 => cancelOnNewPhrase;
        0.0 => responseDelayMin;
        0.0 => responseDelayMax;
        60.0 => localBpm;
        1 => _canTrySilenceSeed;
        spork ~ playbackWorker();
    }

    fun void bindMemory(PhraseMemory @ m) { m @=> _mem; }

    fun void setParam(string param, float val)
    {
        if(param == "owlMode")
        {
            val $ int => int newMode;
            if(newMode != _mode)
            {
                newMode => _mode;
                _playTicket++;
                stopAll();
            }
            if(_mode == 1)
            {
                1 => _canTrySilenceSeed;
                0 => _seeding;
            }
        }
        else if(param == "quantizeRecall") val $ int => _quantizeRecall;
        else if(param == "seedProb") val => _seedProb;
        else if(param == "postSeedQuietMin") val => postSeedQuietMin;
        else if(param == "postSeedQuietMax") val => postSeedQuietMax;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "eddiesEnabled") val $ int => _eddiesEnabled;
        else if(param == "phraseOnlyEddies") val $ int => _phraseOnlyEddies;
        else if(param == "maxHopDepth") val $ int => _maxHopDepth;
        else if(param == "seedCooldownMs") val $ int => _seedCooldownMs;
        else if(param == "verbose") val $ int => verbose;
    }

    fun void stopAll()
    {
        _playTicket++;
        _silenceInstrument();
        if(player.isPlaying()) player.stop();
    }

    fun void _silenceInstrument()
    {
        if(inst == null) return;
        for(0 => int v; v < inst.numVoices(); v++)
        {
            for(0 => int p; p < 128; p++)
            {
                ezNote off(0, 0.01, p, 0);
                inst.noteOff(off, v);
            }
            inst.release_voice(v);
        }
    }

    fun void _emitScoreNotesToBus(ezScore s, int hopDepth, int ticket)
    {
        if(s == null || s.parts().size() == 0) return;
        s.parts()[0].measures()[0].notes() @=> ezNote notes[];
        if(notes.size() == 0) return;

        60.0 / localBpm => float secPerBeat;
        for(int i; i < notes.size(); i++)
        {
            if(_playTicket != ticket || !enabled) return;

            if(i > 0)
            {
                notes[i].onset() - notes[i-1].onset() => float gap;
                if(gap > 0) (gap * secPerBeat)::second => now;
            }
            else if(notes[0].onset() > 0)
                notes[0].onset() * secPerBeat::second => now;

            notes[i].pitch() $ int => int pitch;
            notes[i].velocity() => float vel;
            notes[i].beats() => float b;
            ezNote n(notes[i].onset(), b, pitch, vel);
            _emitAgentNote(n, hopDepth);
            _notifyPulse(vel);
        }
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        return 1;
    }

    fun ezNote[] _quantizeRecalled(ezNote recalled[])
    {
        int mask[12];
        for(0 => int i; i < 12; i++) 0 => mask[i];
        for(0 => int i; i < recalled.size(); i++)
        {
            ((recalled[i].pitch() $ int) % 12 + 12) % 12 => int pc;
            1 => mask[pc];
        }
        if(source != null)
        {
            source.completedPhrase.notes() @=> ezNote done[];
            for(0 => int i; i < done.size(); i++)
            {
                ((done[i].pitch() $ int) % 12 + 12) % 12 => int pc;
                1 => mask[pc];
            }
        }
        0 => int pcs;
        for(0 => int i; i < 12; i++)
            if(mask[i]) pcs++;
        if(pcs >= 2) return SMIR.quantizeNotesToMask(recalled, mask);
        return recalled;
    }

    fun void onPhraseComplete()
    {
        if(!enabled) return;
        if(listenTarget != LISTEN_HUMAN) return;
        if(_mode == 1)
        {
            0 => _seeding; // recover if playback worker skipped
            1 => _canTrySilenceSeed;
        }
        if(_mode == 0) _echoHuman(0);
    }

    fun void onSilenceSustained(float s)
    {
        if(!enabled) return;
        if(_mode != 1) return;
        if(!_eddiesEnabled) return;
        if(_seeding) return;
        if(!_canTrySilenceSeed) return;
        if(now < _seedAllowedAfter) return;
        if(_mem == null || _mem.count() == 0) return;
        if((now - _lastSeedTime) < (_seedCooldownMs::ms)) return;
        if(Math.randomf() > _seedProb) return;

        if(_trySeed())
            0 => _canTrySilenceSeed;
        else
            spork ~ _armNextSeedWindow();
    }

    fun void _armNextSeedWindow()
    {
        Math.random2f(postSeedQuietMin, postSeedQuietMax)::second => now;
        1 => _canTrySilenceSeed;
    }

    fun int _trySeed()
    {
        _mem.recallRandom() @=> ezNote recalled[];
        if(recalled.size() < 2)
        {
            if(verbose) _log("seed skip: recall has " + recalled.size() + " notes");
            return 0;
        }

        if(_quantizeRecall)
            _quantizeRecalled(recalled) @=> recalled;

        now => _lastSeedTime;
        1 => _seeding;
        if(verbose)
            _log("seed recall slot " + _mem.lastRecallWhich() + " / " + (_mem.count() - 1));
        _playPhrase(recalled, 0);
        return 1;
    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        if(_mode == 0) _echoFromNotes(phrase, hopDepth + 1);
    }

    fun void _echoFromNotes(ezNote src[], int hopDepth)
    {
        if(src == null || src.size() < 2) return;
        _copyNotes(src) @=> ezNote notes[];
        _playPhrase(notes, hopDepth);
    }

    fun void _echoHuman(int hopDepth)
    {
        source.completedPhrase.notes() @=> ezNote src[];
        if(src.size() < 2) return;
        _copyNotes(src) @=> ezNote notes[];
        _playPhrase(notes, hopDepth);
    }

    // Chord tones at the same onset share sustain (avoids plucked zero-length notes).
    fun void _sustainEchoNotes(ezNote notes[])
    {
        if(notes.size() == 0) return;

        SMIR.finalizePhraseDurations(notes, 0.2, 1.0);

        0.05 => float onsetEps;
        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].onset() => float t0;
            t0 => float groupEnd;

            for(0 => int j; j < notes.size(); j++)
            {
                if(Math.fabs(notes[j].onset() - t0) < onsetEps)
                {
                    notes[j].onset() + notes[j].beats() => float e;
                    if(e > groupEnd) e => groupEnd;
                }
            }

            for(0 => int j; j < notes.size(); j++)
            {
                if(Math.fabs(notes[j].onset() - t0) < onsetEps)
                {
                    groupEnd - notes[j].onset() => float dur;
                    if(dur < 0.5) 0.5 => dur;
                    dur => notes[j].beats;
                }
            }
        }
    }

    fun void _capNoteBeats(ezNote notes[], float maxBeats)
    {
        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].beats() => float b;
            if(b > maxBeats) maxBeats => b;
            if(b < 0.08) 0.08 => b;
            b => notes[i].beats;
        }
    }

    fun void swapScore(ezScore s)
    {
        if(s == null || s.parts().size() == 0) return;

        _silenceInstrument();
        if(player.isPlaying()) player.stop();
        s @=> currentScore;
        if(s.parts().size() > 0 && s.parts()[0].measures().size() > 0)
        {
            s.parts()[0].measures()[0].notes() @=> ezNote playNotes[];
            if(_mode == 0)
                SMIR.finalizePhraseDurations(playNotes, 0.25, 1.0);
            else
            {
                SMIR.finalizePhraseDurations(playNotes, 0.12, 0.35);
                _capNoteBeats(playNotes, 1.5);
            }
        }
        player.score(s);
        if(inst != null) player.instruments(0, inst);
        player.startPos(0.0);
        player.endPos(_scorePlayEndBeats(s));
        player.pos(0.0);
        player.bpm(localBpm);
        player.play();
        spork ~ _scoreNotePulses(s);
    }

    fun void _playPhrase(ezNote notes[], int hopDepth)
    {
        if(!acceptAgentHop(hopDepth)) return;
        if(notes.size() == 0) return;

        stopAll();
        if(_mode == 0)
        {
            _sustainEchoNotes(notes);
            _capNoteBeats(notes, 0.9);
        }
        else
        {
            SMIR.finalizePhraseDurations(notes, 0.12, 0.35);
            _capNoteBeats(notes, 1.5);
        }

        _thinking(_mode == 1 ? "Owl seed" : "Owl echo");
        ezMeasure m(notes); ezPart p; p.add(m);
        ezPart parts[1]; p @=> parts[0];
        ezScore s(parts); s.bpm(localBpm); s @=> currentScore;
        hopDepth => _pendingHop;
        _log((_mode == 1 ? "seed" : "echo") + " " + notes.size() + " notes");
        _playRequest.broadcast();
    }

    fun void _waitPlayback(float durSec, int ticket)
    {
        0.0 => float elapsed;
        while(elapsed < durSec)
        {
            if(_playTicket != ticket) return;
            25::ms => now;
            elapsed + 0.025 => elapsed;
        }
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(!enabled) continue;
            if(currentScore == null || inst == null)
            {
                if(_mode == 1)
                {
                    0 => _seeding;
                    1 => _canTrySilenceSeed;
                    if(verbose) _log("seed playback skip: no score or instrument");
                }
                continue;
            }

            _playTicket => int ticket;
            _playing(_mode == 1 ? "Owl seed" : "Owl echo");
            swapScore(currentScore);
            spork ~ _emitScoreNotesToBus(currentScore, _pendingHop, ticket);
            currentScore.parts()[0].measures()[0].notes() @=> ezNote sn[];
            _emitAgentPhrase(sn, _pendingHop);
            _scorePlayEndBeats(currentScore) * 60.0 / localBpm => float durSec;
            _waitPlayback(durSec, ticket);

            if(_playTicket != ticket)
            {
                _silenceInstrument();
                if(player.isPlaying()) player.stop();
                if(_mode == 1) 0 => _seeding;
                continue;
            }

            _silenceInstrument();
            if(player.isPlaying()) player.stop();

            if(_mode == 1)
            {
                0 => _seeding;
                0 => _canTrySilenceSeed;
                Math.random2f(postSeedQuietMin, postSeedQuietMax)::second + now => _seedAllowedAfter;
                spork ~ _armNextSeedWindow();
                _log("seed done; next window after quiet");
            }

            spork ~ _idleAfter(durSec::second);
        }
    }
}
