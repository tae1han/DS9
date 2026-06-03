@import "smuck"
@import "../lib/agent.ck"
@import "../lib/SMIR.ck"

// Parrot: mimicks user phrase exactly
public class Parrot extends Agent
{
    2 => int minNotes;
    0.05 => float delayMin;
    0.75 => float delayMax;
    1.0 => float probability;
    Event _playRequest;
    string _pendingDesc;
    int _playTicket;

    // variation parameters
    0.0 => float octaveDisplaceProb; // per-note chance of +/- 1 octave
    1.0 => float rhythmScale;        // multiplier on note durations (0.5 = double speed, 2.0 = half speed)
    0 => int truncateMin;            // min notes to keep (0 = no truncation)
    0 => int truncateMax;            // max notes to keep (0 = no truncation)
    1 => int repeatsMin;             // min times to play the phrase
    1 => int repeatsMax;             // max times to play the phrase
    0.3 => float minNoteDur;
    0 => int _mode; // 0 echo, 1 develop
    -1 => int developTechnique; // -1 random, 0 retro, 1 seq, 2 inv, 3 aug, 4 dim

    fun Parrot()
    {
        "Parrot" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        spork ~ playbackWorker();
    }

    fun void stopAll()
    {
        _playTicket++;
        _releaseAllInstrumentVoices();
        if(player.isPlaying()) player.stop();
    }

