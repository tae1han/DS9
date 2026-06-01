@import "smuck"
@import "bufferState.ck"

public class Agent
{
    ezInstrument @ inst;
    bufferState @ source;
    Gain @ _masterRef;

    ezScorePlayer player;
    ezScore currentScore;
    60.0 => float localBpm;

    0.0 => float responseDelayMin;
    0.0 => float responseDelayMax;
    0 => int cancelOnNewPhrase;

    1 => int enabled;
    0 => int _active;
    "Agent" => string name;
    0 => int verbose;

    // display: 0=idle, 1=thinking, 2=playing
    0 => int displayStatus;
    "" => string displayBody;

    fun void _idle() { 0 => displayStatus; "" => displayBody; }
    fun void _thinking(string s) { 1 => displayStatus; s => displayBody; }
    fun void _playing(string s) { 2 => displayStatus; s => displayBody; }

    fun void _idleAfter(dur d)
    {
        d => now;
        if(displayStatus == 2) _idle();
    }

    fun string _notesToStr(ezNote notes[])
    {
        if(notes.size() == 0) return "";
        "" => string s;
        notes.size() => int n;
        if(n > 6) 6 => n; // cap for display
        for(int i; i < n; i++)
        {
            if(i > 0) s + " " => s;
            s + Smuck.mid2str(notes[i].pitch() $ int) => s;
        }
        if(notes.size() > 6) s + " ..." => s;
        return s;
    }

    fun void _log(string msg)
    {
        if(!verbose) return;
        <<< "[" + name + "]", msg >>>;
    }

    fun void enable()
    {
        if(enabled) return;
        1 => enabled;
        if(inst != null && _masterRef != null) inst => _masterRef;
    }

    fun void disable()
    {
        if(!enabled) return;
        0 => enabled;
        stopAll();
        _idle();
        if(inst != null && _masterRef != null) inst =< _masterRef;
    }

    fun void setParam(string param, float val)
    {
        if(param == "enabled")
        {
            if(val > 0) enable();
            else disable();
        }
        else if(param == "delayMin") val => responseDelayMin;
        else if(param == "delayMax") val => responseDelayMax;
    }

    // override these
    fun int shouldActivate() { return 1; }
    fun void onPhraseStart() { }
    fun void onPhraseComplete() { }
    fun void onNote(ezNote n) { }
    fun void onSilenceSustained(float s) { }
    fun void tick() { }
    fun dur tickPeriod() { return 0::ms; }

    fun void setInstrument(ezInstrument @ i)
    {
        stopAll();
        i @=> inst;
        // <<< "[" + name + "] setInstrument" >>>;
        if(currentScore != null && currentScore.parts().size() > 0)
            player.instruments(0, inst);
    }

    fun void swapScore(ezScore s)
    {
        if(s == null) { _log("swapScore: null score"); return; }
        if(s.parts().size() == 0) { _log("swapScore: no parts"); return; }

        if(verbose)
        {
            <<< "[" + name + "] swapScore: parts=" + s.parts().size()
                + " measures=" + s.parts()[0].measures().size()
                + " beats=" + s.beats() + " bpm=" + s.bpm() >>>;
            s.parts()[0].measures()[0].print();
        }

        // IMPORTANT: must stop before reassigning score, otherwise player
        // can try to read the old score mid-playback
        if(player.isPlaying()) player.stop();
        s @=> currentScore;
        player.score(s);
        if(inst != null) player.instruments(0, inst);
        if(verbose) player.logPlayback(1);
        player.startPos(0.0);
        player.endPos(s.beats());
        player.pos(0.0);
        player.bpm(localBpm);
        player.play();
        // <<< "[" + name + "] swapScore: playing" >>>;
    }

    // NOTE: must copy the note before sporking, otherwise the caller's
    // reference can mutate before _playDirectShred reads it
    fun void playDirect(ezNote n)
    {
        ezNote copy(n.onset(), n.beats(), n.pitch(), n.velocity());
        spork ~ _playDirectShred(copy);
    }

    fun void _playDirectShred(ezNote n)
    {
        if(inst == null) return;
        inst.allocate_voice(n) => int v;
        if(v < 0) return;
        inst.noteOn(n, v);
        // <<< "[playDirect] noteOn", n.pitch(), "voice", v >>>;
        n.beats() => float b;
        if(b <= 0) 0.5 => b; // fallback so it's not instant
        b::second => now;
        inst.noteOff(n, v);
        inst.release_voice(v);
    }

    fun void stopAll()
    {
        if(player.isPlaying()) player.stop();
    }

    fun void _applyDelay()
    {
        if(responseDelayMax <= 0) return;
        responseDelayMin => float lo;
        responseDelayMax => float hi;
        if(lo > hi) hi => lo; // swap if backwards
        Math.random2f(lo, hi) => float d;
        // <<< "[" + name + "] delay", d, "s" >>>;
        if(d > 0) d::second => now;
    }

    // NOTE: these wrappers get sporked so the delay doesn't block the listener
    fun void _runPhraseStart() { _applyDelay(); onPhraseStart(); }
    fun void _runPhraseComplete() { _applyDelay(); onPhraseComplete(); }
    fun void _runNote(ezNote n) { _applyDelay(); onNote(n); }
    fun void _runSilence(float s) { _applyDelay(); onSilenceSustained(s); }

    fun void _phraseStartListener()
    {
        while(true)
        {
            source.phraseStartEvent => now;
            if(!enabled) continue;
            if(cancelOnNewPhrase) stopAll();
            if(shouldActivate()) spork ~ _runPhraseStart();
        }
    }

    fun void _phraseCompleteListener()
    {
        while(true)
        {
            source.phraseCompleteEvent => now;
            if(!enabled) continue;
            if(shouldActivate()) spork ~ _runPhraseComplete();
        }
    }

    fun void _noteListener()
    {
        while(true)
        {
            source.noteReceivedEvent => now;
            if(!enabled) continue;
            source._lastNote @=> ezNote n;
            if(shouldActivate()) spork ~ _runNote(n);
        }
    }

    fun void _silenceListener()
    {
        while(true)
        {
            source.silenceSustainedEvent => now;
            if(!enabled) continue;
            source.silenceSeconds() => float s;
            if(shouldActivate()) spork ~ _runSilence(s);
        }
    }

    fun void _tickLoop()
    {
        while(true)
        {
            tickPeriod() => dur p;
            if(p <= 0::ms) { 100::ms => now; continue; }
            p => now;
            if(enabled && shouldActivate()) tick();
        }
    }

    // spork this once per Agent after setting source and inst
    fun void run()
    {
        if(source == null)
        {
            <<< "Agent", name, ": no bufferState set" >>>;
            return;
        }
        spork ~ _phraseStartListener();
        spork ~ _phraseCompleteListener();
        spork ~ _noteListener();
        spork ~ _silenceListener();
        spork ~ _tickLoop();
        // <<< "[" + name + "] running" >>>;
    }
}
