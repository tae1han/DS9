// Injects random phrases to all client oscBufferStates (no human MIDI needed).
// Run beside local-run after scene:chaos2 (or pass :chaos2 to auto-apply).
//
//   chuck autonomousFeeder.ck:local
//   Starts idle (paused). GameTrak pedal 1 → chaos2 + unpauses feeder.

@import "conductor.ck"
@import "conductorScenes.ck"

8 => int NUM_SLOTS;
9000 => int CLIENT_OSC_PORT;
"224.0.0.1" => string MULTICAST_ADDR;

for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
}

OscOut xmit;
OscOut controlOut;
Conductor conductor(controlOut, MULTICAST_ADDR, NUM_SLOTS);
ConductorScenes scenes(conductor, NUM_SLOTS);

9112 => int FEEDER_CTL_PORT;
1 => int _feederPaused;
OscIn feederCtl;
OscMsg feederMsg;

feederCtl.port(FEEDER_CTL_PORT);
feederCtl.addAddress("/ds9/control/feeder");

fun void _feederCtlListen()
{
    while(true)
    {
        feederCtl => now;
        while(feederCtl.recv(feederMsg))
        {
            if(feederMsg.getInt(0) > 0)
            {
                1 => _feederPaused;
                <<< "autonomousFeeder: PAUSED" >>>;
            }
            else
            {
                0 => _feederPaused;
                <<< "autonomousFeeder: running" >>>;
            }
        }
    }
}

fun void _noteOnAll(int pitch, float vel)
{
    if(_feederPaused) return;
    for(0 => int s; s < NUM_SLOTS; s++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + s);
        xmit.start("/ds9/noteOn");
        pitch => xmit.add;
        vel => xmit.add;
        xmit.send();
    }
}

fun void _noteOffAll(int pitch)
{
    if(_feederPaused) return;
    for(0 => int s; s < NUM_SLOTS; s++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + s);
        xmit.start("/ds9/noteOff");
        pitch => xmit.add;
        xmit.send();
    }
}

fun void _phraseCompleteAll()
{
    if(_feederPaused) return;
    for(0 => int s; s < NUM_SLOTS; s++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + s);
        xmit.start("/ds9/phraseComplete");
        xmit.send();
    }
}

fun void _silenceAll(float sec)
{
    if(_feederPaused) return;
    for(0 => int s; s < NUM_SLOTS; s++)
    {
        xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + s);
        xmit.start("/ds9/silenceSustained");
        sec => xmit.add;
        xmit.send();
    }
}

fun int _clampMidi(int p)
{
    while(p < 40) 12 +=> p;
    while(p > 100) 12 -=> p;
    return p;
}

// Atonal bursts: all 12 PCs, large erratic leaps, very fast note rate.
fun void injectPhrase()
{
    if(_feederPaused) return;

    Math.random2(48, 88) => int cur;
    _clampMidi(cur) => cur;
    Math.random2(7, 14) => int nNotes;

    for(0 => int i; i < nNotes; i++)
    {
        if(_feederPaused) return;

        if(i > 0)
        {
            Math.random2(5, 19) => int leap;
            if(Math.random2(0, 1) == 0) -1 * leap => leap;
            if(Math.randomf() < 0.25)
                Math.random2(24, 36) * (Math.random2(0, 1) * 2 - 1) => leap;
            cur + leap => cur;
            _clampMidi(cur) => cur;
        }

        Math.random2f(0.5, 0.95) => float vel;
        _noteOnAll(cur, vel);
        Math.random2f(18, 55) * 1::ms => now;
        _noteOffAll(cur);
        Math.random2f(8, 28) * 1::ms => now;
    }

    if(_feederPaused) return;

    20::ms => now;
    _phraseCompleteAll();
}

fun void feederLoop()
{
    while(true)
    {
        if(_feederPaused)
        {
            50::ms => now;
            continue;
        }
        injectPhrase();
        if(_feederPaused) continue;
        if(Math.randomf() < 0.12)
        {
            Math.random2f(0.35, 0.7)::second => now;
            if(!_feederPaused) _silenceAll(2.5);
        }
        Math.random2f(0.08, 0.35)::second => now;
    }
}

spork ~ _feederCtlListen();
spork ~ feederLoop();
<<< "autonomousFeeder: idle (paused) — waiting for GameTrak pedal to start chaos2" >>>;

while(true) 1::second => now;
