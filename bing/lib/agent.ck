@import "smuck"
@import "bufferState.ck"
@import "SMIR.ck"

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
    0 => int _instConnected;
    0 => int _active;
    "Agent" => string name;
    0 => int verbose;

    -1 => int listenTarget;
    -1 => int mySlot;
    -1 => int LISTEN_HUMAN;
    OscOut @ _agentOut;
    OscOut @ _pulseOut;
    string _agentBusAddr;
    int _agentBusPortBase;
    int _agentBusSlots;
    int _eddiesEnabled;
    3000 => int _seedCooldownMs;
    4 => int _maxHopDepth;
    1 => int _phraseOnlyEddies;
    time _lastSeedTime;
    Event _notePlayedEvent;

    fun void bindAgentBus(OscOut @ out, int slot, string addr, int portBase, int numSlots)
    {
        out @=> _agentOut;
        slot => mySlot;
        addr => _agentBusAddr;
        portBase => _agentBusPortBase;
        numSlots => _agentBusSlots;
    }

    fun void bindPulseOut(OscOut @ out) { out @=> _pulseOut; }
    fun Event notePlayedEvent() { return _notePlayedEvent; }

    fun void _notifyPulse(float vel)
    {
        if(_pulseOut == null || mySlot < 0) return;
        _pulseOut.start("/ds9/pulse");
        mySlot => _pulseOut.add;
        vel => _pulseOut.add;
        _pulseOut.send();
    }

    fun void _emitAgentNote(ezNote n, int hopDepth)
    {
        if(hopDepth >= _maxHopDepth) return;
        _notifyPulse(n.velocity());
        _notePlayedEvent.broadcast();
        if(_agentOut == null || mySlot < 0 || _agentBusSlots <= 0) return;
        for(int p; p < _agentBusSlots; p++)
        {
            _agentOut.dest(_agentBusAddr, _agentBusPortBase + p);
            _agentOut.start("/ds9/agent/noteOn");
            mySlot => _agentOut.add;
            n.pitch() $ int => _agentOut.add;
            n.velocity() => _agentOut.add;
            n.beats() => _agentOut.add;
            hopDepth => _agentOut.add;
            _agentOut.send();
        }
    }

    fun void _emitAgentPhrase(ezNote notes[], int hopDepth)
    {
        if(hopDepth >= _maxHopDepth) return;
        if(_agentOut == null || mySlot < 0 || notes.size() == 0) return;
        32 => int nNotes;
        if(notes.size() < nNotes) notes.size() => nNotes;
        for(int p; p < _agentBusSlots; p++)
        {
            _agentOut.dest(_agentBusAddr, _agentBusPortBase + p);
            _agentOut.start("/ds9/agent/phraseComplete");
            mySlot => _agentOut.add;
            nNotes => _agentOut.add;
            hopDepth => _agentOut.add;
            for(int i; i < nNotes; i++)
            {
                notes[i].pitch() $ int => _agentOut.add;
                notes[i].velocity() => _agentOut.add;
                notes[i].beats() => _agentOut.add;
                notes[i].onset() => _agentOut.add;
            }
            _agentOut.send();
        }
    }

    fun ezNote[] _copyNotes(ezNote src[])
    {
        ezNote out[0];
        if(src == null) return out;
        for(int i; i < src.size(); i++)
        {
            ezNote n(src[i].onset(), src[i].beats(), src[i].pitch(), src[i].velocity());
            out << n;
        }
        return out;
    }

    fun void setListenTarget(int tgt)
    {
        if(tgt == mySlot && mySlot >= 0) return;
        tgt => listenTarget;
    }

    fun int acceptAgentHop(int hopDepth) { return hopDepth < _maxHopDepth; }

    fun void onAgentNote(int srcSlot, int pitch, float vel, float durBeats, int hopDepth) { }
    fun void onAgentPhrase(int srcSlot, ezNote phrase[], int hopDepth) { }

    // display: 0=idle, 1=thinking, 2=playing
    0 => int displayStatus;
    "" => string displayBody;
    "" => string _displayHeader;
    "" => string _displayDetail;

    fun void _composeDisplay()
    {
        if(_displayDetail.length() > 0)
            _displayHeader + "\n" + _displayDetail => displayBody;
        else
            _displayHeader => displayBody;
    }

    fun void _setDisplayHeader(string h)
    {
        h => _displayHeader;
        _composeDisplay();
    }

    fun void _setDisplayDetail(string d)
    {
        d => _displayDetail;
        _composeDisplay();
    }

    fun void _idle()
    {
        0 => displayStatus;
        "" => _displayHeader;
        "" => _displayDetail;
        "" => displayBody;
    }

    fun void _thinking(string h)
    {
        1 => displayStatus;
        h => _displayHeader;
        "" => _displayDetail;
        _composeDisplay();
    }

    fun void _playing(string h)
    {
        2 => displayStatus;
        h => _displayHeader;
        "" => _displayDetail;
        _composeDisplay();
    }

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

    fun void _connectInst()
    {
        if(_instConnected) return;
        if(inst == null || _masterRef == null) return;
        inst => _masterRef;
        1 => _instConnected;
    }

    fun void _disconnectInst()
    {
        if(!_instConnected) return;
        if(inst != null && _masterRef != null) inst =< _masterRef;
        0 => _instConnected;
    }

    fun void enable()
    {
        if(!enabled) 1 => enabled;
        0 => _instConnected;
        _connectInst();
        spork ~ _liveKick(0::ms);
        spork ~ _liveKick(250::ms);
        spork ~ _liveKick(600::ms);
    }

    fun void _liveKick(dur wait)
    {
        wait => now;
        if(!enabled || source == null) return;
        _connectInst();
        if(!shouldActivate()) return;
        if(source.completedPhrase.notes().size() == 0) return;
        _runPhraseComplete();
    }

    fun void masterRef(Gain @ g) { g @=> _masterRef; }

    fun void disable()
    {
        stopAll();
        if(!enabled) return;
        0 => enabled;
        _idle();
        _disconnectInst();
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
        else if(param == "listenTarget") setListenTarget(val $ int);
        else if(param == "eddiesEnabled") val $ int => _eddiesEnabled;
        else if(param == "seedCooldownMs") val $ int => _seedCooldownMs;
        else if(param == "maxHopDepth") val $ int => _maxHopDepth;
        else if(param == "phraseOnlyEddies") val $ int => _phraseOnlyEddies;
        else if(param == "verbose") val $ int => verbose;
    }

    // override these
    fun int shouldActivate() { return 1; }
    fun void onPhraseStart() { }
    fun void onPhraseComplete() { }
    fun void onNote(ezNote n) { }
    fun void onNoteOff(int pitch) { }
    fun void onSilenceSustained(float s) { }
    fun void tick() { }
    fun dur tickPeriod() { return 0::ms; }

    fun void setInstrument(ezInstrument @ i)
    {
        stopAll();
        _disconnectInst();
        i @=> inst;
        // <<< "[" + name + "] setInstrument" >>>;
        if(currentScore != null && currentScore.parts().size() > 0)
            player.instruments(0, inst);
        if(enabled) _connectInst();
    }

    fun float _scorePlayEndBeats(ezScore s)
    {
        if(s.parts().size() == 0) return s.beats();
        s.parts()[0].measures()[0].notes() @=> ezNote notes[];
        if(notes.size() == 0) return s.beats();
        0.0 => float end;
        for(int i; i < notes.size(); i++)
        {
            notes[i].onset() + notes[i].beats() => float e;
            if(e > end) e => end;
        }
        if(end > s.beats()) return end;
        return s.beats();
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
        _releaseAllInstrumentVoices();
        if(player.isPlaying()) player.stop();
        s @=> currentScore;
        if(s.parts().size() > 0 && s.parts()[0].measures().size() > 0)
        {
            s.parts()[0].measures()[0].notes() @=> ezNote playNotes[];
            SMIR.finalizePhraseDurations(playNotes, 0.12, 0.5);
        }
        player.score(s);
        if(inst != null) player.instruments(0, inst);
        if(verbose) player.logPlayback(1);
        player.startPos(0.0);
        player.endPos(_scorePlayEndBeats(s));
        player.pos(0.0);
        player.bpm(localBpm);
        player.play();
        spork ~ _scoreNotePulses(s);
        // <<< "[" + name + "] swapScore: playing" >>>;
    }

    fun void _scoreNotePulses(ezScore s)
    {
        if(s.parts().size() == 0) return;
        s.parts()[0].measures()[0].notes() @=> ezNote notes[];
        if(notes.size() == 0) return;

        60.0 / localBpm => float secPerBeat;
        for(int i; i < notes.size(); i++)
        {
            if(i > 0)
                (notes[i].onset() - notes[i-1].onset()) * secPerBeat::second => now;
            else if(notes[0].onset() > 0)
                notes[0].onset() * secPerBeat::second => now;

            _notifyPulse(notes[i].velocity());
        }
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
        _notifyPulse(n.velocity());
        _notePlayedEvent.broadcast();
        n.beats() => float b;
        if(b <= 0) 0.5 => b;
        (b * 60.0 / localBpm)::second => now;
        inst.noteOff(n, v);
        inst.release_voice(v);
    }

    fun void _releaseAllInstrumentVoices()
    {
        if(inst == null) return;
        for(0 => int v; v < inst.numVoices(); v++)
        {
            ezNote off(0, 0.01, 60, 0);
            inst.noteOff(off, v);
            inst.release_voice(v);
        }
    }

    fun void stopAll()
    {
        _releaseAllInstrumentVoices();
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
    fun void _runNoteOff(int pitch) { onNoteOff(pitch); }
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

    fun void _midiListener()
    {
        int on[1];
        int pitch[1];
        float vel[1];

        while(true)
        {
            source.midiQueueEvent => now;
            if(!enabled) continue;
            while(source.mqPop(on, pitch, vel))
            {
                if(!enabled) break;
                if(on[0])
                {
                    ezNote n(0, 0, pitch[0], vel[0]);
                    if(shouldActivate()) spork ~ _runNote(n);
                }
                else if(shouldActivate())
                {
                    spork ~ _runNoteOff(pitch[0]);
                }
            }
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
        spork ~ _silenceListener();
        spork ~ _tickLoop();
        // <<< "[" + name + "] running" >>>;
    }
}
