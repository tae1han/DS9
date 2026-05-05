@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "midiPlayer.ck"}
@import {"graphics/display.ck"}

// Config
"USB Midi Cable" => string MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.75 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

"224.0.0.1" => string MULTICAST_ADDR;
8888 => int CLIENT_OSC_PORT;
8889 => int SERVER_STATUS_PORT;

// chuck server.ck[:midiDeviceName]
if(me.args() > 0) me.arg(0) => MIDI_DEVICE;

// Buffer state
bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);

// OSC multicast
OscOut xmit;
xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT);

// forward bufferState events to OSC multicast
fun void _forwardNoteOn()
{
    while(true)
    {
        bs.noteReceivedEvent => now;
        bs._lastNote @=> ezNote n;
        xmit.start("/ds9/noteOn");
        n.pitch() $ int => xmit.add;
        n.velocity() => xmit.add;
        xmit.send();
    }
}

fun void _forwardNoteOff()
{
    while(true)
    {
        bs.noteOffEvent => now;
        xmit.start("/ds9/noteOff");
        bs._lastNoteOffPitch => xmit.add;
        xmit.send();
    }
}

fun void _forwardPhraseStart()
{
    while(true)
    {
        bs.phraseStartEvent => now;
        xmit.start("/ds9/phraseStart");
        xmit.send();
    }
}

fun void _forwardPhraseComplete()
{
    while(true)
    {
        bs.phraseCompleteEvent => now;
        xmit.start("/ds9/phraseComplete");
        xmit.send();
    }
}

fun void _forwardSilence()
{
    while(true)
    {
        bs.silenceSustainedEvent => now;
        xmit.start("/ds9/silenceSustained");
        bs.silenceSeconds() => xmit.add;
        xmit.send();
    }
}

// Monitor
// ------------------------------------------------------------
Gain master => LPF lpf => Dyno comp => NRev rev;
master.gain(.8);
lpf.freq(7000);
comp.limit();
rev.mix(0.1);
for(int i; i < dac.channels(); i++)
{
    rev => dac.chan(i);
}

if(MONITOR_USER_INPUT)
{
    ezFluidInst monitorInst("./data/TimGM6mb.sf2");
    monitorInst.gain(10);
    monitorInst => master;
    midiPlayer monitor;
    monitor.device(MIDI_DEVICE);
    monitor.setInstrument(monitorInst);
}

// Run
// ------------------------------------------------------------
spork ~ bs.listen();
spork ~ bs.silenceWatcher();
spork ~ bs.rollingReaper();

spork ~ _forwardNoteOn();
spork ~ _forwardNoteOff();
spork ~ _forwardPhraseStart();
spork ~ _forwardPhraseComplete();
spork ~ _forwardSilence();

<<< "server running. multicast:", MULTICAST_ADDR, "port:", CLIENT_OSC_PORT >>>;

// Display
// ------------------------------------------------------------
DisplayConsole display --> GG.scene();
GG.camera().orthographic();
GG.bloom(true);
GG.bloomPass().intensity(0.2);

["parrot", "parakeet", "albatross", "peacock", "emu", "falcon"] @=> string agentNames[];

fun int agentIndex(string name)
{
    for(int i; i < agentNames.size(); i++)
    {
        if(agentNames[i] == name) return i;
    }
    return -1;
}

OscIn statusIn;
OscMsg statusMsg;
SERVER_STATUS_PORT => statusIn.port;
statusIn.addAddress("/ds9/status");

fun void _receiveStatus()
{
    while(true)
    {
        statusIn => now;
        while(statusIn.recv(statusMsg))
        {
            statusMsg.getString(0) => string name;
            statusMsg.getInt(1) => int stat;
            statusMsg.getString(2) => string body;
            agentIndex(name) => int idx;
            if(idx >= 0)
            {
                display.setStatus(idx, stat);
                display.setBody(idx, body);
            }
            // <<< "status from", name, ":", stat >>>;
        }
    }
}

spork ~ _receiveStatus();

while(true)
{
    GG.nextFrame() => now;
}
