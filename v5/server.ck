@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "oscBroadcaster.ck", "midiPlayer.ck"}
@import {"graphics/display.ck"}

// Config
2 => int MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.75 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

8888 => int CLIENT_OSC_PORT;
8889 => int SERVER_STATUS_PORT;

["localhost"] @=> string CLIENT_IPS[]; // debug
// ["cheese.local", "dumpling.local", "eggroll.local", ...] @=> string CLIENT_IPS[];

// Buffer state
bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);

// OSC
oscBroadcaster broadcaster;
for(int i; i < CLIENT_IPS.size(); i++)
{
    broadcaster.addClient(CLIENT_IPS[i], CLIENT_OSC_PORT);
}

// forward bufferState events to OSC
fun void _forwardNoteOn()
{
    while(true)
    {
        bs.noteReceivedEvent => now;
        bs._lastNote @=> ezNote n;
        // <<< "fwd noteOn:", n.pitch(), n.velocity() >>>;
        broadcaster.noteOn(n.pitch() $ int, n.velocity());
    }
}

fun void _forwardNoteOff()
{
    while(true)
    {
        bs.noteOffEvent => now;
        // <<< "fwd noteOff:", bs._lastNoteOffPitch >>>;
        broadcaster.noteOff(bs._lastNoteOffPitch);
    }
}

fun void _forwardPhraseStart()
{
    while(true)
    {
        bs.phraseStartEvent => now;
        // <<< "fwd phraseStart" >>>;
        broadcaster.phraseStart();
    }
}

fun void _forwardPhraseComplete()
{
    while(true)
    {
        bs.phraseCompleteEvent => now;
        // <<< "fwd phraseComplete, notes:", bs.completedPhrase.notes().size() >>>;
        broadcaster.phraseComplete();
    }
}

fun void _forwardSilence()
{
    while(true)
    {
        bs.silenceSustainedEvent => now;
        broadcaster.silenceSustained(bs.silenceSeconds());
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
    midiPlayer monitor(MIDI_DEVICE);
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

<<< "server running. clients:", CLIENT_IPS.size(), "port:", CLIENT_OSC_PORT >>>;

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
