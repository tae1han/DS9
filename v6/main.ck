@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "agent.ck", "midiPlayer.ck"}
@import {"instruments/modalBarInst.ck", "instruments/krstlchrInst.ck", "instruments/frenchrnInst.ck", "instruments/synthBassInst.ck", "instruments/arpInst.ck"}
@import {"agents/parrot.ck", "agents/parakeet.ck", "agents/albatross.ck", "agents/peacock.ck", "agents/emu.ck", "agents/falcon.ck"}
@import {"graphics/display.ck"}

// Config
"USB Midi Cable" => string MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.75 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

if(me.args() > 0) me.arg(0) => MIDI_DEVICE;

bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);


// Instruments (gains match client.ck)
modalBarInst parrotInst(6);      parrotInst.gain(2.5);
ezFluidInst parakeetInst("./data/TimGM6mb.sf2", 24);  parakeetInst.gain(8);
krstlchrInst albatrossInst;      albatrossInst.gain(0.5);
frenchrnInst peacockInst;        peacockInst.gain(.8);
synthBassInst emuInst;           emuInst.gain(.9);
arpInst falconInst;              falconInst.gain(.5);

ezFluidInst monitorInst("./data/TimGM6mb.sf2");
monitorInst.gain(10);

// Master chain (matches client.ck: all instruments direct to master)
Gain master => LPF lpf => Dyno comp => NRev rev;
master.gain(.8);
lpf.freq(7000);
comp.limit();
rev.mix(0.1);
for(int i; i < dac.channels(); i++)
{
    rev => dac.chan(i);
}

parrotInst    => master;
parakeetInst  => master;
albatrossInst => master;
peacockInst   => master;
emuInst       => master;
falconInst    => master;

if(MONITOR_USER_INPUT) monitorInst => master;

// Agents
Parrot parrot;       bs @=> parrot.source;    parrotInst @=> parrot.inst;
Parakeet parakeet;   bs @=> parakeet.source;  parakeetInst @=> parakeet.inst;
Albatross albatross; bs @=> albatross.source; albatrossInst @=> albatross.inst;
Peacock peacock;     bs @=> peacock.source;   peacockInst @=> peacock.inst;
Emu emu;             bs @=> emu.source;       emuInst @=> emu.inst;
Falcon falcon;       bs @=> falcon.source;    falconInst @=> falcon.inst;

if(MONITOR_USER_INPUT)
{
    midiPlayer monitor;
    monitor.device(MIDI_DEVICE);
    monitor.setInstrument(monitorInst);
}

// Run
spork ~ bs.listen();
spork ~ bs.silenceWatcher();
spork ~ bs.rollingReaper();

parrot.run();
parakeet.run();
albatross.run();
peacock.run();
emu.run();
falcon.run();

<<< "running with 6 agents. silenceThreshold=" + bs.silenceThreshold + "s rollingWindow=" + bs.rollingWindow + "s" >>>;

// Graphics

Agent @ agents[6];
parrot @=> agents[0];
parakeet @=> agents[1];
albatross @=> agents[2];
peacock @=> agents[3];
emu @=> agents[4];
falcon @=> agents[5];




DisplayConsole display --> GG.scene();
for(int i; i < 6; i++)
{
    agents[i].inst => display.waveforms[i].inlet;
}
GG.camera().orthographic();

GG.bloom(true);
GG.bloomPass().intensity(0.2);

while(true)
{
    for(int i; i < agents.size(); i++)
    {
        display.setStatus(i, agents[i].displayStatus);
        display.setBody(i, agents[i].displayBody);
    }
    GG.nextFrame() => now;
}