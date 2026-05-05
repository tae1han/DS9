@import "smuck"
@import "../agent.ck"

// Albatross: gets the weight normalized pitch set, picks a note or two from it, and plays long sustained notes
public class Albatross extends Agent
{
    4 => int minNotes;
    4 => int minPitchClasses;
    5.0 => float holdSecondsMin;
    9.0 => float holdSecondsMax;
    72 => int baseMidi;            // register center
    2 => int octaveRange;
    2 => int maxVoices; // how many simultaneous drones
    0.2 => float velMin;
    0.5 => float velMax;

    Event _playRequest;

    fun Albatross()
    {
        "Albatross" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        0.5 => responseDelayMin;
        5 => responseDelayMax;
        spork ~ playbackWorker();
    }

    fun void setParam(string param, float val)
    {
        if(param == "minNotes") val $ int => minNotes;
        else if(param == "minPitchClasses") val $ int => minPitchClasses;
        else if(param == "holdSecondsMin") val => holdSecondsMin;
        else if(param == "holdSecondsMax") val => holdSecondsMax;
        else if(param == "maxVoices") val $ int => maxVoices;
        else if(param == "velMin") val => velMin;
        else if(param == "velMax") val => velMax;
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
        options << "sampling from pitch set";
        options << "hmm...";
        options << "I just want to pick one note";
        options << "CAW!";
        options << "feeling picky";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string thinkPhrase(int n)
    {
        string options[0];
        options << "chose " + n + " drone notes";
        options << "I'm just gonna hold " + n + " note";
        options << "lonnnng tones";
        options << "holding on to " + n + " notes";
        options << "CA CAW!";

        return options[Math.random2(0, options.size() - 1)];
    }

    fun string playPhrase(ezNote notes[])
    {
        string options[0];
        options << "sustaining: " + _notesToStr(notes);
        options << "hold long notes: " + _notesToStr(notes);
        options << "I could hold this forever... " + _notesToStr(notes);
        options << "CA CAWWWWWWWWWWWWWW! " + _notesToStr(notes);

        return options[Math.random2(0, options.size() - 1)];
    }

    // Sample a pitch class by the weighted-normalized distribution.
    fun int _samplePitchClass(float weights[])
    {
        float total;
        for(int i; i < weights.size(); i++) weights[i] +=> total;
        if(total <= 0) return Math.random2(0, 11);

        Math.randomf() * total => float r;
        float acc;
        for(int i; i < weights.size(); i++)
        {
            weights[i] +=> acc;
            if(r <= acc) return i;
        }
        return weights.size() - 1;
    }

    fun void onPhraseComplete()
    {
        _thinking(thinkPhrase());

        source.completedSmir.pitchSetWeightedNorm() @=> float w[];
        if(w == null || w.size() < 12) { _idle(); return; }

        0 => int numPCs;
        for(int i; i < 12; i++)
        {
            if(w[i] > 0) numPCs++;
        }
        if(numPCs < minPitchClasses)
        {
            _log("only " + numPCs + " pitch classes, need " + minPitchClasses);
            _idle();
            return;
        }

        Math.random2(1, maxVoices) => int nVoices;
        Math.random2f(holdSecondsMin, holdSecondsMax) => float holdS;

        ezNote held[0];
        int used[12];

        for(int v; v < nVoices; v++)
        {
            _samplePitchClass(w) => int pc;
            if(used[pc]) continue;
            1 => used[pc];

            Math.random2(-octaveRange, octaveRange) => int oct;
            baseMidi + oct * 12 => int base;
            base - (base % 12) + pc => int pitch;
            while(pitch < 30) 12 +=> pitch;
            while(pitch > 96) 12 -=> pitch;

            Math.random2f(velMin, velMax) => float vel;
            ezNote n(0.0, holdS, pitch, vel);
            held << n;
        }

        if(held.size() == 0) { _idle(); return; }

        _thinking(thinkPhrase(held.size()));

        ezMeasure m(held);
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
