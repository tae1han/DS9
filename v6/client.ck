@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "oscBufferState.ck", "agent.ck"}
@import {"instruments/modalBarInst.ck", "instruments/krstlchrInst.ck", "instruments/frenchrnInst.ck", "instruments/synthBassInst.ck", "instruments/arpInst.ck"}
@import {"agents/parrot.ck", "agents/parakeet.ck", "agents/albatross.ck", "agents/peacock.ck", "agents/emu.ck", "agents/falcon.ck"}
@import {"graphics/display.ck"}

// Config
8888 => int OSC_LISTEN_PORT;
8889 => int SERVER_STATUS_PORT;
"224.0.0.1" => string MULTICAST_ADDR;

// chuck client.ck:<agentName>
if(me.args() < 1)
{
    <<< "usage: chuck client.ck:<agent name>" >>>;
    me.exit();
}

me.arg(0) => string agentName;

["parrot", "parakeet", "albatross", "peacock", "emu", "falcon"] @=> string agentNames[];

fun int agentIndex(string name)
{
    for(int i; i < agentNames.size(); i++)
    {
        if(agentNames[i] == name) return i;
    }
    return -1;
}

agentIndex(agentName) => int myIndex;
if(myIndex < 0)
{
    <<< "unknown agent:", agentName >>>;
    me.exit();
}

// OSC input from server
// ------------------------------------------------------------
oscBufferState obs;
obs.oscPort(OSC_LISTEN_PORT);

// Audio signal chain
Gain master => LPF lpf => Dyno comp => NRev rev;
master.gain(.8);
lpf.freq(7000);
comp.limit();
rev.mix(0.1);
for(int i; i < dac.channels(); i++)
{
    rev => dac.chan(i);
}

// Agent + instrument
Agent @ theAgent;

if(agentName == "parrot")
{
    modalBarInst inst(6);
    inst.gain(2.5);
    inst => master;
    Parrot agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}
else if(agentName == "parakeet")
{
    ezFluidInst inst("./data/TimGM6mb.sf2", 24);
    inst.gain(12);
    // inst => LPF lpf_p => NRev rev_p => master;
    // lpf_p.freq(3000);
    // rev_p.mix(0.075);
    inst => master;
    Parakeet agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}
else if(agentName == "albatross")
{
    krstlchrInst inst;
    inst.gain(0.5);
    inst => master;
    Albatross agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}
else if(agentName == "peacock")
{
    frenchrnInst inst;
    inst.gain(.8);
    inst => master;
    Peacock agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}
else if(agentName == "emu")
{
    synthBassInst inst;
    inst.gain(.9);
    inst => master;
    Emu agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}
else if(agentName == "falcon")
{
    arpInst inst;
    inst.gain(.5);
    inst => master;
    Falcon agent;
    obs @=> agent.source;
    inst @=> agent.inst;
    agent @=> theAgent;
}

// Run
// ------------------------------------------------------------
spork ~ obs.oscListen();
spork ~ obs.rollingReaper();
theAgent.run();

<<< "client running:", agentName, "multicast:", MULTICAST_ADDR >>>;

// report status back to server via multicast
OscOut statusOut;
statusOut.dest(MULTICAST_ADDR, SERVER_STATUS_PORT);

fun void _reportStatus()
{
    while(true)
    {
        100::ms => now;
        statusOut.start("/ds9/status");
        agentName => statusOut.add;
        theAgent.displayStatus => statusOut.add;
        theAgent.displayBody => statusOut.add;
        statusOut.send();
        // <<< "sent status:", theAgent.displayStatus >>>;
    }
}

spork ~ _reportStatus();

// Display
ClientDisplay display --> GG.scene();
display.init(myIndex);
if(theAgent.inst != null)
{
    theAgent.inst => display.waveform.inlet;
}
GG.camera().orthographic();
GG.bloom(true);
GG.bloomPass().intensity(0.2);

while(true)
{
    display.setStatus(theAgent.displayStatus);
    display.setBody(theAgent.displayBody);
    GG.nextFrame() => now;
}
