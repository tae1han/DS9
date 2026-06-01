@import "smuck"
@import "../agent.ck"

@import "../instruments/glideBassInst.ck"

// Emu: only listens to the bottom voice of the phrase, contstructs a minimal bassline
public class Emu extends Agent
{
    1 => int minNotes;
    -12 => int transposeSemis; // octave down
    0 => int loopPlayback;
    7.0 => float gateInterval;   // interval between bottom-voice checks
    5.0 => float maxLeap;        // max semitone jump before reacquire
    4.0 => float reacquireBeats; // how long before re-locking bottom

    1 => int legatoize;
    0 => int glideMode;
    0 => int autoModeSwitch;
    5.0 => float modeSwitchMin;
    8.0 => float modeSwitchMax;
    0.45 => float glideProb;
    8 => int glideMinSpan;
    3 => int glideLocalMinSpan;
    0.5 => float glideLocalCooldownMin;
    1.0 => float glideLocalCooldownMax;
    1.0 => float glideCooldownMin;
    2.0 => float glideCooldownMax;
    10 => int glideDramMaxSpan;
    5 => int glideLocalMaxSpan;
    0.45 => float glideDramSecMin;
    0.65 => float glideDramSecMax;
    2.5 => float glideDramHoldMin;
    4.0 => float glideDramHoldMax;
    0.6 => float glideDramVel;
    0.18 => float glideLocalSecMin;
    0.32 => float glideLocalSecMax;
    1.5 => float glideLocalHoldMin;
    2.5 => float glideLocalHoldMax;
    0.4 => float glideLocalVel;
    4.0 => float glideDramResetMin;
    6.0 => float glideDramResetMax;
    time _nextGlideAllowed;
    time _nextDramaticAllowed;
    int _lastGlideTarget;
    int _glideFrom;
    int _glideTo;
    float _glideT;
    float _glideHold;
    float _glideVel;
    int _pendingHop;

    Event _playRequest;
    int _glideGen;

    fun Emu()
    {
        "Emu" => name;
        0 => cancelOnNewPhrase;
        60.0 => localBpm;
        0.2 => responseDelayMin;
        0.6 => responseDelayMax;
        spork ~ playbackWorker();
        spork ~ modeToggleWorker();
    }

    fun void stopAll()
    {
        _glideGen++;
        if(player.isPlaying()) player.stop();
        inst $ glideBassInst @=> glideBassInst gb;
        if(gb != null) gb.allOff();
    }

    fun void setParam(string param, float val)
    {
        if(param == "transposeSemis") val $ int => transposeSemis;
        else if(param == "loopPlayback") val $ int => loopPlayback;
        else if(param == "gateInterval") val => gateInterval;
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
        else if(param == "glideMode") val $ int => glideMode;
        else if(param == "autoModeSwitch") val $ int => autoModeSwitch;
        else if(param == "modeSwitchMin") val => modeSwitchMin;
        else if(param == "modeSwitchMax") val => modeSwitchMax;
        else if(param == "glideProb") val => glideProb;
        else if(param == "glideMinSpan") val $ int => glideMinSpan;
        else if(param == "glideCooldownMin") val => glideCooldownMin;
        else if(param == "glideCooldownMax") val => glideCooldownMax;
        else if(param == "glideDramMaxSpan") val $ int => glideDramMaxSpan;
        else if(param == "glideLocalMaxSpan") val $ int => glideLocalMaxSpan;
        else if(param == "glideDramResetMin") val => glideDramResetMin;
        else if(param == "glideDramResetMax") val => glideDramResetMax;
        else if(param == "enabled") { if(val > 0) enable(); else disable(); }
    }

    fun void modeToggleWorker()
    {
        while(true)
        {
            Math.random2f(modeSwitchMin, modeSwitchMax)::second => now;
            if(!autoModeSwitch || !enabled) continue;

            if(glideMode) 0 => glideMode;
            else 1 => glideMode;

            if(glideMode) _log("Emu auto -> glide");
            else _log("Emu auto -> bottom-line");
        }
    }

    fun int _clampMidi(int p)
    {
        while(p < 0) p + 12 => p;
        while(p > 127) p - 12 => p;
        return p;
    }

    fun int _phrasePitchSpan(ezNote src[])
    {
        if(src.size() == 0) return 0;
        src[0].pitch() $ int => int lo;
        src[0].pitch() $ int => int hi;
        for(1 => int i; i < src.size(); i++)
        {
            src[i].pitch() $ int => int p;
            if(p < lo) p => lo;
            if(p > hi) p => hi;
        }
        return hi - lo;
    }

    fun int _glideAllowed(int span, int dramatic)
    {
        if(dramatic)
        {
            if(span < glideMinSpan) return 0;
        }
        else
        {
            if(span < glideLocalMinSpan) return 0;
        }
        if(now < _nextGlideAllowed) return 0;
        if(glideProb < 0.999 && Math.randomf() > glideProb) return 0;
        return 1;
    }

