@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "midiPlayer.ck"}
@import {"graphics/display.ck"}

// Config
"USB Midi Cable" => string MIDI_DEVICE;
true => int MONITOR_USER_INPUT;
.25 => float SILENCE_THRESHOLD_SEC;
5.0 => float ROLLING_WINDOW_SEC;

"224.0.0.1" => string MULTICAST_ADDR;
9000 => int CLIENT_OSC_PORT;
8889 => int SERVER_STATUS_PORT;
8891 => int SERVER_WAVE_PORT;
9100 => int CLIENT_CONTROL_PORT_BASE;

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
OscOut controlOut;
controlOut.dest(MULTICAST_ADDR, CLIENT_CONTROL_PORT_BASE);

// forward bufferState events to OSC multicast
fun void _forwardNoteOn()
{
    while(true)
    {
        bs.noteReceivedEvent => now;
        bs._lastNote @=> ezNote n;
        for(int slot; slot < 6; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/noteOn");
            n.pitch() $ int => xmit.add;
            n.velocity() => xmit.add;
            xmit.send();
        }
    }
}

fun void _forwardNoteOff()
{
    while(true)
    {
        bs.noteOffEvent => now;
        for(int slot; slot < 6; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/noteOff");
            bs._lastNoteOffPitch => xmit.add;
            xmit.send();
        }
    }
}

fun void _forwardPhraseStart()
{
    while(true)
    {
        bs.phraseStartEvent => now;
        for(int slot; slot < 6; slot++)
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
        for(int slot; slot < 6; slot++)
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
        for(int slot; slot < 6; slot++)
        {
            xmit.dest(MULTICAST_ADDR, CLIENT_OSC_PORT + slot);
            xmit.start("/ds9/silenceSustained");
            bs.silenceSeconds() => xmit.add;
            xmit.send();
        }
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
for(int i; i < 6; i++) display.waveforms[i].setUseLocalAudio(0);
GG.camera().orthographic();
GG.bloom(true);
GG.bloomPass().intensity(0.2);

["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon"] @=> string roleLabels[];
["parrot", "parakeet", "albatross", "peacock", "emu", "falcon"] @=> string agentNames[];

fun int agentIndex(string name)
{
    for(int i; i < agentNames.size(); i++)
    {
        if(agentNames[i] == name) return i;
    }
    return -1;
}

fun void sendActivate(int slotId, int roleIdx, int enabled)
{
    controlOut.dest(MULTICAST_ADDR, CLIENT_CONTROL_PORT_BASE + slotId);
    controlOut.start("/ds9/control/activate");
    slotId => controlOut.add;
    roleIdx => controlOut.add;
    enabled => controlOut.add;
    controlOut.send();
}

fun void sendParam(int slotId, int roleIdx, string param, float value)
{
    controlOut.dest(MULTICAST_ADDR, CLIENT_CONTROL_PORT_BASE + slotId);
    controlOut.start("/ds9/control/setParam");
    slotId => controlOut.add;
    roleIdx => controlOut.add;
    param => controlOut.add;
    value => controlOut.add;
    controlOut.send();
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
            statusMsg.getInt(0) => int slotId;
            statusMsg.getInt(1) => int roleIdx;
            statusMsg.getInt(2) => int stat;
            statusMsg.getString(3) => string body;
            statusMsg.getInt(4) => int visible;
            if(slotId >= 0 && slotId < 6)
            {
                if(roleIdx >= 0 && roleIdx < 6)
                {
                    display.setName(slotId, roleLabels[roleIdx]);
                    if(roleIdx == 0) display.setColor(slotId, Color.RED);
                    else if(roleIdx == 1) display.setColor(slotId, Color.GREEN);
                    else if(roleIdx == 2) display.setColor(slotId, Color.CYAN);
                    else if(roleIdx == 3) display.setColor(slotId, Color.BLUE);
                    else if(roleIdx == 4) display.setColor(slotId, Color.YELLOW);
                    else if(roleIdx == 5) display.setColor(slotId, Color.MAGENTA);
                }
                display.setVisible(slotId, visible);
                display.setStatus(slotId, stat);
                display.setBody(slotId, body);
            }
        }
    }
}

spork ~ _receiveStatus();

OscIn waveIn;
OscMsg waveMsg;
SERVER_WAVE_PORT => waveIn.port;
waveIn.addAddress("/ds9/wave");

