// GameTrak performance conductor (local-run :pad + local-autonomous + this).
//   ./scripts/local-gametrak
//   ./scripts/local-gametrak local 1       # device 1
//   ./scripts/local-gametrak local button:2
//
// Pedal 1 → chaos2 + feeder on (+ arms MIDI-mute on server :pad)
// First MIDI → mute (server :pad, only after pedal 1)
// Pedals 2–8 → movements 2–8; pedal 9 → solo

@import "ds10Config.ck"
@import "conductor.ck"
@import "conductorScenes.ck"

8 => int NUM_AGENT_SLOTS;
"224.0.0.1" => string MULTICAST_ADDR;
0 => int GT_DEVICE;
0 => int GT_BUTTON;
1 => int GT_VERBOSE;
1 => int _pedalReady;
0 => int _pedalAxisHeld;

for(0 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "b0") 0 => GT_BUTTON;
    else if(a == "b1") 1 => GT_BUTTON;
    else if(a == "b2") 2 => GT_BUTTON;
    else if(a == "b3") 3 => GT_BUTTON;
    else if(a == "verbose") 1 => GT_VERBOSE;
    else if(a == "quiet") 0 => GT_VERBOSE;
    else Std.atoi(a) => GT_DEVICE;
}

OscOut controlOut;
Conductor conductor(controlOut, MULTICAST_ADDR, NUM_AGENT_SLOTS);
ConductorScenes scenes(conductor, NUM_AGENT_SLOTS);

0 => int _step;
Event _pedal;

Hid trak;
HidMsg msg;
if(!trak.openJoystick(GT_DEVICE))
{
    <<< "GameTrak: could not open joystick", GT_DEVICE, "— try :1 or list devices" >>>;
    me.exit();
}
<<< "GameTrak:", trak.name(), "| device", GT_DEVICE, "| pedal = button", GT_BUTTON,
    "(or Z axis pull)" >>>;

fun int _axisPedalDown(HidMsg m)
{
    if(!m.isAxisMotion()) return 0;
    if(m.which != 2 && m.which != 5) return 0;
    1 - ((m.axisPosition + 1) / 2) => float z;
  // Foot pedal pulls tether Z inward on many units.
    return (z > 0.82);
}

fun void _pedalDown()
{
    if(!_pedalReady) return;
    _pedal.broadcast();
}

fun void _hidListen()
{
    while(true)
    {
        trak => now;
        while(trak.recv(msg))
        {
            if(msg.isButtonDown())
            {
                if(GT_VERBOSE)
                    <<< "GameTrak button", msg.which, "down" >>>;
                if(msg.which == GT_BUTTON)
                    _pedalDown();
            }
            else if(_axisPedalDown(msg))
            {
                if(!_pedalAxisHeld)
                {
                    1 => _pedalAxisHeld;
                    if(GT_VERBOSE) <<< "GameTrak pedal (axis", msg.which, ") down" >>>;
                    _pedalDown();
                }
            }
            else if(msg.isAxisMotion() && (msg.which == 2 || msg.which == 5))
            {
                if(!_axisPedalDown(msg))
                    0 => _pedalAxisHeld;
            }
        }
    }
}

fun void _keyboardFallback()
{
    Hid kb;
    HidMsg km;
    if(!kb.openKeyboard(0)) return;
    <<< "GameTrak: keyboard fallback — press 1–9 for pedals (1=chaos)" >>>;
    while(true)
    {
        kb => now;
        while(kb.recv(km))
        {
            if(!km.isButtonDown()) continue;
            km.ascii => int c;
            if(c >= 49 && c <= 57)
            {
                <<< "keyboard pedal", (c - 48) >>>;
                _pedalDown();
            }
        }
    }
}

fun void _advance()
{
    // Ignore HID chatter during open; first physical press = pedal 1.
    1.2::second => now;
    1 => _pedalReady;
    <<< "GameTrak: waiting for pedal 1 (current movement: idle)" >>>;

    while(true)
    {
        _pedal => now;
        200::ms => now;

        _step++;
        <<< ">>> PEDAL", _step, "pressed" >>>;
        if(_step == 1)
            spork ~ scenes.applyChaos2();
        else if(_step == 2)
            scenes.applyMovement2(7, 5);
        else if(_step == 3)
            scenes.applyMovement3(7, 5, 0, 4, 1, 3);
        else if(_step == 4)
            scenes.applyMovement4(6, 0, 2, 4);
        else if(_step == 5)
            scenes.applyMovement5();
        else if(_step == 6)
            scenes.applyMovement6();
        else if(_step == 7)
            scenes.applyMovement7();
        else if(_step == 8)
            scenes.applyMovement8();
        else if(_step == 9)
            scenes.applySoloMode(7, 5);
        else
            <<< ">>> pedal", _step, "(no scene mapped)" >>>;

        if(_step == 1)
            <<< ">>> (after chaos2 finishes: play MIDI for MUTE, then pedal 2)" >>>;
        else
            <<< ">>> now:", scenes.currentMovement() >>>;
    }
}

spork ~ _hidListen();
spork ~ _keyboardFallback();
spork ~ _advance();

<<< "GameTrak ready — pedal 1 in ~1.2s | 1=chaos | MIDI=mute | 2–8=mvts | 9=solo" >>>;
<<< "  Log: .local-logs/gametrak.log | keyboard: keys 1–9 (one step each)" >>>;

while(true) 1::second => now;
