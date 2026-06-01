@import "smuck"
@import "../agent.ck"

// Emu: only listens to the bottom voice of the phrase, contstructs a minimal bassline
public class Emu extends Agent
{
    1 => int minNotes;
    -12 => int transposeSemis; // octave down
    0 => int loopPlayback;
    7.0 => float gateInterval;   // interval between bottom-voice checks
    5.0 => float maxLeap;        // max semitone jump before reacquire
    4.0 => float reacquireBeats; // how long before re-locking bottom

    1 => int legatoize; // stretch notes durations to fill gaps

    Event _playRequest;

    fun Emu()
    {
        "Emu" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        0.2 => responseDelayMin;
        0.6 => responseDelayMax;
        spork ~ playbackWorker();
    }

    fun void setParam(string param, float val)
    {
        if(param == "transposeSemis") val $ int => transposeSemis;
        else if(param == "loopPlayback") val $ int => loopPlayback;
        else if(param == "gateInterval") val => gateInterval;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
    }

    fun int shouldActivate()
    {
        if(source == null) return 0;
        if(source.completedPhrase.notes().size() < minNotes) return 0;
        return 1;
    }

    fun string thinkPhrase()
    {
        string options[0];
        options << "listening for the low notes...";
        options << "needs more bass...";
        options << "extracting bottom voice";
        options << "DOH";
        options << "hmmm....";
        options << "WANT BASS";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string thinkPhrase(int n)
    {
        string options[0];
        options << "heard " + n + " bass notes";
        options << n + " low notes";
        options << "trying to make a bassline";
        options << "DOH DOH";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string playPhrase(ezNote notes[])
    {
        string options[0];
        options << "bassline: " + _notesToStr(notes);
        options << "how about this: " + _notesToStr(notes);
        options << "DOH: " + _notesToStr(notes);
        options << "adding some low notes: " + _notesToStr(notes);

        return options[Math.random2(0, options.size() - 1)];
    }

    fun void onPhraseComplete()
    {
        _thinking(thinkPhrase());

        source.completedSmir.bottomLine(gateInterval, maxLeap, reacquireBeats) @=> ezNote line[];
        if(line == null || line.size() == 0) { _idle(); return; }

        _thinking(thinkPhrase(line.size()));

        line[0].onset() => float anchor;

        ezNote out[0];
        for(int i; i < line.size(); i++)
        {
            line[i].pitch() $ int + transposeSemis => int pitch;
            if(pitch < 0) pitch + 12 => pitch;
            if(pitch > 127) pitch - 12 => pitch;

            line[i].onset() - anchor => float on;
            line[i].beats() => float b;
            if(b <= 0) 0.25 => b;

            ezNote n(on, b, pitch, line[i].velocity());
            out << n;
        }

        if(out.size() == 0) return;

        if(legatoize) _legatoize(out);

        ezMeasure m(out);
        ezPart part;
        part.add(m);
        ezPart parts[1];
        part @=> parts[0];
        ezScore s(parts);
        s.bpm(localBpm);
        s @=> currentScore;

        _playRequest.broadcast();
    }

    fun void _legatoize(ezNote out[])
    {
        for(int i; i < out.size() - 1; i++)
        {
            out[i+1].onset() - out[i].onset() => float gap;
            if(gap > 0) out[i].beats(gap);
        }
        Math.random2f(.5, 1.5) => float stretchFactor;
        2.5 * stretchFactor * (localBpm / 60.0) => float minLastBeats;
        if(out.size() > 0 && out[out.size()-1].beats() < minLastBeats)
            out[out.size()-1].beats(minLastBeats); // let the last note ring
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
            player.loop(loopPlayback);
            spork ~ _idleAfter((currentScore.beats() * 60.0 / localBpm)::second);
        }
    }
}