fun void _receiveWave()
{
    while(true)
    {
        waveIn => now;
        while(waveIn.recv(waveMsg))
        {
            waveMsg.getInt(0) => int slotId;
            if(slotId < 0 || slotId >= 6) continue;
            float ys[0];
            for(int i; i < 64; i++)
            {
                waveMsg.getFloat(i + 1) => float y;
                ys << y;
            }
            display.waveforms[slotId].setRemoteY(ys);
        }
    }
}

spork ~ _receiveWave();

// Start with all slots inactive/hidden until first played note.
for(int i; i < 6; i++)
{
    sendActivate(i, 0, 0);
}

fun void _conductorTimeline()
{
    bs.noteReceivedEvent => now;
    <<< "conductor: first MIDI note received, starting timeline" >>>;
    <<< "movement 1: solo parrot (5s)" >>>;

    // Start: all 6 are parrots, but only slot 0 active.
    for(int i; i < 6; i++)
    {
        sendActivate(i, 0, 0);
        // unison / verbatim baseline
        sendParam(i, 0, "probability", 1.0);
        sendParam(i, 0, "delayMin", 1.5);
        sendParam(i, 0, "delayMax", 1.5);
        sendParam(i, 0, "octaveDisplaceProb", 0.0);
        sendParam(i, 0, "rhythmScale", 1.0);
        sendParam(i, 0, "truncateMin", 0);
        sendParam(i, 0, "truncateMax", 0);
        sendParam(i, 0, "repeatsMin", 1);
        sendParam(i, 0, "repeatsMax", 1);
    }
    sendActivate(0, 0, 1);
    5::second => now;

    // Over 5 seconds: activate remaining parrots.
    <<< "movement 2: parrot unison ramp-in (5s)" >>>;
    for(1 => int i; i < 6; i++)
    {
        1::second => now;
        sendActivate(i, 0, 1);
    }

    // 20 seconds parrot drift (testbench-like).
    <<< "movement 3: parrot drift (20s)" >>>;
    for(int step; step < 4; step++)
    {
        (step + 1) / 4.0 => float t;
        for(int i; i < 6; i++)
        {
            Math.random2f(0.0, 2.0 * t) => float dMin;
            Math.random2f(1.5, 1.5 + 4.0 * t) => float dMax;
            Math.random2f(1.0 - 0.6 * t, 1.0) => float pProb;
            sendParam(i, 0, "probability", pProb);
            sendParam(i, 0, "delayMin", dMin);
            sendParam(i, 0, "delayMax", dMax);
            sendParam(i, 0, "octaveDisplaceProb", Math.random2f(0.0, 0.3 * t));
            sendParam(i, 0, "rhythmScale", Math.random2f(1.0 - 0.3 * t, 1.0 + 0.7 * t));
            if(t > 0.5)
            {
                sendParam(i, 0, "truncateMin", Math.random2(2, 4));
                sendParam(i, 0, "truncateMax", Math.random2(4, 8));
            }
            if(t > 0.7)
            {
                sendParam(i, 0, "repeatsMin", 1);
                sendParam(i, 0, "repeatsMax", Math.random2(1, 3));
            }
        }
        5::second => now;
    }

    // Over 5 seconds: staggered random Parrot -> Parakeet.
    <<< "movement 4: staggered parrot -> parakeet (5s)" >>>;
    int orderA[6];
    for(int i; i < 6; i++) i => orderA[i];
    for(5 => int i; i > 0; i--)
    {
        Math.random2(0, i) => int j;
        orderA[i] => int t;
        orderA[j] => orderA[i];
        t => orderA[j];
    }
    for(int s; s < 6; s++)
    {
        sendActivate(orderA[s], 1, 1);
        if(s < 5) 1::second => now;
    }

    // 20 seconds parakeet drift.
    <<< "movement 5: parakeet drift (20s)" >>>;
    for(int step; step < 4; step++)
    {
        (step + 1) / 4.0 => float t;
        for(int i; i < 6; i++)
        {
            sendParam(i, 1, "intervalMin", Math.random2(1, Math.max(1, 4 - ((t * 2.5) $ int))));
            sendParam(i, 1, "intervalMax", Math.random2(7 + ((t * 6) $ int), 12 + ((t * 6) $ int)));
            if(Math.randomf() < 0.55 * t) sendParam(i, 1, "harmonyDirection", -1);
            else sendParam(i, 1, "harmonyDirection", 1);
            sendParam(i, 1, "polyphony", Math.random2(1, Math.min(4, 1 + ((t * 3.9) $ int))));
            sendParam(i, 1, "activationProb", Math.random2f(0.5 + t * 0.45, 1.0));
            sendParam(i, 1, "windowDurMin", Math.random2f(1.5, 2.0 + 4.0 * t));
            sendParam(i, 1, "windowDurMax", Math.random2f(3.0 + 3.0 * t, 6.0 + 6.0 * t));
            sendParam(i, 1, "silenceMin", Math.random2f(2.0, 4.0 + 4.0 * t));
            sendParam(i, 1, "silenceMax", Math.random2f(5.0, 7.0 + 8.0 * t));
        }
        5::second => now;
    }

    // 5 seconds: staggered split to 3 Albatross and 3 Peacock.
    <<< "movement 6: split to albatross/peacock (5s)" >>>;
    int orderB[6];
    for(int i; i < 6; i++) i => orderB[i];
    for(5 => int i; i > 0; i--)
    {
        Math.random2(0, i) => int j;
        orderB[i] => int t;
        orderB[j] => orderB[i];
        t => orderB[j];
    }
    for(int s; s < 6; s++)
    {
        if(s < 3)
        {
            sendActivate(orderB[s], 2, 1); // albatross
            // make albatross entry easier to trigger immediately
            sendParam(orderB[s], 2, "minNotes", 2);
            sendParam(orderB[s], 2, "minPitchClasses", 2);
            sendParam(orderB[s], 2, "delayMin", 0.0);
            sendParam(orderB[s], 2, "delayMax", 0.2);
        }
        else sendActivate(orderB[s], 3, 1);      // peacock
        if(s < 5) 1::second => now;
    }

    // 20 seconds mixed Albatross/Peacock drift.
    <<< "movement 7: mixed albatross + peacock (20s)" >>>;
    for(int step; step < 4; step++)
    {
        for(int s; s < 3; s++)
        {
            orderB[s] => int idxA;
            sendParam(idxA, 2, "holdSecondsMin", Math.random2f(4.0, 8.0));
            sendParam(idxA, 2, "holdSecondsMax", Math.random2f(8.0, 14.0));
            sendParam(idxA, 2, "delayMin", Math.random2f(0.5, 2.0));
            sendParam(idxA, 2, "delayMax", Math.random2f(3.0, 7.0));
            sendParam(idxA, 2, "maxVoices", Math.random2(1, 3));
        }
        for(int s; s < 3; s++)
        {
            orderB[s + 3] => int idxP;
            sendParam(idxP, 3, "inversionProb", Math.random2f(0.3, 0.8));
            sendParam(idxP, 3, "delayMin", Math.random2f(0.0, 1.5));
            sendParam(idxP, 3, "delayMax", Math.random2f(2.0, 5.0));
        }
        5::second => now;
    }

    // Agent 5 becomes Emu.
    <<< "movement 8: slot 5 -> emu" >>>;
    4 => int slotEmu;
    sendActivate(slotEmu, 4, 1);

    // 15 seconds later, agent 6 becomes Falcon.
    <<< "movement 9: wait 15s, slot 6 -> falcon" >>>;
    15::second => now;
    5 => int slotLeadFalcon;
    sendActivate(slotLeadFalcon, 5, 1);

    // Over 10 seconds, stagger the rest to Falcon.
    <<< "movement 10: stagger remaining -> falcon (10s)" >>>;
    int rest[4];
    0 => rest[0];
    1 => rest[1];
    2 => rest[2];
    3 => rest[3];
    for(3 => int i; i > 0; i--)
    {
        Math.random2(0, i) => int j;
        rest[i] => int t;
        rest[j] => rest[i];
        t => rest[j];
    }
    for(int r; r < 4; r++)
    {
        sendActivate(rest[r], 5, 1);
        if(r < 3) 2500::ms => now;
    }

    // After 15 seconds, stagger to canonical assignments:
    // parrot, parakeet, albatross, peacock, emu, falcon.
    <<< "movement 11: wait 15s, stagger to canonical roles" >>>;
    15::second => now;
    int canonical[6];
    0 => canonical[0];
    1 => canonical[1];
    2 => canonical[2];
    3 => canonical[3];
    4 => canonical[4];
    5 => canonical[5];
    int orderC[6];
    for(int i; i < 6; i++) i => orderC[i];
    for(5 => int i; i > 0; i--)
    {
        Math.random2(0, i) => int j;
        orderC[i] => int t;
        orderC[j] => orderC[i];
        t => orderC[j];
    }
    for(int s; s < 6; s++)
    {
        orderC[s] => int idx;
        sendActivate(idx, canonical[idx], 1);
        if(s < 5) 1::second => now;
    }

    // Late-section "more async" feel: keep response delays low.
    // High activation probability where supported (Parrot/Falcon).
    for(int slot; slot < 6; slot++)
    {
        sendParam(slot, 0, "delayMin", 0.0);   // Parrot
        sendParam(slot, 0, "delayMax", 0.2);
        sendParam(slot, 0, "probability", 0.98);
        sendParam(slot, 3, "delayMin", 0.0);   // Peacock
        sendParam(slot, 3, "delayMax", 0.2);
        sendParam(slot, 4, "delayMin", 0.0);   // Emu
        sendParam(slot, 4, "delayMax", 0.2);
        sendParam(slot, 5, "delayMin", 0.0);   // Falcon
        sendParam(slot, 5, "delayMax", 0.2);
        sendParam(slot, 5, "probability", 0.98);
    }

    int currentRoles[6];
    for(int i; i < 6; i++) canonical[i] => currentRoles[i];

    // After 30s in the canonical movement, begin periodic role shuffling.
    <<< "movement 12: canonical hold (30s)" >>>;
    30::second => now;
    <<< "movement 13: role shuffling (60s)" >>>;
    for(int cycle; cycle < 12; cycle++) // 12 * 5s = 60s
    {
        int shuffled[6];
        for(int i; i < 6; i++) currentRoles[i] => shuffled[i];
        for(5 => int i; i > 0; i--)
        {
            Math.random2(0, i) => int j;
            shuffled[i] => int t;
            shuffled[j] => shuffled[i];
            t => shuffled[j];
        }
        for(int slot; slot < 6; slot++)
        {
            if(shuffled[slot] != currentRoles[slot])
                sendActivate(slot, shuffled[slot], 1);
            shuffled[slot] => currentRoles[slot];

            // Maintain low-delay / high-activity behavior during shuffle.
            if(currentRoles[slot] == 0) // Parrot
            {
                sendParam(slot, 0, "delayMin", 0.0);
                sendParam(slot, 0, "delayMax", 0.2);
                sendParam(slot, 0, "probability", 0.98);
            }
            else if(currentRoles[slot] == 3) // Peacock
            {
                sendParam(slot, 3, "delayMin", 0.0);
                sendParam(slot, 3, "delayMax", 0.2);
            }
            else if(currentRoles[slot] == 4) // Emu
            {
                sendParam(slot, 4, "delayMin", 0.0);
                sendParam(slot, 4, "delayMax", 0.2);
            }
            else if(currentRoles[slot] == 5) // Falcon
            {
                sendParam(slot, 5, "delayMin", 0.0);
                sendParam(slot, 5, "delayMax", 0.2);
                sendParam(slot, 5, "probability", 0.98);
            }
        }
        5::second => now;
    }

    // Then deactivate in order: emu, falcon, parrot, peacock, albatross, parakeet.
    <<< "movement 14: ordered fade-out by role" >>>;
    for(int slot; slot < 6; slot++)
    {
        sendParam(slot, 1, "probability", 0.8);
    }
    int offOrder[6];
    4 => offOrder[0]; // emu
    5 => offOrder[1]; // falcon
    0 => offOrder[2]; // parrot
    3 => offOrder[3]; // peacock
    2 => offOrder[4]; // albatross
    1 => offOrder[5]; // parakeet
    for(int oi; oi < 6; oi++)
    {
        offOrder[oi] => int targetRole;
        for(int slot; slot < 6; slot++)
        {
            if(currentRoles[slot] == targetRole)
            {
                sendActivate(slot, targetRole, 0);
                -1 => currentRoles[slot];
                break;
            }
        }
        if(oi < 5) 5::second => now;
    }
    <<< "timeline complete: all agents deactivated" >>>;
}

spork ~ _conductorTimeline();

while(true)
{
    GG.nextFrame() => now;
}
