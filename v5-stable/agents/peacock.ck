@import "smuck"
@import "../agent.ck"

// Peacock: only pays attention to chords, replays them in different inversions
public class Peacock extends Agent
{
    2 => int minNotes;

    Event _playRequest;

    fun Peacock()
    {
        "Peacock" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        spork ~ playbackWorker();
    }

    fun int shouldActivate()
    {
        if(source == null) return 0;
        if(source.completedPhrase.notes().size() < minNotes) return 0;
        return 1;
    }

    0.5 => float inversionProb; // per-note chance of octave displacement

    fun string thinkPhrase()
    {
        string options[0];
        options << "analyzing chords";
        options << "listening to harmony";
        options << "single notes are boring";
        options << "ooh i heard that chord";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string thinkPhrase(int n)
    {
        string options[0];
        options << "found " + n + " chord notes";
        options << n + " notes...";
        options << "got " + n + " chord tones, inverting some";
        options << "finding new chord voicings";
        options << "colorful chords!";
        options << "HONK";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string playPhrase(ezNote notes[])
    {
        string options[0];
        options << "inversion: " + _notesToStr(notes);
        options << "playing chords: " + _notesToStr(notes);
        options << "chord inversion: " + _notesToStr(notes);
        options << "how about THIS voicing: " + _notesToStr(notes);
        options << "HONK HONK";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun void onPhraseComplete()
    {
        _thinking(thinkPhrase());

        source.completedSmir.extractChords() @=> ezNote chords[];
        if(chords == null || chords.size() == 0) { _idle(); return; }

        _thinking(thinkPhrase(chords.size()));
        SMIR.randomInversion(chords, inversionProb) @=> ezNote inv[]; // shuffle voicings
        ezMeasure m(inv);
        ezPart p;
        p.add(m);
        ezPart parts[1];
        p @=> parts[0];
        ezScore s(parts);
        s.bpm(localBpm);
        s @=> currentScore;

        _playRequest.broadcast();
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            if(currentScore == null || inst == null) continue;

            currentScore.parts()[0].measures()[0].notes() @=> ezNote sn[];
            _playing(playPhrase(sn));
            swapScore(currentScore);
            player.loop(0);
            spork ~ _idleAfter((currentScore.beats() * 60.0 / localBpm)::second);
        }
    }
}
