@import "conductor.ck"
@import "lib/SMIR.ck"
@import {"smuck", "smuck/ezFluidInst.ck"}
@import "instruments/slorkPianoMonitorInst.ck"
@import {"lib/bufferState.ck"}
@import {"score/performanceScore.ck"}
@import {"graphics/performanceMonitor.ck"}

"USB Midi Cable" => string MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.25 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

"224.0.0.1" => string MULTICAST_ADDR;
9000 => int CLIENT_OSC_PORT;
8891 => int SERVER_PULSE_PORT;
8892 => int SERVER_LINK_PORT;
8893 => int SERVER_LINK_REPLY_PORT;

me.dir() + "data/TimGM6mb.sf2" => string MONITOR_SF2;

0 => int MIDI_LOG;
0 => int MONITOR_TRACE;
0 => int SOLO_MONITOR;
0 => int SIM_MONITOR;
0 => int FIRST_NOTE_MUTE;
0 => int _firstNoteMuted;
0 => int _ensembleMuted;

for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "sim") 1 => SIM_MONITOR;
    else if(a == "pad" || a == "firstNoteMute") 1 => FIRST_NOTE_MUTE;
    else if(a == "midiLog") 1 => MIDI_LOG;
    else if(a == "monitorTrace") 1 => MONITOR_TRACE;
    else if(a == "solo") 1 => SOLO_MONITOR;
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
    for(int slot; slot < NumSlots.count(); slot++)
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
    for(int slot; slot < NumSlots.count(); slot++)
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
        for(int slot; slot < NumSlots.count(); slot++)
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
        for(int slot; slot < NumSlots.count(); slot++)
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
        for(int slot; slot < NumSlots.count(); slot++)
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
else master.gain(1.6);
lpf.freq(7000);
comp.limit();
rev.mix(0.05);
for(0 => int i; i < dac.channels(); i++)
    rev => dac.chan(i);

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
    if(SIM_MONITOR) monitorInst.gain(8.0);
    else monitorInst.gain(10);
    monitorInst => master;
    for(0 => int p; p < 128; p++) -1 => _monVoice[p];
    1 => _monitorReady;
    <<< "bing server — performance score | MIDI 28–36 control" >>>;
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
        if(_monVoice[pitch] >= 0) _monitorMidi(0, pitch, vel);
        monitorInst.allocate_voice(n) => int v;
        if(v < 0) return;
        v => _monVoice[pitch];
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

Conductor conductor(controlOut, MULTICAST_ADDR, NumSlots.count());

PerformanceMonitor @ monitor;
if(!SOLO_MONITOR)
{
    new PerformanceMonitor() @=> monitor;
    spork ~ monitor.run(0);
}

PerformanceScore score(conductor, NumSlots.count(), monitor);

fun void _resumeClientMidi()
{
    0 => _ensembleMuted;
    conductor.sendMidiForward(1);
}

fun void _applyPadBreak(int postChaos)
{
    if(!postChaos && _firstNoteMuted) return;
    if(postChaos && !score.padAfterChaosReady()) return;
    if(!postChaos) 1 => _firstNoteMuted;
    1 => _ensembleMuted;
    bs.clearHumanBuffers();
    score.applyPadBreak(postChaos);
}

fun void _controlMidiLoop()
{
    while(true)
    {
        bs.controlMidiEvent => now;
        bs.ctlOn => int on;
        bs.ctlPitch => int pitch;

        if(MIDI_LOG && on)
            <<< "CONTROL", pitch >>>;

        if(on) _monitorSilencePitch(pitch);

        if(!on) continue;

        if(pitch == MidiCtl.toggle())
            score.toggleListenChain();
        else if(pitch == MidiCtl.chaos1A())
        {
            _resumeClientMidi();
            score.apply1A();
        }
        else if(pitch == MidiCtl.chaos5() || (pitch >= MidiCtl.movementFirst() && pitch <= MidiCtl.movementLast()))
        {
            _resumeClientMidi();
            score.applyMovement(pitch);
        }
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
            if(_isControlMidi(pitch[0])) continue;

            if(FIRST_NOTE_MUTE && !_firstNoteMuted && on[0])
            {
                _applyPadBreak(0);
                _monitorMidi(1, pitch[0], vel[0]);
                continue;
            }

            if(on[0] && score.padAfterChaosReady())
            {
                _applyPadBreak(1);
                _monitorMidi(1, pitch[0], vel[0]);
                continue;
            }

            if(on[0])
            {
                _monitorMidi(1, pitch[0], vel[0]);
                if(!_ensembleMuted) _oscForwardNoteOn(pitch[0], vel[0]);
            }
            else
            {
                _monitorMidi(0, pitch[0], 0.0);
                if(!_ensembleMuted) _oscForwardNoteOff(pitch[0]);
            }
        }
    }
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
        while(linkIn.recv(linkMsg)) ;
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
            if(serverCtlMsg.getInt(0) > 0) 0 => _ensembleMuted;
            else 1 => _ensembleMuted;
        }
    }
}

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
    if(!SIM_MONITOR)
        for(int i; i < NumSlots.count(); i++)
            conductor.sendActivate(i, 0);
}

if(SOLO_MONITOR)
    <<< "bing SOLO — piano monitor only" >>>;
else
{
    <<< "v10 server OSC", MULTICAST_ADDR, "| :local = same-machine only" >>>;
    if(FIRST_NOTE_MUTE)
        <<< "v10 server — :pad: first note = 1B solo; MIDI 100=1A, 36=5, 29–35=movements, 28=toggle" >>>;
    else
        <<< "v10 server — pass :pad for concert flow" >>>;
}

while(true) 50::ms => now;
