@import "smuck"
@import "../agent.ck"

// Parakeet: harmonize incoming notes in real-time

public class Parakeet extends Agent
{
    int intervals[0];
    0.25 => float activationProb;
    1.0 => float windowDurMin;
    5.0 => float windowDurMax;
    3.0 => float silenceMin;
    8.0 => float silenceMax;
    0.8 => float harmonyVelScale;
    1.0 => float harmonyBeats;
    0.15 => float minInputVel;

    0.2 => float doubleVoiceProb; // chance of adding a second harmony

    // window = time period wto harmonize incoming notes
    0 => int _windowOpen;
    time _activeUntil;
    time _nextTryTime;
    0 => int _currentInterval;
    0 => int _secondInterval;

    fun Parakeet()
    {
        "Parakeet" => name;
        0 => cancelOnNewPhrase;
        intervals << 3;
        intervals << 4;
        intervals << 5;
        intervals << 7;
        intervals << 9;
        0.0 => responseDelayMin;
        0.0 => responseDelayMax;
    }

    fun void setIntervals(int xs[])
    {
        intervals.clear();
        for(int i; i < xs.size(); i++) intervals << xs[i];
    }

    fun int shouldActivate()
    {
        if(source == null || inst == null) return 0;
        return 1;
    }

    fun string playPhrase(int interval)
    {
        string options[0];
        options << "harmonizing +" + interval + " semitones";
        options << "me too!";
        options << "trying to fit the harmony with +" + interval + " semitones";
        options << "I'm playing harmony on top!";

        return options[Math.random2(0, options.size() - 1)];
    }
    fun string playPhrase(int interval1, int interval2)
    {
        string options[0];
        options << "harmonizing +" + interval1 + " & +" + interval2 + " semitones";
        options << "I'm trying two harmony parts!";
        options << "trying to fit the harmony with +" + interval1 + " & +" + interval2 + " semitones";
        options << "I'm playing TWO harmonies on top!";
        options << "the more the merrier";

        return options[Math.random2(0, options.size() - 1)];
    }
    fun string playPhrase(string heard, string harmony)
    {
        string options[0];
        options << "I heard your " + heard + " and raise you a " + harmony;
        options << "harmonizing your " + heard + " with a " + harmony;
        options << "adding harmony " + harmony;
        options << heard + " + " + harmony + "... WOW";

        return options[Math.random2(0, options.size() - 1)];
    }
    fun void onNote(ezNote incoming)
    {
        if(incoming == null) return;
        if(incoming.velocity() < minInputVel) return;
        if(intervals.size() == 0) return;

        // Window just expired — enter silence
        if(_windowOpen && now >= _activeUntil)
        {
            0 => _windowOpen;
            now + Math.random2f(silenceMin, silenceMax)::second => _nextTryTime;
            _log("window closed, silent for " + ((_nextTryTime - now) / second) + "s");
            _idle();
            return;
        }

        // Still in silence cooldown
        if(!_windowOpen && now < _nextTryTime) return;

        // Cooldown over, roll dice to open a new window
        if(!_windowOpen)
        {
            if(Math.randomf() > activationProb) return;

            Math.random2(0, intervals.size() - 1) => int idx;
            intervals[idx] => _currentInterval;

            // Maybe pick a second voice with a different interval
            -1 => _secondInterval;
            if(intervals.size() > 1 && Math.randomf() < doubleVoiceProb)
            {
                int idx2;
                do { Math.random2(0, intervals.size() - 1) => idx2; }
                while(idx2 == idx);
                intervals[idx2] => _secondInterval;
            }

            now + Math.random2f(windowDurMin, windowDurMax)::second => _activeUntil;
            1 => _windowOpen;
            if(_secondInterval >= 0)
            {
                _log("window open, intervals=" + _currentInterval + "," + _secondInterval);
                _playing(playPhrase(_currentInterval, _secondInterval));
            }
            else
            {
                _log("window open, interval=" + _currentInterval);
                _playing(playPhrase(_currentInterval));
            }
        }

        incoming.pitch() $ int => int p;

        // build pitch mask from what's been played recently
        source.rollingSmir.pitchNormSet() @=> float w[];
        int mask[12];
        for(int i; i < 12; i++)
        {
            if(w[i] > 0) 1 => mask[i];
        }

        incoming.velocity() * harmonyVelScale => float v;
        if(v > 1.0) 1.0 => v;

        // Build harmony notes
        p + _currentInterval => int raw;
        if(raw < 0 || raw > 127) return;
        source.rollingSmir.quantizeToMask(raw, mask) => int q;
        ezNote harmony(0.0, harmonyBeats, q, v);

        ezNote harmony2;
        0 => int hasSecond;
        if(_secondInterval >= 0)
        {
            p + _secondInterval => int raw2;
            if(raw2 >= 0 && raw2 <= 127)
            {
                source.rollingSmir.quantizeToMask(raw2, mask) => int q2;
                ezNote h2(0.0, harmonyBeats, q2, v);
                h2 @=> harmony2;
                1 => hasSecond;
            }
        }

        _log("in=" + p + " +" + _currentInterval + " ~> " + q + " vel=" + v);
        Smuck.mid2str(p) => string heardStr;
        Smuck.mid2str(q) => string harmonyStr;
        _playing(playPhrase(heardStr, harmonyStr));

        // noteOn both voices
        inst.noteOn(harmony, 0);
        if(hasSecond) inst.noteOn(harmony2, 1);

        harmonyBeats::second => now;

        // noteOff both voices
        inst.noteOff(harmony, 0);
        if(hasSecond) inst.noteOff(harmony2, 1);
    }
}
