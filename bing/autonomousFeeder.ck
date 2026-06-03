8 => int NUM_SLOTS;
"224.0.0.1" => string MULTICAST_ADDR;

for(0 => int i; i < me.args(); i++)
{
    if(me.arg(i) == "local") "127.0.0.1" => MULTICAST_ADDR;
}

OscOut xmit;
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
        xmit.dest(MULTICAST_ADDR, 9000 + s);
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
        xmit.dest(MULTICAST_ADDR, 9000 + s);
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
        xmit.dest(MULTICAST_ADDR, 9000 + s);
        xmit.start("/ds9/phraseComplete");
        xmit.send();
    }
}

fun void _silenceAll(float sec)
{
    if(_feederPaused) return;
    for(0 => int s; s < NUM_SLOTS; s++)
    {
        xmit.dest(MULTICAST_ADDR, 9000 + s);
        xmit.start("/ds9/silenceSustained");
        sec => xmit.add;
        xmit.send();
    }
}

fun void injectPhrase()
{
    if(_feederPaused) return;
    Math.random2(48, 84) => int cur;
    Math.random2(3, 8) => int numNotes;
    for(0 => int i; i < numNotes; i++)
    {
        if(_feederPaused) return;
        Math.random2(-5, 5) + cur => int next;
        if(next < 36) 36 => next;
        if(next > 96) 96 => next;
        next => cur;
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
<<< "autonomousFeeder: idle (paused) — unpaused by Movement 1A / 5 (MIDI 36)" >>>;

while(true) 1::second => now;
