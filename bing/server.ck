@import "config.ck"
@import "SMIR.ck"
@import "reservedMidi.ck"
@import {"smuck", "smuck/ezFluidInst.ck"}
@import "instruments/slorkPianoMonitorInst.ck"
@import {"bufferState.ck"}
@import {"conductor.ck"}
@import {"conductorScenes.ck"}
@import {"score/movements.ck"}

8 => int NUM_AGENT_SLOTS;

"USB Midi Cable" => string MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.25 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

"224.0.0.1" => string MULTICAST_ADDR;
9000 => int CLIENT_OSC_PORT;
8889 => int SERVER_STATUS_PORT;
8891 => int SERVER_PULSE_PORT;
8892 => int SERVER_LINK_PORT;
8893 => int SERVER_LINK_REPLY_PORT;
9100 => int CLIENT_CONTROL_PORT_BASE;

me.dir() + "data/TimGM6mb.sf2" => string MONITOR_SF2;

0 => int AUTO_SCORE;
0 => int MIDI_LOG;
0 => int MONITOR_TRACE;
0 => int SOLO_MONITOR;
0 => int SIM_MONITOR;
0 => int FIRST_NOTE_MUTE;
0 => int _firstNoteMuted;
0 => int _ensembleMuted;

5 => int OWL_SLOT_B;
7 => int OWL_SLOT_A;
0 => int _owlToggleIsSeed;
1 => int MOVEMENTS_VIA_STUDIO;
for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "cues" || a == "score") 1 => AUTO_SCORE;
    else if(a == "sim") 1 => SIM_MONITOR;
    else if(a == "pad" || a == "firstNoteMute") 1 => FIRST_NOTE_MUTE;
    else if(a == "midiLog") 1 => MIDI_LOG;
    else if(a == "monitorTrace") 1 => MONITOR_TRACE;
    else if(a == "solo") 1 => SOLO_MONITOR;
    else if(a == "serverMovements") 0 => MOVEMENTS_VIA_STUDIO;
    else a => MIDI_DEVICE;
}

bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);
if(MIDI_LOG) bs.rawMidiLog(1);

OscOut xmit;
OscOut controlOut;

fun int _isControlMidi(int pitch)
{
    return ReservedMidi.isControl(pitch);
}

fun void _oscForwardNoteOn(int pitch, float vel)
{
    if(_ensembleMuted || _isControlMidi(pitch)) return;
    for(int slot; slot < NUM_AGENT_SLOTS; slot++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
        xmit.start("/ds9/noteOn");
        pitch => xmit.add;
        vel => xmit.add;
        xmit.send();
    }
}

fun void _oscForwardNoteOff(int pitch)
{
    if(_ensembleMuted || _isControlMidi(pitch)) return;
    for(int slot; slot < NUM_AGENT_SLOTS; slot++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
        xmit.start("/ds9/noteOff");
        pitch => xmit.add;
        xmit.send();
    }
}

fun void _forwardPhraseStart()
{
    while(true)
    {
        bs.phraseStartEvent => now;
        if(_ensembleMuted) continue;
        for(int slot; slot < NUM_AGENT_SLOTS; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/phraseStart");
            xmit.send();
        }
    }
}

fun void _forwardPhraseComplete()
{
    while(true)
    {
        bs.phraseCompleteEvent => now;
        if(_ensembleMuted) continue;
        for(int slot; slot < NUM_AGENT_SLOTS; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/phraseComplete");
            xmit.send();
        }
    }
}

fun void _forwardSilence()
{
    while(true)
    {
        bs.silenceSustainedEvent => now;
        if(_ensembleMuted) continue;
        for(int slot; slot < NUM_AGENT_SLOTS; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/silenceSustained");
            bs.silenceSeconds() => xmit.add;
            xmit.send();
        }
    }
}

Gain master => LPF lpf => Dyno comp => NRev rev;
if(SIM_MONITOR) master.gain(0.45);
else master.gain(0.8);
lpf.freq(7000);
comp.limit();
rev.mix(0.05);
for(0 => int i; i < dac.channels(); i++)
    rev => dac.chan(i);

// TimGM piano monitor. Control MIDI 28–35: separate path + instrument filter.
SlorkPianoMonitorInst @ monitorInst;
int _monVoice[128];
0 => int _monitorReady;

fun void _initMonitor()
{
    if(_monitorReady || !MONITOR_USER_INPUT) return;

    FileIO f;
    if(!f.open(MONITOR_SF2, FileIO.READ))
    {
        <<< "bing monitor: soundfont not found:", MONITOR_SF2 >>>;
        me.exit();
    }
    f.close();

    new SlorkPianoMonitorInst(MONITOR_SF2, 0) @=> monitorInst;
    monitorInst.numVoices(128);
    if(SIM_MONITOR) monitorInst.gain(4.5);
    else monitorInst.gain(10);
    monitorInst => master;

    for(0 => int p; p < 128; p++) -1 => _monVoice[p];
    1 => _monitorReady;
    <<< "bing server build: reserved-midi-v5 | monitor ready | MIDI 28-35 SILENT" >>>;
}

