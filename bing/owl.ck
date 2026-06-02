@import "smuck"
@import "../agent.ck"
@import "../phraseMemory.ck"
@import "../SMIR.ck"

public class Owl extends Agent
{
    PhraseMemory @ _mem;
    0 => int _mode; // 0 develop, 1 seed
    2 => int minNotes;
    -1 => int developTechnique;
    0.3 => float minNoteDur;
    0 => int _quantizeRecall; // off by default; seeds play as stored
    0.5 => float _seedProb;
    "" => string _developDesc;
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
        else if(param == "developTechnique") val $ int => developTechnique;
        else if(param == "verbose") val $ int => verbose;
        else if(param == "clearMemory")
        {
            if(_mem != null) _mem.clear();
            _playTicket++;
            stopAll();
            0 => _seeding;
            if(_mode == 1) 1 => _canTrySilenceSeed;
        }
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
        if(_mode == 0 && source.completedPhrase.notes().size() < minNotes) return 0;
        return 1;
    }

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
            ((p % 12) + 12) % 12 => int pc;
            if(!mask[pc]) { 1 => mask[pc]; 1 => any; }
        }
        source.completedPhrase.notes() @=> ezNote doneNotes[];
        for(0 => int i; i < doneNotes.size(); i++)
        {
            doneNotes[i].pitch() $ int => int p;
            if(p < 0 || p > 127) continue;
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
                ((p % 12) + 12) % 12 => int pc;
                if(!mask[pc]) { 1 => mask[pc]; 1 => any; }
            }
        }
        return any;
    }

    fun ezNote[] _quantizeToHumanSet(ezNote n[])
    {
        int mask[12];
        if(!_humanPitchMask(mask)) return n;
        return SMIR.quantizeNotesToMask(n, mask);
    }

    fun string _developName(int id)
    {
        if(id == 0) return "retrograde";
        if(id == 1) return "sequence";
        if(id == 2) return "inversion";
        if(id == 3) return "augment";
        if(id == 4) return "diminution";
        return "develop";
    }

    fun int _pickDevelopTechnique(int haveMask)
    {
        if(developTechnique >= 0 && developTechnique <= 4)
        {
            if(developTechnique == 1 && !haveMask) return 0;
            return developTechnique;
        }
        float w[5];
        1.2 => w[0];
        if(haveMask) 1.0 => w[1]; else 0.0 => w[1];
        1.0 => w[2];
        0.9 => w[3];
        0.9 => w[4];
        float total;
        for(0 => int i; i < 5; i++) w[i] +=> total;
        if(total <= 0) return 0;
        Math.randomf() * total => float r;
        float acc;
        for(0 => int i; i < 5; i++)
        {
            w[i] +=> acc;
            if(r <= acc) return i;
        }
        return 0;
    }

    fun ezNote[] _applyDevelop(ezNote src[])
    {
        _copyNotes(src) @=> ezNote work[];
        int mask[12];
        _humanPitchMask(mask) => int haveMask;
        _pickDevelopTechnique(haveMask) => int tech;
        if(tech == 0) SMIR.retrograde(work) @=> work;
        else if(tech == 1) SMIR.sequence(work, Math.random2(2, 7)) @=> work;
        else if(tech == 2) SMIR.invert(work, -1) @=> work;
        else if(tech == 3) SMIR.augmentRhythm(work, 2.0) @=> work;
        else if(tech == 4) SMIR.diminishRhythm(work, 0.5) @=> work;
        _quantizeToHumanSet(work) @=> work;
        _developName(tech) => _developDesc;
        for(0 => int i; i < work.size(); i++)
        {
            work[i].beats() => float b;
            if(b < minNoteDur) minNoteDur => b;
            work[i].beats(b);
        }
        return work;
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
            0 => _seeding;
            1 => _canTrySilenceSeed;
        }
        else _developHuman(0);
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
        if(_mode == 0) _developFromNotes(phrase, hopDepth + 1);
    }

    fun void _developFromNotes(ezNote src[], int hopDepth)
    {
        if(src == null || src.size() < minNotes) return;
        _applyDevelop(src) @=> ezNote notes[];
        _playPhrase(notes, hopDepth);
    }

    fun void _developHuman(int hopDepth)
    {
        source.completedPhrase.notes() @=> ezNote src[];
        if(src.size() < minNotes) return;
        _applyDevelop(src) @=> ezNote notes[];
        _playPhrase(notes, hopDepth);
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
            if(_mode == 1)
            {
                SMIR.finalizePhraseDurations(playNotes, 0.12, 0.35);
                _capNoteBeats(playNotes, 1.5);
            }
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
        SMIR.finalizePhraseDurations(notes, 0.12, 0.35);
        _capNoteBeats(notes, 1.5);

        if(_mode == 1)
            _thinking("Owl seed");
        else if(_developDesc != "")
            _thinking("Owl " + _developDesc);
        else
            _thinking("Owl develop");
        ezMeasure m(notes); ezPart p; p.add(m);
        ezPart parts[1]; p @=> parts[0];
        ezScore s(parts); s.bpm(localBpm); s @=> currentScore;
        hopDepth => _pendingHop;
        if(_mode == 1)
            _log("seed " + notes.size() + " notes");
        else
            _log((_developDesc != "" ? _developDesc : "develop") + " " + notes.size() + " notes");
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
            _playing(_mode == 1 ? "Owl seed" : "Owl develop");
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
