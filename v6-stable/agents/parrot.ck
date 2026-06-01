@import "smuck"
@import "../agent.ck"

// Parrot: mimicks user phrase exactly
public class Parrot extends Agent
{
    2 => int minNotes;
    0.0 => float delayMin;
    4.0 => float delayMax;
    .5 => float probability;
    Event _playRequest;
    string _pendingDesc;

    // variation parameters
    0.0 => float octaveDisplaceProb; // per-note chance of +/- 1 octave
    1.0 => float rhythmScale;        // multiplier on note durations (0.5 = double speed, 2.0 = half speed)
    0 => int truncateMin;            // min notes to keep (0 = no truncation)
    0 => int truncateMax;            // max notes to keep (0 = no truncation)
    1 => int repeatsMin;             // min times to play the phrase
    1 => int repeatsMax;             // max times to play the phrase
    0.3 => float minNoteDur;         // minimum note duration in beats (always applied)

    fun Parrot()
    {
        "Parrot" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        spork ~ playbackWorker();
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
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
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

    fun void onPhraseComplete()
    {
        if(inst == null || source == null) return;
        source.completedPhrase.notes() @=> ezNote src[];
        if(src == null || src.size() < minNotes) return;

        _thinking(thinkPhrase(src.size()));

        // copy notes for transformation, enforce minimum duration
        ezNote notes[0];
        for(int i; i < src.size(); i++)
        {
            src[i].beats() => float b;
            if(b < minNoteDur) minNoteDur => b;
            ezNote n(src[i].onset(), b, src[i].pitch(), src[i].velocity());
            notes << n;
        }

        // track transformations for display
        src.size() => int originalSize;
        0 => int didTruncate;
        0 => int octaveShift;
        0 => int didScale;

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

        // octave displacement (whole phrase)
        if(octaveDisplaceProb > 0 && Math.randomf() < octaveDisplaceProb)
        {
            Math.random2(0, 1) * 2 - 1 => int dir; // -1 or +1
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

        // rhythmic scaling
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

        // build display description
        notes.size() + " notes" => string desc;
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
        _playRequest.broadcast();
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(currentScore == null || inst == null) continue;
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
            currentScore.beats() * 60.0 / localBpm => float phraseDurSec;
            for(int r; r < reps; r++)
            {
                swapScore(currentScore);
                player.loop(0);
                phraseDurSec::second => now;
            }
            _idle();
        }
    }
}
