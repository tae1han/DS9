@import "config.ck"
@import "SMIR.ck"
@import {"smuck", "smuck/ezFluidInst.ck"}
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
0 => int MONITOR_DEBUG;
0 => int MIDI_LOG;
0 => int SIM_MONITOR;
0 => int FIRST_NOTE_MUTE;
0 => int _firstNoteMuted;
0 => int _ensembleMuted;

5 => int OWL_SLOT_B;
7 => int OWL_SLOT_A;
0 => int _owlToggleIsSeed;
for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "cues" || a == "score") 1 => AUTO_SCORE;
    else if(a == "sim") 1 => SIM_MONITOR;
    else if(a == "pad" || a == "firstNoteMute") 1 => FIRST_NOTE_MUTE;
    else if(a == "monitorDebug") 1 => MONITOR_DEBUG;
    else if(a == "midiLog") 1 => MIDI_LOG;
    else a => MIDI_DEVICE;
}

bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);

OscOut xmit;
OscOut controlOut;

fun void _oscForwardNoteOn(int pitch, float vel)
{
    if(_ensembleMuted || _midiSuppressMonitor(pitch)) return;
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
    if(_ensembleMuted || _midiSuppressMonitor(pitch)) return;
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

int _monVoice[128];
ezFluidInst @ monitorInst;
0 => int _monitorReady;
0 => int _dacWired;

fun void _wireDac()
{
    if(_dacWired) return;
    for(int i; i < dac.channels(); i++)
        rev => dac.chan(i);
    1 => _dacWired;
}

fun void _initMonitor()
{
    if(_monitorReady || !MONITOR_USER_INPUT) return;

    FileIO f;
    if(!f.open(MONITOR_SF2, FileIO.READ))
    {
        <<< "v10 monitor: soundfont not found:", MONITOR_SF2 >>>;
        me.exit();
    }
    f.close();

    new ezFluidInst(MONITOR_SF2, 0) @=> monitorInst;
    monitorInst.numVoices(128);
    if(SIM_MONITOR) monitorInst.gain(4.5);
    else monitorInst.gain(10);
    monitorInst => master;
    for(0 => int p; p < 128; p++) -1 => _monVoice[p];
    1 => _monitorReady;
    <<< "v10 monitor: TimGM piano:", MONITOR_SF2 >>>;
}

fun int _midiSuppressMonitor(int pitch)
{
    return SMIR.skipForPitchSet(pitch);
}

fun void _logMidi(int on, int pitch, float vel)
{
    if(!MIDI_LOG && !MONITOR_DEBUG) return;
    if(on)
        <<< "MIDI in: noteOn pitch", pitch, "vel", vel,
            "(owlToggle:", SMIR.isOwlToggleMidi(pitch), "movement:",
            SMIR.movementFromMidi(pitch), ")" >>>;
    else
        <<< "MIDI in: noteOff pitch", pitch >>>;
}

fun void _monitorNoteOff(int pitch)
{
    if(!_monitorReady || monitorInst == null) return;
    if(pitch < 0 || pitch > 127) return;
    if(_midiSuppressMonitor(pitch)) return;
    ezNote n;
    n.pitch(pitch);
    n.velocity(0.5);
    if(_monVoice[pitch] >= 0)
    {
        monitorInst.noteOff(n, _monVoice[pitch]);
        monitorInst.release_voice(_monVoice[pitch]);
        -1 => _monVoice[pitch];
    }
}

fun void _monitorNoteOn(int pitch, float vel)
{
    if(!MONITOR_USER_INPUT || !_monitorReady) return;
    if(pitch < 0 || pitch > 127) return;
    if(_midiSuppressMonitor(pitch)) return;

    ezNote n;
    n.pitch(pitch);
    n.velocity(vel);

    if(_monVoice[pitch] >= 0)
        _monitorNoteOff(pitch);

    monitorInst.allocate_voice(n) => int v;
    if(v < 0)
    {
        for(0 => int p; p < 128; p++)
        {
            if(_monVoice[p] >= 0)
            {
                _monitorNoteOff(p);
                break;
            }
        }
        monitorInst.allocate_voice(n) => v;
    }
    if(v < 0)
    {
        if(MONITOR_DEBUG) <<< "monitor noteOn dropped (no voice)", pitch >>>;
        return;
    }
    v => _monVoice[pitch];
    monitorInst.noteOn(n, v);
    if(MONITOR_DEBUG || MIDI_LOG)
        <<< "MONITOR noteOn pitch", pitch, "vel", vel >>>;
    if(pitch == 28)
        <<< "WARNING: monitor played pitch 28 — should be suppressed" >>>;
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
    <<< ">>> first MIDI — muted, feeder paused, all agents off, phrase memory cleared" >>>;
    <<< ">>> play solo on monitor; MIDI 29–35 = movements 2–8" >>>;
}

fun void _triggerMovementFromMidi(int pitch)
{
    SMIR.movementFromMidi(pitch) => int mov;
    if(mov < 2 || mov > 8) return;
    <<< "MIDI movement trigger: key", pitch, "→ movement", mov >>>;
    if(mov == 2) scenes.applyMovement2(OWL_SLOT_A, OWL_SLOT_B);
    else if(mov == 3) scenes.applyMovement3(OWL_SLOT_A, OWL_SLOT_B, 0, 4, 1, 3);
    else if(mov == 4) scenes.applyMovement4(6, 0, 2, 4);
    else if(mov == 5) scenes.applyMovement5();
    else if(mov == 6) scenes.applyMovement6();
    else if(mov == 7) scenes.applyMovement7();
    else if(mov == 8) scenes.applyMovement8();
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
            _logMidi(on[0], pitch[0], vel[0]);

            if(SMIR.isOwlToggleMidi(pitch[0]))
            {
                if(on[0])
                {
                    _monitorNoteOff(pitch[0]);
                    _toggleOwlSlotsMode();
                }
                else _monitorNoteOff(pitch[0]);
                continue;
            }

            if(SMIR.isMovementMidi(pitch[0]))
            {
                if(on[0]) _triggerMovementFromMidi(pitch[0]);
                _monitorNoteOff(pitch[0]);
                continue;
            }

            if(FIRST_NOTE_MUTE && !_firstNoteMuted && on[0])
            {
                _applyFirstNoteMute();
                _monitorNoteOn(pitch[0], vel[0]);
                continue;
            }

            if(_ensembleMuted)
            {
                if(on[0]) _monitorNoteOn(pitch[0], vel[0]);
                else _monitorNoteOff(pitch[0]);
                continue;
            }

            if(on[0])
            {
                _monitorNoteOn(pitch[0], vel[0]);
                _oscForwardNoteOn(pitch[0], vel[0]);
            }
            else
            {
                _monitorNoteOff(pitch[0]);
                _oscForwardNoteOff(pitch[0]);
            }
        }
    }
}

