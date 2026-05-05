@import "smuck"
@import "../agent.ck"

// Falcon: does scale runs based on the current pitch set extracted from the rolling buffer

public class Falcon extends Agent
{
    2 => int minRollingNotes;
    8 => int numNotesMin;
    24 => int numNotesMax;
    40.0 => float stepMsMin; // min step duration
    180.0 => float stepMsMax; // max step duration
    20.0 => float stepJitterMs; // random jitter to step dur
    0.05 => float reversalProb; // chance of briefly going the other direction
    7 => int reversalSemis;
    400.0 => float noteDurMs;
    48 => int lowMidi;
    96 => int highMidi;
    0.2 => float velMin;
    0.8 => float velMax;
    0.5 => float activationProb;

    fun Falcon()
    {
        "Falcon" => name;
        1 => cancelOnNewPhrase; // stop mid-run if new input comes in
        60.0 => localBpm;
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        if(source.rollingBuffer.notes().size() < minRollingNotes) return 0;
        return 1;
    }

    fun string playPhrase(string dir, string startNote, int numNotes)
    {
        string options[0];
        options << dir + " run from " + startNote + ", " + numNotes + " notes";
        options << "swooping " + dir + " from " + startNote;
        options << numNotes + "-note dive starting at " + startNote;
        options << "DIVE BOMB!";
        options << "watch this: " + dir + " run, " + numNotes + " notes";
        options << "FALCON PUNCH!";
        options << "GOTTA GO FAST!";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string tickPhrase(string dir, string currNote, int played, int total)
    {
        string options[0];
        options << dir + ": " + currNote + " (" + played + "/" + total + ")";
        options << currNote + " ~ " + played + "/" + total;
        options << currNote + "! (" + played + " of " + total + ")";
        options << currNote + "!!1!";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun void onPhraseComplete()
    {
        if(Math.randomf() > activationProb) return;

        source.rollingSmir.pitchNormSet() @=> float w[];
        if(w == null || w.size() < 12) return;

        int active[12];
        int anyActive;
        for(int i; i < 12; i++)
        {
            if(w[i] > 0) { 1 => active[i]; 1 => anyActive; }
        }
        if(!anyActive) return;

        Math.random2(0, 1) => int ascending;
        Math.random2(numNotesMin, numNotesMax) => int numNotes;
        Math.random2f(stepMsMin, stepMsMax) => float stepMs;

        int startPitch;
        if(ascending) Math.random2(lowMidi, lowMidi + 24) => startPitch;
        else Math.random2(highMidi - 24, highMidi) => startPitch;

        "ascending" => string dir;
        if(!ascending) "descending" => dir;
        _playing(playPhrase(dir, Smuck.mid2str(startPitch), numNotes));

        startPitch => int curr;
        0 => int played;

        while(played < numNotes)
        {
            ((curr % 12) + 12) % 12 => int pc;
            if(active[pc])
            {
                Math.random2f(velMin, velMax) => float vel;
                ezNote n(0.0, noteDurMs / 1000.0, curr, vel);
                playDirect(n);
                played++;
                tickPhrase(dir, Smuck.mid2str(curr), played, numNotes) => displayBody;
                (stepMs + Math.random2f(-stepJitterMs, stepJitterMs))::ms => now;
            }

            if(Math.randomf() < reversalProb)
            {
                if(ascending) curr - reversalSemis => curr;
                else curr + reversalSemis => curr;
            }
            else
            {
                if(ascending) curr + 1 => curr;
                else curr - 1 => curr;
            }

            if(curr > highMidi) break;
            if(curr < lowMidi) break;
        }

        _idle();
    }
}
