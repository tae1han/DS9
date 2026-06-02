// ChuGL studio conductor — local 8-slot sim without GameTrak.
// Usage: chuck studioConductor.ck[:local]
//   Run via ./scripts/local-studio or ./scripts/studio-gui

@import "ds10Config.ck"
@import "conductor.ck"
@import "conductorScenes.ck"
@import "roleGains.ck"
@import "graphics/studioGrid.ck"

8 => int NUM_SLOTS;
0 => int ROLE_PARROT;
1 => int ROLE_PARAKEET;
4 => int ROLE_EMU;
7 => int ROLE_OWL;

["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon", "Swan", "Owl"] @=> string ROLE_NAMES[];
"224.0.0.1" => string MULTICAST_ADDR;
8889 => int STATUS_PORT;
8891 => int PULSE_PORT;

for(0 => int i; i < me.args(); i++)
{
    if(me.arg(i) == "local") "127.0.0.1" => MULTICAST_ADDR;
}

OscOut controlOut;
Conductor cond(controlOut, MULTICAST_ADDR, NUM_SLOTS);
ConductorScenes scenes(cond, NUM_SLOTS);
RoleGains roleGains;
0 => int _movement2Busy;

UI_Bool slotActive[8];
UI_Int slotRole[8];
UI_Int slotListen[8];
UI_Float slotGain[8];
UI_Float slotProb[8];
UI_Int slotMode[8];

UI_Bool feederPaused(1);
UI_Bool midiForward(1);

["Human", "Slot 0", "Slot 1", "Slot 2", "Slot 3",
 "Slot 4", "Slot 5", "Slot 6", "Slot 7"] @=> string LISTEN_ITEMS[];

["Echo", "Develop"] @=> string PARROT_MODES[];
["Mirror", "Harmonize"] @=> string PARAKEET_MODES[];
["Bassline", "Glide"] @=> string EMU_MODES[];
["Echo", "Seed"] @=> string OWL_MODES[];

for(0 => int s; s < NUM_SLOTS; s++)
{
    UI_Bool act(0) @=> slotActive[s];
    UI_Int role(s) @=> slotRole[s];
    UI_Int listen(0) @=> slotListen[s];
    roleGains.performance(s) => float g;
    UI_Float gain(g) @=> slotGain[s];
    UI_Float prob(1.0) @=> slotProb[s];
    UI_Int mode(0) @=> slotMode[s];
}

StudioGrid grid;
grid --> GG.scene();
GG.camera().orthographic();
@(1, 1, 1) => GG.scene().ambient;
GG.bloom(true);
GG.bloomPass().intensity(0.6);
@(0, 0, 14) => GG.camera().pos;

fun int _listenFromIdx(int idx)
{
    if(idx <= 0) return -1;
    return idx - 1;
}

fun int _idxFromListen(int target)
{
    if(target < 0) return 0;
    return target + 1;
}

fun float _presetGain(int role)
{
    return roleGains.performance(role);
}

fun void _syncSlotGain(int s)
{
    slotRole[s].val() => int r;
    slotGain[s].val(_presetGain(r));
}

fun void _syncAllGains()
{
    for(0 => int s; s < NUM_SLOTS; s++)
        _syncSlotGain(s);
}

fun void _triggerMovement2()
{
    if(_movement2Busy) return;
    1 => _movement2Busy;
    scenes.applyMovement2(7, 5);
    0 => _movement2Busy;
}

fun void _sendModeParam(int s)
{
    slotRole[s].val() => int r;
    slotMode[s].val() => int m;
    if(r == ROLE_PARROT) cond.sendParam(s, "mode", m $ float);
    else if(r == ROLE_PARAKEET) cond.sendParam(s, "rtMode", m $ float);
    else if(r == ROLE_EMU) cond.sendParam(s, "glideMode", m $ float);
    else if(r == ROLE_OWL) cond.sendParam(s, "owlMode", m $ float);
}

