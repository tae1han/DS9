@import "smuck"
@import "../agent.ck"

// Parrot: mimicks user phrase exactly
public class Parrot extends Agent
{
    2 => int minNotes;
    0.0 => float delayMin;
    4.0 => float delayMax;
    .5 => float probability; // whether to activate 
    Event _playRequest;

    fun Parrot()
    {
        "Parrot" => name;
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
        if(src == null || src.size() < minNotes)
        {
            return;
        }

        _thinking(thinkPhrase(src.size()));

        source.completedPhrase.copy() @=> ezMeasure m; 
        ezPart part;
        part.add(m);
        ezPart parts[1];
        part @=> parts[0];
        ezScore score(parts);
        score.bpm(localBpm);

        score @=> currentScore;
        _playRequest.broadcast();

        if(verbose)
        {
            chout <= "[Parrot] queued phrase: notes=" <= src.size()
                  <= " beats=" <= currentScore.beats() <= IO.newline();
        }
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

            currentScore.parts()[0].measures()[0].notes() @=> ezNote sn[];
            _playing(playPhrase(sn));
            swapScore(currentScore);
            player.loop(0);
            spork ~ _idleAfter((currentScore.beats() * 60.0 / localBpm)::second);
        }
    }
}
