@import "ds10Config.ck"
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
9100 => int CLIENT_CONTROL_PORT_BASE;

me.dir() + "data/TimGM6mb.sf2" => string MONITOR_SF2;

0 => int AUTO_SCORE;
0 => int MONITOR_DEBUG;
0 => int SIM_MONITOR;
0 => int FIRST_NOTE_MUTE;
0 => int _firstNoteMuted;
0 => int _ensembleMuted;
for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "cues" || a == "score") 1 => AUTO_SCORE;
    else if(a == "sim") 1 => SIM_MONITOR;
    else if(a == "pad" || a == "firstNoteMute") 1 => FIRST_NOTE_MUTE;
    else if(a == "monitorDebug") 1 => MONITOR_DEBUG;
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
    if(_ensembleMuted) return;
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
    if(_ensembleMuted) return;
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

fun void _monitorNoteOff(int pitch)
{
    if(!_monitorReady || monitorInst == null) return;
    if(pitch < 0 || pitch > 127) return;
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
    if(MONITOR_DEBUG) <<< "monitor noteOn", pitch, vel >>>;
}

fun void _applyFirstNoteMute()
{
    if(_firstNoteMuted) return;
    1 => _firstNoteMuted;
    // Studio/sim: keep OSC flowing to client buffers — movements need phrase + silence events.
    if(SIM_MONITOR)
    {
        <<< ">>> first MIDI (sim — still forwarding to clients)" >>>;
        return;
    }
    1 => _ensembleMuted;
    // Monitor-only from here — do not deactivate clients. The ChuGL / GameTrak
    // conductor owns agent activation (applyMovement2, etc.).
    <<< ">>> first MIDI — monitor only (conductor controls agents)" >>>;
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
            if(FIRST_NOTE_MUTE && !_firstNoteMuted && on[0])
            {
                _monitorNoteOn(pitch[0], vel[0]);
                _applyFirstNoteMute();
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
        <<< "v10 server — :pad: first MIDI note mutes ensemble" >>>;
    else
        <<< "v10 server — pass :score or :pad" >>>;
}

while(true) 50::ms => now;