fun void _monitorSilencePitch(int pitch)
{
    if(!_monitorReady || monitorInst == null) return;
    if(pitch < 0 || pitch > 127) return;
    monitorInst.silencePitch(pitch);
    if(_monVoice[pitch] >= 0)
    {
        ezNote n;
        n.pitch(pitch);
        monitorInst.noteOff(n, _monVoice[pitch]);
        monitorInst.release_voice(_monVoice[pitch]);
        -1 => _monVoice[pitch];
    }
}

fun void _monitorMidi(int on, int pitch, float vel)
{
    if(_isControlMidi(pitch)) return;
    if(!MONITOR_USER_INPUT || !_monitorReady || monitorInst == null) return;
    if(pitch < 0 || pitch > 127) return;

    ezNote n;
    n.pitch(pitch);
    n.velocity(vel);

    if(on)
    {
        if(_monVoice[pitch] >= 0)
            _monitorMidi(0, pitch, vel);
        monitorInst.allocate_voice(n) => int v;
        if(v < 0) return;
        v => _monVoice[pitch];
        if(MONITOR_TRACE)
            <<< "TRACE MONITOR_PLAY pitch", pitch, "vel", vel >>>;
        monitorInst.noteOn(n, v);
    }
    else
    {
        if(_monVoice[pitch] < 0) return;
        monitorInst.noteOff(n, _monVoice[pitch]);
        monitorInst.release_voice(_monVoice[pitch]);
        -1 => _monVoice[pitch];
    }
}

_initMonitor();

fun void _resumeClientMidi()
{
    0 => _ensembleMuted;
    conductor.sendMidiForward(1);
}

fun void _applyFirstNoteMute()
{
    if(_firstNoteMuted) return;
    1 => _firstNoteMuted;
    1 => _ensembleMuted;
    bs.clearHumanBuffers();
    conductor.sendFeederPause(1);
    conductor.sendMidiForward(0);
    for(int i; i < NUM_AGENT_SLOTS; i++)
    {
        conductor.sendPanic(i);
        conductor.sendActivate(i, 0);
        conductor.sendParam(i, "clearMemory", 1);
    }
    scenes.endChaosOwls(OWL_SLOT_A, OWL_SLOT_B);
    conductor.sendSceneAbort();
    <<< ">>> first MIDI — muted, feeder paused, all agents off, phrase memory cleared" >>>;
    <<< ">>> play solo on monitor; MIDI 29–35 = movements 2–8" >>>;
}

fun void _runMovementLocal(int mov)
{
    if(mov == 2) scenes.applyMovement2(OWL_SLOT_A, OWL_SLOT_B);
    else if(mov == 3) scenes.applyMovement3(OWL_SLOT_A, OWL_SLOT_B, 0, 4, 1, 3);
    else if(mov == 4) scenes.applyMovement4(6, 0, 2, 4);
    else if(mov == 5) scenes.applyMovement5();
    else if(mov == 6) scenes.applyMovement6();
    else if(mov == 7) scenes.applyMovement7();
    else if(mov == 8) scenes.applyMovement8();
}

fun void _runMovement(int pitch)
{
    if(pitch < 29 || pitch > 35) return;
    pitch - 27 => int mov;
    if(mov < 2 || mov > 8) return;
    _resumeClientMidi();
    conductor.sendSceneAbort();
    if(MOVEMENTS_VIA_STUDIO)
    {
        <<< "MIDI movement trigger: key", pitch, "→ movement", mov, "(studio)" >>>;
        conductor.sendRunMovement(mov);
    }
    else
    {
        <<< "MIDI movement trigger: key", pitch, "→ movement", mov, "(server)" >>>;
        _runMovementLocal(mov);
    }
}

fun void _runFirstNoteMute(int pitch, float vel)
{
    _applyFirstNoteMute();
    _monitorMidi(1, pitch, vel);
}

fun void _controlMidiLoop()
{
    while(true)
    {
        bs.controlMidiEvent => now;
        bs.ctlOn => int on;
        bs.ctlPitch => int pitch;
        bs.ctlVel => float vel;

        if(MIDI_LOG)
        {
            if(on) <<< "CONTROL (no piano)", pitch, vel >>>;
            else <<< "CONTROL off", pitch >>>;
        }

        if(on)
            _monitorSilencePitch(pitch);

        if(MONITOR_TRACE)
            <<< "TRACE CONTROL pitch", pitch,
                on ? "on" : "off", "(no monitor noteOn)" >>>;

        if(pitch == 28 && on)
            spork ~ _toggleOwlSlotsMode();
        else if(on)
            _runMovement(pitch);
    }
}