fun void _applySlot(int s, int forceOffOn)
{
    // forceOffOn: 0 = respect checkbox, 1 = always activate after setup
    cond.sendActivate(s, 0);
    cond.sendRole(s, slotRole[s].val());
    cond.sendListenTarget(s, _listenFromIdx(slotListen[s].val()));
    cond.sendParam(s, "roleGain", slotGain[s].val());
    cond.sendParam(s, "probability", slotProb[s].val());
    _sendModeParam(s);

    if(forceOffOn || slotActive[s].val())
        cond.sendActivate(s, 1);
    else
        cond.sendActivate(s, 0);
}

fun void _applyGain(int s)
{
    cond.sendParam(s, "roleGain", slotGain[s].val());
}

fun void _applyProb(int s)
{
    cond.sendParam(s, "probability", slotProb[s].val());
}

fun void _applyListen(int s)
{
    cond.sendListenTarget(s, _listenFromIdx(slotListen[s].val()));
}

fun void _applyMode(int s)
{
    _sendModeParam(s);
}

fun void _toggleActive(int s)
{
    if(slotActive[s].val()) _applySlot(s, 1);
    else cond.sendActivate(s, 0);
}

fun void _resetBaseline(int s)
{
    cond.sendParam(s, "resetBaseline", 1);
    slotGain[s].val(roleGains.performance(slotRole[s].val()));
    _applyGain(s);
}

fun void _slotLabel(int s)
{
    if(s == 0) UI.text("Slot 0");
    else if(s == 1) UI.text("Slot 1");
    else if(s == 2) UI.text("Slot 2");
    else if(s == 3) UI.text("Slot 3");
    else if(s == 4) UI.text("Slot 4");
    else if(s == 5) UI.text("Slot 5");
    else if(s == 6) UI.text("Slot 6");
    else UI.text("Slot 7");
}

fun void _roleLabel(int r)
{
    if(r == 0) UI.text("Parrot");
    else if(r == 1) UI.text("Parakeet");
    else if(r == 2) UI.text("Albatross");
    else if(r == 3) UI.text("Peacock");
    else if(r == 4) UI.text("Emu");
    else if(r == 5) UI.text("Falcon");
    else if(r == 6) UI.text("Swan");
    else UI.text("Owl");
}

fun void _drawSlot(int s)
{
    UI.separator();
    _slotLabel(s);

    UI.pushID(s);
    _roleLabel(slotRole[s].val());

    if(UI.checkbox("Active", slotActive[s]))
        _toggleActive(s);

    if(UI.combo("Role", slotRole[s], ROLE_NAMES))
    {
        _syncSlotGain(s);
        slotMode[s].val(0);
        if(slotActive[s].val()) _applySlot(s, 1);
    }

    if(UI.combo("Listen", slotListen[s], LISTEN_ITEMS))
    {
        if(slotActive[s].val()) _applyListen(s);
    }

    if(UI.slider("Gain", slotGain[s], 0.0, 6.0))
        _applyGain(s);

    if(UI.slider("Probability", slotProb[s], 0.0, 1.0))
        _applyProb(s);

    slotRole[s].val() => int r;
    if(r == ROLE_PARROT)
    {
        if(UI.combo("Mode", slotMode[s], PARROT_MODES) && slotActive[s].val())
            _applyMode(s);
    }
    else if(r == ROLE_PARAKEET)
    {
        if(UI.combo("Mode", slotMode[s], PARAKEET_MODES) && slotActive[s].val())
            _applyMode(s);
    }
    else if(r == ROLE_EMU)
    {
        if(UI.combo("Mode", slotMode[s], EMU_MODES) && slotActive[s].val())
            _applyMode(s);
    }
    else if(r == ROLE_OWL)
    {
        if(UI.combo("Mode", slotMode[s], OWL_MODES) && slotActive[s].val())
            _applyMode(s);
    }

    if(UI.button("Apply slot"))
        _applySlot(s, slotActive[s].val());

    if(UI.button("Reset baseline"))
        _resetBaseline(s);

    UI.popID();
}

