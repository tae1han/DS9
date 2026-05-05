@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "agent.ck", "midiPlayer.ck"}
@import {"instruments/modalBarInst.ck", "instruments/krstlchrInst.ck", "instruments/frenchrnInst.ck", "instruments/synthBassInst.ck", "instruments/arpInst.ck"}
@import {"agents/parrot.ck", "agents/parakeet.ck", "agents/albatross.ck", "agents/peacock.ck", "agents/emu.ck", "agents/falcon.ck"}
@import {"graphics/display.ck"}

// Config
2 => int MIDI_DEVICE;
false => int MONITOR_USER_INPUT;
.75 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

bufferState bs;
SILENCE_THRESHOLD_SEC => bs.silenceThreshold;
ROLLING_WINDOW_SEC => bs.rollingWindow;
bs.device(MIDI_DEVICE);


// Instruments
modalBarInst parrotInst(6);      parrotInst.gain(1.5);
ezFluidInst parakeetInst("./data/TimGM6mb.sf2", 24);  parakeetInst.gain(12);
// modalBarInst parakeetInst(1);  parakeetInst.gain(1.5);
krstlchrInst albatrossInst;      albatrossInst.gain(0.5);
frenchrnInst peacockInst;        peacockInst.gain(.8);
synthBassInst emuInst;           emuInst.gain(.6);
arpInst falconInst;              falconInst.gain(.5);


chout <= "Instrument channel count: " <= IO.newline();
chout <= "parrotInst: " <= parrotInst.channels() <= IO.newline();
chout <= "parakeetInst: " <= parakeetInst.channels() <= IO.newline();
chout <= "albatrossInst: " <= albatrossInst.channels() <= IO.newline();
chout <= "peacockInst: " <= peacockInst.channels() <= IO.newline();
chout <= "emuInst: " <= emuInst.channels() <= IO.newline();
chout <= "falconInst: " <= falconInst.channels() <= IO.newline();
// monitorInst options
// modalBarInst monitorInst(4);  monitorInst.gain(1.2);
// krstlchrInst monitorInst;
// frenchrnInst monitorInst;
ezFluidInst monitorInst("./data/TimGM6mb.sf2");
// monitorInst.progChange(72);
monitorInst.gain(10);

// Master chain
Gain master => LPF lpf => Dyno comp => NRev rev;
master.gain(.8);
lpf.freq(7000);
comp.limit();
rev.mix(0.1);
master.gain(1.2);
for(int i; i < dac.channels(); i++)
{
    rev => dac.chan(i);
}
// <<< "master chain ready" >>>;

parrotInst    => master;
parakeetInst  => LPF lpf_parakeet => NRev rev_parakeet => master;
lpf_parakeet.freq(3000);
rev_parakeet.mix(0.075);
albatrossInst => master;
peacockInst   => master;
// emuInst       => master;
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
    midiPlayer monitor(MIDI_DEVICE);
    monitor.setInstrument(monitorInst);
    // <<< "monitor active on device", MIDI_DEVICE >>>;
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

// fun void graphicsLoop()
// {
//     while(true)
//     {
//         for(int i; i < agents.size(); i++)
//         {
//             display.setStatus(i, agents[i].displayStatus);
//             display.setBody(i, agents[i].displayBody);
//         }
//         GG.nextFrame() => now;
//     }
// }

// spork ~ graphicsLoop();

// while(true)
// {
//     samp => now;
// }

    while(true)
    {
        for(int i; i < agents.size(); i++)
        {
            display.setStatus(i, agents[i].displayStatus);
            display.setBody(i, agents[i].displayBody);
        }
        GG.nextFrame() => now;
    }