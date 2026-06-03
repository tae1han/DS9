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
    0.45 => float velMin;
    0.82 => float velMax;
    0.5 => float activationProb;
    int _runTicket;

    fun Falcon()
    {
        "Falcon" => name;
        1 => cancelOnNewPhrase; // stop mid-run if new input comes in
        60.0 => localBpm;
    }

    fun void setParam(string param, float val)
    {
        if(param == "probability") val => activationProb;
        else if(param == "numNotesMin") val $ int => numNotesMin;
        else if(param == "numNotesMax") val $ int => numNotesMax;
        else if(param == "stepMsMin") val => stepMsMin;
        else if(param == "stepMsMax") val => stepMsMax;
        else if(param == "stepJitterMs") val => stepJitterMs;
        else if(param == "noteDurMs") val => noteDurMs;
        else if(param == "lowMidi") val $ int => lowMidi;
        else if(param == "highMidi") val $ int => highMidi;
        else if(param == "reversalProb") val => reversalProb;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        if(listenTarget != LISTEN_HUMAN) return 0;
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

    // Sequential noteOn/noteOff in this shred — do not spork per note (voice steal
    // via playDirect leaves FluidSynth notes stuck with no noteOff).
    fun void _playRunNote(int pitch, float vel, float holdMs)
    {
        if(inst == null) return;
        if(holdMs < 30) 30 => holdMs;

        ezNote n(0.0, holdMs / 1000.0, pitch, vel);
        inst.allocate_voice(n) => int v;
        if(v < 0) return;

        inst.noteOn(n, v);
        _emitAgentNote(n, 0);
        _notifyPulse(vel);
        holdMs::ms => now;
        inst.noteOff(n, v);
        inst.release_voice(v);
    }

    fun void _silencePitch(int pitch)
    {
        if(inst == null || pitch < 0 || pitch > 127) return;
        ezNote n(0.0, 0.01, pitch, 0.0);
        inst.noteOff(n, 0);
    }

    fun void _silenceRunRange()
    {
        if(inst == null) return;
        for(lowMidi => int p; p <= highMidi; p++)
            _silencePitch(p);
    }

    fun int _runAlive(int myTicket)
    {
        return (myTicket == _runTicket && enabled);
    }

    fun void onPhraseStart()
    {
        _runTicket++;
        _silenceRunRange();
        stopAll();
    }

    fun void onPhraseComplete()
    {
        if(!enabled) return;
        if(listenTarget != LISTEN_HUMAN) return;
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

        _runTicket++;
        _runTicket => int myTicket;
        _silenceRunRange();

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
        -1 => int lastPlayedPitch;

        while(played < numNotes)
        {
            if(!_runAlive(myTicket))
            {
                _silenceRunRange();
                return;
            }

            ((curr % 12) + 12) % 12 => int pc;
            if(active[pc])
            {
                _silencePitch(curr);
                Math.random2f(velMin, velMax) => float vel;
                Math.min(noteDurMs, stepMs * 0.85) => float holdMs;
                _playRunNote(curr, vel, holdMs);
                curr => lastPlayedPitch;
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

        if(_runAlive(myTicket))
        {
            if(lastPlayedPitch >= 0) _silencePitch(lastPlayedPitch);
            _silenceRunRange();
            _idle();
        }
    }
}