    fun void _armGlideCooldown(int dramatic)
    {
        if(dramatic)
        {
            Math.random2f(glideCooldownMin, glideCooldownMax)::second + now => _nextGlideAllowed;
            Math.random2f(glideDramResetMin, glideDramResetMax)::second + now => _nextDramaticAllowed;
        }
        else
        {
            Math.random2f(glideLocalCooldownMin, glideLocalCooldownMax)::second + now => _nextGlideAllowed;
        }
    }

    // Sets _glideFrom/_glideTo/_glideT/_glideHold/_glideVel. Returns 1 dramatic, 0 local, -1 skip.
    fun int _planGlide(int phraseMin, int phraseMax)
    {
        _clampMidi(phraseMin + transposeSemis) => _glideTo;

        if(now >= _nextDramaticAllowed)
        {
            _clampMidi(phraseMax + transposeSemis + Math.random2(2, 5)) => int fromCandidate;
            _clampMidi(_glideTo + glideDramMaxSpan) => int fromCap;
            if(fromCandidate > fromCap) fromCap => fromCandidate;
            if(fromCandidate < _glideTo + 5) _clampMidi(_glideTo + Math.random2(5, Math.min(glideDramMaxSpan, 9))) => fromCandidate;
            fromCandidate => _glideFrom;
            Math.random2f(glideDramSecMin, glideDramSecMax) => _glideT;
            Math.random2f(glideDramHoldMin, glideDramHoldMax) => _glideHold;
            glideDramVel => _glideVel;
            return 1;
        }

        int anchor;
        if(_lastGlideTarget > 0) _lastGlideTarget => anchor;
        else _clampMidi(phraseMax + transposeSemis) => anchor;

        anchor => _glideFrom;
        if(_glideFrom < _glideTo + 2) _glideTo + Math.random2(2, glideLocalMaxSpan) => _glideFrom;
        if(_glideFrom - _glideTo > glideLocalMaxSpan) _glideTo + glideLocalMaxSpan => _glideFrom;
        if(_glideFrom - _glideTo < 2) return -1;

        Math.random2f(glideLocalSecMin, glideLocalSecMax) => _glideT;
        Math.random2f(glideLocalHoldMin, glideLocalHoldMax) => _glideHold;
        glideLocalVel => _glideVel;
        return 0;
    }

    fun int shouldActivate()
    {
        if(source == null) return 0;
        if(listenTarget != LISTEN_HUMAN) return 0;
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
        if(!enabled) return;
        if(listenTarget != LISTEN_HUMAN) return;
        _connectInst();

        if(glideMode && inst != null)
        {
            source.completedPhrase.notes() @=> ezNote src[];
            if(src.size() > 0)
            {
                src[0].pitch() $ int => int phraseMin;
                src[0].pitch() $ int => int phraseMax;
                for(1 => int i; i < src.size(); i++)
                {
                    src[i].pitch() $ int => int p;
                    if(p < phraseMin) p => phraseMin;
                    if(p > phraseMax) p => phraseMax;
                }
                _phrasePitchSpan(src) => int span;
                (now >= _nextDramaticAllowed) => int wantDramatic;
                if(_glideAllowed(span, wantDramatic))
                {
                    _planGlide(phraseMin, phraseMax) => int dramatic;
                    if(dramatic >= 0)
                    {
                        _armGlideCooldown(dramatic);
                        _glideTo => _lastGlideTarget;

                        if(dramatic) _thinking("glide bass (dramatic)");
                        else _thinking("glide bass (local)");
                        if(dramatic) _playing("Emu glide");
                        else _playing("Emu glide local");
                        _glideGen++;
                        _glideGen => int g0;
                        spork ~ _glidePlayback(g0);
                        return;
                    }
                }
            }
        }

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
        0 => _pendingHop;
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

    fun void _glidePlayback(int g0)
    {
        if(!enabled || g0 != _glideGen) return;
        _connectInst();
        inst $ glideBassInst @=> glideBassInst gb;
        if(gb == null) return;

        _playing("Emu glide");
        _notifyPulse(_glideVel);
        gb.glideDescend(_glideFrom, _glideTo, _glideT, _glideHold, _glideVel);
        if(!enabled || g0 != _glideGen) return;

        ezNote held[1];
        ezNote n(0, _glideHold, _glideTo, _glideVel);
        n @=> held[0];
        _emitAgentPhrase(held, 0);
        spork ~ _idleAfter((_glideT + _glideHold)::second);
    }

    fun void playbackWorker()
    {
        while(true)
        {
            _playRequest => now;
            _connectInst();
            if(currentScore == null || inst == null) continue;

            currentScore.parts()[0].measures()[0].notes() @=> ezNote sn[];
            _playing(playPhrase(sn));
            swapScore(currentScore);
            player.loop(loopPlayback);
            _scorePlayEndBeats(currentScore) * 60.0 / localBpm => float durSec;
            durSec::second => now;
            _emitAgentPhrase(sn, _pendingHop);
            spork ~ _idleAfter(durSec::second);
        }
    }
}