spork ~ bs.listen();
spork ~ bs.silenceWatcher();
spork ~ bs.rollingReaper();

spork ~ _forwardPhraseStart();
spork ~ _forwardPhraseComplete();
spork ~ _forwardSilence();

<<< "v10 server OSC:", MULTICAST_ADDR, "slots:", NUM_AGENT_SLOTS >>>;

_initMonitor();
_wireDac();

Conductor conductor(controlOut, MULTICAST_ADDR, NUM_AGENT_SLOTS);
ConductorScenes scenes(conductor, NUM_AGENT_SLOTS);

fun void _toggleOwlSlotsMode()
{
    if(_owlToggleIsSeed) 0 => _owlToggleIsSeed;
    else 1 => _owlToggleIsSeed;

    _owlToggleIsSeed $ float => float mode;
    conductor.sendParam(OWL_SLOT_A, "owlMode", mode);
    conductor.sendParam(OWL_SLOT_B, "owlMode", mode);
    if(_owlToggleIsSeed)
        <<< "MIDI 28: Owls slots", OWL_SLOT_A, OWL_SLOT_B, "→ SEED" >>>;
    else
        <<< "MIDI 28: Owls slots", OWL_SLOT_A, OWL_SLOT_B, "→ DEVELOP" >>>;
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
OscIn serverCtl;
OscMsg serverCtlMsg;
serverCtl.port(SERVER_CTL_PORT);
serverCtl.addAddress("/ds9/control/midiForward");

fun void _serverCtlListen()
{
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

spork ~ _serverCtlListen();
spork ~ _serverLinkHeartbeat();
spork ~ _serverLinkListen();
spork ~ _midiDispatch();

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
else
{
    if(FIRST_NOTE_MUTE)
        <<< "v10 server — :pad: first MIDI = mute, deactivate, clear owl memory" >>>;
    else
        <<< "v10 server — pass :score or :pad" >>>;
    <<< "v10 server — MIDI 28 owl toggle | 29–35 movements 2–8 | :midiLog for pitch debug" >>>;
    <<< "v10 server — link ping port", SERVER_LINK_PORT, "pong", SERVER_LINK_REPLY_PORT >>>;
}

while(true) 50::ms => now;