fun void _midiDispatch()
{
    int on[1];
    int pitch[1];
    float vel[1];

    while(true)
    {
        bs.midiQueueEvent => now;
        while(bs.mqPop(on, pitch, vel))
        {
            if(_isControlMidi(pitch[0]))
            {
                if(MIDI_LOG)
                    <<< "WARN: control pitch", pitch[0], "in musical queue (ignored)" >>>;
                continue;
            }

            if(MIDI_LOG)
            {
                if(on[0]) <<< "MONITOR", pitch[0], vel[0] >>>;
                else <<< "MONITOR off", pitch[0] >>>;
            }

            if(FIRST_NOTE_MUTE && !_firstNoteMuted && on[0])
            {
                spork ~ _runFirstNoteMute(pitch[0], vel[0]);
                continue;
            }

            if(on[0])
            {
                _monitorMidi(1, pitch[0], vel[0]);
                if(!_ensembleMuted)
                    _oscForwardNoteOn(pitch[0], vel[0]);
            }
            else
            {
                _monitorMidi(0, pitch[0], 0.0);
                if(!_ensembleMuted)
                    _oscForwardNoteOff(pitch[0]);
            }
        }
    }
}

<<< "bing server dir:", me.dir() >>>;
<<< "v10 server OSC:", MULTICAST_ADDR, "slots:", NUM_AGENT_SLOTS >>>;

fun void _toggleOwlSlotsMode()
{
    if(_owlToggleIsSeed) 0 => _owlToggleIsSeed;
    else 1 => _owlToggleIsSeed;

    scenes.sendOwlToggleMode(_owlToggleIsSeed, OWL_SLOT_A, -1);
    if(_owlToggleIsSeed)
        <<< "owl toggle: slot", OWL_SLOT_A, "→ SEED" >>>;
    else
        <<< "owl toggle: slot", OWL_SLOT_A, "→ DEVELOP" >>>;
}

fun void _serverLinkHeartbeat()
{
    while(true)
    {
        250::ms => now;
        xmit.dest(MULTICAST_ADDR, SERVER_LINK_PORT);
        xmit.start("/ds9/link/ping");
        xmit.send();
    }
}

fun void _serverLinkListen()
{
    OscIn linkIn;
    OscMsg linkMsg;
    linkIn.port(SERVER_LINK_REPLY_PORT);
    linkIn.addAddress("/ds9/link/pong");

    while(true)
    {
        linkIn => now;
        while(linkIn.recv(linkMsg))
            linkMsg.getInt(0) => int slot; // slot ack (optional log)
    }
}

9113 => int SERVER_CTL_PORT;

fun void _serverCtlListen()
{
    OscIn serverCtl;
    OscMsg serverCtlMsg;
    serverCtl.port(SERVER_CTL_PORT);
    serverCtl.addAddress("/ds9/control/midiForward");

    while(true)
    {
        serverCtl => now;
        while(serverCtl.recv(serverCtlMsg))
        {
            if(serverCtlMsg.getInt(0) > 0)
                0 => _ensembleMuted;
            else
                1 => _ensembleMuted;
        }
    }
}

Conductor conductor(controlOut, MULTICAST_ADDR, NUM_AGENT_SLOTS);
ConductorScenes scenes(conductor, NUM_AGENT_SLOTS);

spork ~ bs.listen();
spork ~ bs.silenceWatcher();
spork ~ bs.rollingReaper();
spork ~ _forwardPhraseStart();
spork ~ _forwardPhraseComplete();
spork ~ _forwardSilence();
spork ~ _controlMidiLoop();
spork ~ _midiDispatch();

if(!SOLO_MONITOR)
{
    spork ~ _serverCtlListen();
    spork ~ _serverLinkHeartbeat();
    spork ~ _serverLinkListen();
}

// Clients start inactive; in sim/studio skip this — it races the ChuGL conductor.
if(!SIM_MONITOR)
{
    for(int i; i < NUM_AGENT_SLOTS; i++)
        conductor.sendActivate(i, 0);
}

ScoreMovements score(conductor, NUM_AGENT_SLOTS);

fun void _scoreEntry()
{
    bs.noteReceivedEvent => now;
    <<< "v10: starting score timeline" >>>;
    score.runTimeline();
}

if(AUTO_SCORE)
    spork ~ _scoreEntry();
else if(SOLO_MONITOR)
{
    <<< "bing SOLO — piano monitor only (no OSC listeners)" >>>;
    if(MONITOR_TRACE)
        <<< "  press 28-35: TRACE CONTROL | other keys: TRACE MONITOR_PLAY" >>>;
}
else
{
    if(FIRST_NOTE_MUTE)
        <<< "v10 server — :pad: first MIDI = mute, deactivate, clear owl memory" >>>;
    else
        <<< "v10 server — pass :score or :pad" >>>;
    if(MOVEMENTS_VIA_STUDIO)
        <<< "bing server — MIDI 28 owl | 29-35 → studio (need studioConductor)" >>>;
    else
        <<< "bing server — MIDI 28 owl | 29-35 movements on server (:serverMovements)" >>>;
    <<< "v10 server — link ping port", SERVER_LINK_PORT, "pong", SERVER_LINK_REPLY_PORT >>>;
}

while(true) 50::ms => now;