    fun void setParam(string param, float val)
    {
        if(param == "probability") val => probability;
        else if(param == "delayMin") val => delayMin;
        else if(param == "delayMax") val => delayMax;
        else if(param == "octaveDisplaceProb") val => octaveDisplaceProb;
        else if(param == "rhythmScale") val => rhythmScale;
        else if(param == "truncateMin") val $ int => truncateMin;
        else if(param == "truncateMax") val $ int => truncateMax;
        else if(param == "repeatsMin") val $ int => repeatsMin;
        else if(param == "repeatsMax") val $ int => repeatsMax;
        else if(param == "mode") val $ int => _mode;
        else if(param == "developTechnique") val $ int => developTechnique;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
        else if(param == "listenTarget") setListenTarget(val $ int);
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

    // Pitch classes from human input only (rolling + completed + live phrase).
    // Returns 0 if no pitches yet — never defaults to all 12 classes.
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

    fun ezNote[] _quantizeToHumanSet(ezNote n[])
    {
        int mask[12];
        if(!_humanPitchMask(mask)) return n;
        return SMIR.quantizeNotesToMask(n, mask);
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

    fun ezNote[] _prepareNotes(ezNote src[])
    {
        ezNote out[0];
        if(src == null) return out;
        for(int i; i < src.size(); i++)
        {
            src[i].beats() => float b;
            if(b < minNoteDur) minNoteDur => b;
            ezNote n(src[i].onset(), b, src[i].pitch(), src[i].velocity());
            out << n;
        }
        return out;
    }

    fun void _clampMinDurations(ezNote notes[])
    {
        for(int i; i < notes.size(); i++)
        {
            notes[i].beats() => float b;
            if(b < minNoteDur) minNoteDur => b;
            notes[i].beats(b);
        }
    }

    fun float _notesEndBeats(ezNote notes[])
    {
        0.0 => float end;
        for(int i; i < notes.size(); i++)
        {
            notes[i].onset() + notes[i].beats() => float e;
            if(e > end) e => end;
        }
        return end;
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
        _developName(tech) @=> _pendingDesc;
        return work;
    }

    fun int shouldActivate()
    {
        if(source == null) return 0;
        if(source.completedPhrase.notes().size() < minNotes) return 0;
        return 1;
    }

    fun string thinkPhrase(int n)
    {
        string options[0];
        options << "I heard " + n + " notes, getting ready to echo";
        options << "ooh I liked that. I want to try";
        options << "I'm gonna copy those " + n + " notes";
        options << "Squawk!";
        options << "I liked those last " + n + " notes";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string playPhrase(ezNote n[])
    {
        string options[0];
        options << "Echoing: ";
        options << "like this! ";
        options << "SQUAWK! SQUAWK!";
        options << "copying you! ";
        options << "Me too! ";

        options[Math.random2(0, options.size() - 1)] => string s;
        for(int i; i < n.size(); i++)
        {
            s + " " + Smuck.mid2str(n[i].pitch()) => s;
        }
        return s;

    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        _planFromNotes(phrase, hopDepth + 1);
    }

    fun void onPhraseComplete()
    {
        if(listenTarget != LISTEN_HUMAN) return;
        source.completedPhrase.notes() @=> ezNote src[];
        _planFromNotes(src, 0);
    }

    fun void _planFromNotes(ezNote src[], int hopDepth)
    {
        if(inst == null || source == null) return;
        if(src == null || src.size() < minNotes) return;

        _thinking(thinkPhrase(src.size()));

        _prepareNotes(src) @=> ezNote prepared[];

        // build score
        ezNote notes[0];
        if(_mode == 1)
        {
            _applyDevelop(prepared) @=> notes;
            _clampMinDurations(notes);
        }
        else
        {
            "" => _pendingDesc;
            prepared @=> notes;
        }

        // track transformations for display
        src.size() => int originalSize;
        0 => int didTruncate;
        0 => int octaveShift;
        0 => int didScale;

        // echo-only variations (not applied in develop mode)
        if(_mode == 0)
        {
            // truncate (takes last N notes from phrase)
            if(truncateMin > 0 && truncateMax > 0 && notes.size() > truncateMin && Math.randomf() < 0.25)
            {
                Math.random2(truncateMin, Math.min(truncateMax, notes.size())) => int keep;
                ezNote trimmed[0];
                notes.size() - keep => int startIdx;
                notes[startIdx].onset() => float anchorOnset;
                for(startIdx => int i; i < notes.size(); i++)
                {
                    ezNote n(notes[i].onset() - anchorOnset, notes[i].beats(), notes[i].pitch(), notes[i].velocity());
                    trimmed << n;
                }
                trimmed @=> notes;
                1 => didTruncate;
            }

            if(octaveDisplaceProb > 0 && Math.randomf() < octaveDisplaceProb)
            {
                Math.random2(0, 1) * 2 - 1 => int dir;
                dir * 12 => int shift;
                for(int i; i < notes.size(); i++)
                {
                    notes[i].pitch() $ int + shift => int p;
                    if(p < 21) p + 12 => p;
                    if(p > 108) p - 12 => p;
                    notes[i].pitch(p);
                }
                dir => octaveShift;
            }

            if(rhythmScale != 1.0)
            {
                for(int i; i < notes.size(); i++)
                {
                    notes[i].onset() * rhythmScale => notes[i].onset;
                    notes[i].beats() * rhythmScale => float newBeats;
                    if(newBeats < 0.25) 0.25 => newBeats;
                    notes[i].beats(newBeats);
                }
                1 => didScale;
            }
        }

        // build display description
        string desc;
        if(_mode == 1 && _pendingDesc != "")
            _pendingDesc + " " + notes.size() + " notes" => desc;
        else
            notes.size() + " notes" => desc;
        if(didTruncate) desc + " (from " + originalSize + ")" => desc;
        if(octaveShift > 0) desc + " +8va" => desc;
        else if(octaveShift < 0) desc + " -8va" => desc;
        if(didScale) { if(rhythmScale < 1.0) desc + " faster" => desc; else desc + " slower" => desc; }
        desc @=> _pendingDesc;

        // build score
        ezMeasure m(notes);
        ezPart part;
        part.add(m);
        ezPart parts[1];
        part @=> parts[0];
        ezScore score(parts);
        score.bpm(localBpm);

        score @=> currentScore;
        hopDepth => _pendingHop;
        _playRequest.broadcast();
    }

    int _pendingHop;

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

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(!enabled) continue;
            if(currentScore == null || inst == null) continue;
            _playTicket => int ticket;
            if(Math.randomf() > probability)
            {
                _idle();
                continue;
            }

            Math.random2f(delayMin, delayMax)::second => now;

            Math.random2(repeatsMin, repeatsMax) => int reps;
            _pendingDesc => string desc;
            if(reps > 1) desc + " x" + reps => desc;
            _playing(desc);
            currentScore.parts()[0].measures()[0].notes() @=> ezNote playNotes[];
            _notesEndBeats(playNotes) * 60.0 / localBpm => float phraseDurSec;
            for(int r; r < reps; r++)
            {
                if(_playTicket != ticket || !enabled) break;
                swapScore(currentScore);
                if(r == 0) spork ~ _emitScoreNotesToBus(currentScore, _pendingHop, ticket);
                player.loop(0);
                phraseDurSec::second => now;
                if(_playTicket != ticket || !enabled) break;
            }
            currentScore.parts()[0].measures()[0].notes() @=> ezNote out[];
            _emitAgentPhrase(out, _pendingHop);
            _idle();
        }
    }
}
