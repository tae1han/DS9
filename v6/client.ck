@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "oscBufferState.ck", "agent.ck"}
@import {"instruments/modalBarInst.ck", "instruments/krstlchrInst.ck", "instruments/frenchrnInst.ck", "instruments/synthBassInst.ck", "instruments/arpInst.ck"}
@import {"agents/parrot.ck", "agents/parakeet.ck", "agents/albatross.ck", "agents/peacock.ck", "agents/emu.ck", "agents/falcon.ck"}
@import {"graphics/display.ck"}

// Config
9000 => int OSC_LISTEN_PORT_BASE;
8889 => int SERVER_STATUS_PORT;
9100 => int CLIENT_CONTROL_PORT_BASE;
8891 => int SERVER_WAVE_PORT;
"224.0.0.1" => string MULTICAST_ADDR;

// chuck client.ck:<slotId0to5>
if(me.args() < 1)
{
    <<< "usage: chuck client.ck:<slotId 0-5>" >>>;
    me.exit();
}

Std.atoi(me.arg(0)) => int myIndex;
if(myIndex < 0 || myIndex > 5)
{
    <<< "invalid slotId:", myIndex >>>;
    me.exit();
}

["parrot", "parakeet", "albatross", "peacock", "emu", "falcon"] @=> string roleNames[];

// OSC input from server
// ------------------------------------------------------------
oscBufferState obs;
obs.oscPort(OSC_LISTEN_PORT_BASE + myIndex);

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

// Agents + instruments (all preloaded; only one active at a time)
Agent @ roleAgents[6];
ezInstrument @ roleInst[6];
Parrot parrot;
Parakeet parakeet;
Albatross albatross;
Peacock peacock;
Emu emu;
Falcon falcon;

modalBarInst instParrot(6); instParrot.gain(2.5); instParrot => master;
ezFluidInst instParakeet("./data/TimGM6mb.sf2", 24); instParakeet.gain(8); instParakeet => master;
krstlchrInst instAlbatross; instAlbatross.gain(0.8); instAlbatross => master;
frenchrnInst instPeacock; instPeacock.gain(1.1); instPeacock => master;
synthBassInst instEmu; instEmu.gain(.9); instEmu => master;
arpInst instFalcon; instFalcon.gain(.5); instFalcon => master;

obs @=> parrot.source; instParrot @=> parrot.inst; "parrot" => parrot.name;
obs @=> parakeet.source; instParakeet @=> parakeet.inst; "parakeet" => parakeet.name;
obs @=> albatross.source; instAlbatross @=> albatross.inst; "albatross" => albatross.name;
obs @=> peacock.source; instPeacock @=> peacock.inst; "peacock" => peacock.name;
obs @=> emu.source; instEmu @=> emu.inst; "emu" => emu.name;
obs @=> falcon.source; instFalcon @=> falcon.inst; "falcon" => falcon.name;

parrot @=> roleAgents[0]; instParrot @=> roleInst[0];
parakeet @=> roleAgents[1]; instParakeet @=> roleInst[1];
albatross @=> roleAgents[2]; instAlbatross @=> roleInst[2];
peacock @=> roleAgents[3]; instPeacock @=> roleInst[3];
emu @=> roleAgents[4]; instEmu @=> roleInst[4];
falcon @=> roleAgents[5]; instFalcon @=> roleInst[5];

for(int i; i < 6; i++)
{
    roleAgents[i].run();
    roleAgents[i].disable();
}
(-1) => int activeRole;

// Run
// ------------------------------------------------------------
spork ~ obs.oscListen();
spork ~ obs.rollingReaper();

<<< "client running slot:", myIndex, "multicast:", MULTICAST_ADDR >>>;

// report status back to server via multicast
OscOut statusOut;
statusOut.dest(MULTICAST_ADDR, SERVER_STATUS_PORT);

fun void _reportStatus()
{
    while(true)
    {
        100::ms => now;
        statusOut.start("/ds9/status");
        myIndex => statusOut.add;
        activeRole => statusOut.add;
        if(activeRole >= 0)
        {
            roleAgents[activeRole].displayStatus => statusOut.add;
            roleAgents[activeRole].displayBody => statusOut.add;
            1 => statusOut.add;
        }
        else
        {
            0 => statusOut.add;
            "" => statusOut.add;
            0 => statusOut.add;
        }
        statusOut.send();
    }
}

spork ~ _reportStatus();

OscOut waveOut;
waveOut.dest(MULTICAST_ADDR, SERVER_WAVE_PORT);

fun void _reportWaveform()
{
    while(true)
    {
        33::ms => now; // ~30 Hz
        if(activeRole < 0) continue;
        if(display.waveform.samples.size() < 64) continue;

        display.waveform.samples.size() / 64 => int step;
        if(step < 1) 1 => step;

        waveOut.start("/ds9/wave");
        myIndex => waveOut.add;
        for(int i; i < 64; i++)
        {
            i * step => int idx;
            if(idx >= display.waveform.samples.size())
                display.waveform.samples.size() - 1 => idx;
            display.waveform.samples[idx] * 2.0 => waveOut.add;
        }
        waveOut.send();
    }
}

// Display
ClientDisplay display --> GG.scene();
display.init(0);
display.setVisible(0);
GG.camera().orthographic();
GG.bloom(true);
GG.bloomPass().intensity(0.2);
spork ~ _reportWaveform();

fun void _activateRole(int roleIdx)
{
    if(roleIdx == activeRole) return;

    if(activeRole >= 0)
    {
        roleAgents[activeRole].disable();
        roleInst[activeRole] =< display.waveform.inlet;
    }

    if(roleIdx < 0 || roleIdx >= 6)
    {
        -1 => activeRole;
        display.setVisible(0);
        return;
    }

    roleIdx => activeRole;
    roleAgents[activeRole].enable();
    roleInst[activeRole] => display.waveform.inlet;
    display.setRole(activeRole);
    display.setVisible(1);
}

OscIn controlIn;
OscMsg controlMsg;
CLIENT_CONTROL_PORT_BASE + myIndex => controlIn.port;
controlIn.addAddress("/ds9/control/activate");
controlIn.addAddress("/ds9/control/setParam");

fun void _receiveControl()
{
    while(true)
    {
        controlIn => now;
        while(controlIn.recv(controlMsg))
        {
            if(controlMsg.address == "/ds9/control/activate")
            {
                controlMsg.getInt(0) => int slotId;
                controlMsg.getInt(1) => int roleIdx;
                controlMsg.getInt(2) => int enabled;
                if(slotId != myIndex) continue;
                if(enabled > 0) _activateRole(roleIdx);
                else _activateRole(-1);
            }
            else if(controlMsg.address == "/ds9/control/setParam")
            {
                controlMsg.getInt(0) => int slotId;
                controlMsg.getInt(1) => int roleIdx;
                controlMsg.getString(2) => string param;
                controlMsg.getFloat(3) => float value;
                if(slotId != myIndex) continue;
                if(roleIdx >= 0 && roleIdx < 6) roleAgents[roleIdx].setParam(param, value);
            }
        }
    }
}

spork ~ _receiveControl();

while(true)
{
    if(activeRole >= 0)
    {
        display.setStatus(roleAgents[activeRole].displayStatus);
        display.setBody(roleAgents[activeRole].displayBody);
    }
    else
    {
        display.setStatus(0);
        display.setBody("");
    }
    GG.nextFrame() => now;
}