fun void _drawMovements()
{
    if(!UI.begin("Movements")) return;

    UI.text("Performance arc (same as GameTrak pedals 1–9):");
    if(UI.button("Chaos2 + feeder"))
        spork ~ scenes.applyChaos2();
    if(UI.button("Movement 2 — Owl")) _triggerMovement2();
    if(UI.button("Movement 3 — Parrots/Pkts")) scenes.applyMovement3(7, 5, 0, 4, 1, 3);
    if(UI.button("Movement 4 — Peacock/Swan")) scenes.applyMovement4(6, 0, 2, 4);
    if(UI.button("Movement 5 — Emu + Albatross")) scenes.applyMovement5();
    if(UI.button("Movement 6 — All Falcon")) scenes.applyMovement6();
    if(UI.button("Movement 7 — Eight roles"))
        scenes.applyMovement7();
    if(UI.button("Movement 8 — Parakeet fade")) scenes.applyMovement8();
    if(UI.button("Solo — Owl seed")) scenes.applySoloMode(7, 5);

    UI.separator();
    UI.text("Other presets:");
    if(UI.button("M1 baseline"))
        scenes.applyM1();
    if(UI.button("Chaos (max)"))
        scenes.applyChaos();
    if(UI.button("Mute all")) scenes.applyMute();
    if(UI.button("All Parrot echo")) scenes.applyAllParrotEcho();

    UI.separator();
    if(UI.checkbox("Feeder paused", feederPaused))
        cond.sendFeederPause(feederPaused.val());

    if(UI.checkbox("MIDI forward", midiForward))
        cond.sendMidiForward(midiForward.val());

    if(UI.button("Deactivate all"))
    {
        cond.deactivateAll();
        for(0 => int s; s < NUM_SLOTS; s++)
        {
            slotActive[s].val(0);
            grid.setActive(s, 0);
        }
    }

    if(UI.button("Default layout (slot i = role i)"))
    {
        for(0 => int s; s < NUM_SLOTS; s++)
        {
            slotRole[s].val(s);
            slotListen[s].val(0);
            slotProb[s].val(1.0);
            slotMode[s].val(0);
            slotActive[s].val(0);
            grid.setActive(s, 0);
        }
    }

    UI.end();
}

fun void _drawSlots()
{
    if(!UI.begin("Slots")) return;

    for(0 => int s; s < NUM_SLOTS; s++)
        _drawSlot(s);

    UI.end();
}

fun void _syncFromStatus(int slot, int activeRole, int enabled, int listenTarget)
{
    if(slot < 0 || slot >= NUM_SLOTS) return;

    if(activeRole >= 0 && enabled)
    {
        slotActive[slot].val(1);
        slotRole[slot].val(activeRole);
        slotGain[slot].val(_presetGain(activeRole));
        grid.setActive(slot, 1);
    }
    else
    {
        slotActive[slot].val(0);
        grid.setActive(slot, 0);
    }

    slotListen[slot].val(_idxFromListen(listenTarget));
}

fun void _statusListen()
{
    OscIn statusIn;
    OscMsg msg;
    STATUS_PORT => statusIn.port;
    statusIn.addAddress("/ds9/status");

    while(true)
    {
        statusIn => now;
        while(statusIn.recv(msg))
        {
            msg.getInt(0) => int slot;
            msg.getInt(1) => int activeRole;
            msg.getInt(4) => int enabled;
            msg.getInt(5) => int listenTarget;
            _syncFromStatus(slot, activeRole, enabled, listenTarget);
        }
    }
}

fun void _pulseListen()
{
    OscIn pulseIn;
    OscMsg msg;
    PULSE_PORT => pulseIn.port;
    pulseIn.addAddress("/ds9/pulse");

    while(true)
    {
        pulseIn => now;
        while(pulseIn.recv(msg))
        {
            msg.getInt(0) => int slot;
            msg.getFloat(1) => float vel;
            grid.triggerPulse(slot, vel);
        }
    }
}

spork ~ _statusListen();
spork ~ _pulseListen();

cond.sendFeederPause(1);
cond.sendMidiForward(1);

<<< "DS10 Studio conductor ready — OSC to", MULTICAST_ADDR >>>;
<<< "  Movements + per-slot controls in ChuGL windows" >>>;
<<< "  Pulse grid reacts to agent notes on /ds9/pulse" >>>;

while(true)
{
    GG.nextFrame() => now;
    grid.tick();
    _drawMovements();
    _drawSlots();
}
