@import "smuck"
@import "../lib/agent.ck"

@import "../instruments/albatrossSynthInst.ck"

// Albatross: pitch-set drones with ascending portamento or conditional trill (custom synth).
public class Albatross extends Agent
{
    4 => int minNotes;
    4 => int minPitchClasses;
    2.0 => float holdSecondsMin;
    4.0 => float holdSecondsMax;
    72 => int baseMidi;            // register center
    2 => int octaveRange;
    2 => int maxVoices; // how many simultaneous drones
    0.15 => float velMin;
    0.35 => float velMax;
    // Trill controls (performance defaults).
    0.28 => float trillProb;
    4.5 => float trillRateMinHz;      // preserve slow trill floor
    16.0 => float trillRateMaxHz;     // keep expanded fast ceiling
    0.6 => float trillRampProb;
    3.0 => float trillRampMinSpanHz;  // enough motion to hear contour

    Event _playRequest;
    int _pendingHop;
    int _playGen;
    int _playTicket;
    ezNote _heldNotes[0];
    float _holdSec;

    fun Albatross()
    {
        "Albatross" => name;
        1 => cancelOnNewPhrase;
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
        else if(param == "trillProb") val => trillProb;
        else if(param == "trillRateMinHz") val => trillRateMinHz;
        else if(param == "trillRateMaxHz") val => trillRateMaxHz;
        else if(param == "trillRampProb") val => trillRampProb;
        else if(param == "trillRampMinSpanHz") val => trillRampMinSpanHz;
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

    fun int _pcActive(float w[], int pc)
    {
        ((pc % 12) + 12) % 12 => pc;
        if(pc < 0 || pc >= w.size()) return 0;
        return w[pc] > 0;
    }

    // Build a robust pitch-class weight vector from completedPhrase notes.
    // IMPORTANT: phraseComplete can fire while notes are still held (sustain pedal),
    // so note durations can be 0. We treat each note as weight 1.0 for PC activity.
    fun int _pcWeightsFromCompleted(float w[], int active[])
    {
        0 => int numPCs;
        for(0 => int i; i < 12; i++)
        {
            0.0 => w[i];
            0 => active[i];
        }

        if(source == null) return numPCs;
        source.completedPhrase.notes() @=> ezNote notes[];
        if(notes == null) return numPCs;

        for(0 => int i; i < notes.size(); i++)
        {
            notes[i].pitch() $ int => int p;
            if(p < 0 || p > 127) continue;
            if(SMIR.skipForPitchSet(p)) continue;
            ((p % 12) + 12) % 12 => int pc;
            1.0 +=> w[pc];
            if(!active[pc]) { 1 => active[pc]; numPCs++; }
        }
        return numPCs;
    }

    fun int _trillPartner(int pitch, float w[])
    {
        int partners[0];
        if(_pcActive(w, (pitch - 2) % 12)) partners << pitch - 2;
        if(_pcActive(w, (pitch + 2) % 12)) partners << pitch + 2;
        if(partners.size() == 0) return -1;
        return partners[Math.random2(0, partners.size() - 1)];
    }

    fun void _stopSynth()
    {
        inst $ albatrossSynthInst @=> albatrossSynthInst synth;
        if(synth != null) synth.allOff();
    }

    fun void stopAll()
    {
        _playGen++;
        if(player.isPlaying()) player.stop();
        _stopSynth();
    }

    fun void _synthVoice(int pitch, float holdS, float vel, float w[], int gen)
    {
        if(gen != _playGen || !enabled) return;
        inst $ albatrossSynthInst @=> albatrossSynthInst synth;
        if(synth == null) return;

        if(trillProb < 0.0) 0.0 => trillProb;
        if(trillProb > 1.0) 1.0 => trillProb;
        if(trillRateMinHz < 2.0) 2.0 => trillRateMinHz;
        if(trillRateMaxHz < trillRateMinHz) trillRateMinHz => trillRateMaxHz;
        if(trillRampProb < 0.0) 0.0 => trillRampProb;
        if(trillRampProb > 1.0) 1.0 => trillRampProb;
        if(trillRampMinSpanHz < 0.0) 0.0 => trillRampMinSpanHz;

        _trillPartner(pitch, w) => int partner;
        _notifyPulse(vel);
        if(partner >= 0 && Math.randomf() < trillProb)
        {
            Math.random2f(trillRateMinHz, trillRateMaxHz) => float hzA;
            Math.random2f(trillRateMinHz, trillRateMaxHz) => float hzB;
            if(Math.fabs(hzA - hzB) < trillRampMinSpanHz)
            {
                if(Math.randomf() < 0.5)
                    Math.min(trillRateMaxHz, hzA + trillRampMinSpanHz) => hzB;
                else
                    Math.max(trillRateMinHz, hzA - trillRampMinSpanHz) => hzB;
            }
            if(Math.randomf() < trillRampProb)
                synth.trillHoldRamp(pitch, partner, holdS, vel, hzA, hzB);
            else
                synth.trillHold(pitch, partner, holdS, vel, hzA);
        }
        else
        {
            Math.random2(5, 12) => int drop;
            pitch - drop => int fromP;
            while(fromP < 30) 12 +=> fromP;
            Math.random2f(0.25, 1.25) => float glide;
            synth.glideAscend(fromP, pitch, glide, holdS, vel);
        }
    }

    fun void onPhraseComplete()
    {
        if(listenTarget != LISTEN_HUMAN) return;
        _doDrones(0);
    }

    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth)
    {
        if(!enabled || srcSlot != listenTarget) return;
        if(!acceptAgentHop(hopDepth)) return;
        _doDrones(hopDepth + 1);
    }

    fun void _doDrones(int hopDepth)
    {
        _connectInst();
        _playGen++;
        _stopSynth();

        _thinking(thinkPhrase());

        float w[12];
        int active[12];
        _pcWeightsFromCompleted(w, active) => int numPCs;
        if(numPCs <= 0) { _idle(); return; }
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
        holdS => _holdSec;
        held @=> _heldNotes;
        hopDepth => _pendingHop;
        _playGen => _playTicket;
        _playRequest.broadcast();
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            _connectInst();
            if(inst == null || _heldNotes.size() == 0) continue;

            _playTicket => int gen;
            if(gen != _playGen) continue;

            _playing(playPhrase(_heldNotes));
            inst $ albatrossSynthInst @=> albatrossSynthInst synth;
            if(synth != null)
            {
                float w[12];
                int active[12];
                _pcWeightsFromCompleted(w, active);
                for(int i; i < _heldNotes.size(); i++)
                {
                    if(gen != _playGen) break;
                    _heldNotes[i].pitch() $ int => int p;
                    _heldNotes[i].velocity() => float vel;
                    spork ~ _synthVoice(p, _holdSec, vel, w, gen);
                }
                _emitAgentPhrase(_heldNotes, _pendingHop);
                spork ~ _idleAfter(_holdSec::second);
            }
            else
            {
                ezMeasure m(_heldNotes);
                ezPart p;
                p.add(m);
                ezPart parts[1];
                p @=> parts[0];
                ezScore s(parts);
                s.bpm(localBpm);
                s @=> currentScore;
                swapScore(currentScore);
                player.loop(0);
                _emitAgentPhrase(_heldNotes, _pendingHop);
                spork ~ _idleAfter((currentScore.beats() * 60.0 / localBpm)::second);
            }
        }
    }
}
