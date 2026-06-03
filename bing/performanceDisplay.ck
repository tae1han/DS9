// Read-only performance monitor: movement title + slot pulse grid + role labels.
@import "conductor.ck"
@import "graphics/pulseGrid.ck"

"224.0.0.1" => string MULTICAST_ADDR;
8889 => int STATUS_PORT;
8891 => int PULSE_PORT;
9111 => int SCENE_PORT;

for(0 => int i; i < me.args(); i++)
{
    if(me.arg(i) == "local") "127.0.0.1" => MULTICAST_ADDR;
}

PulseGrid grid;
GText titleText;
GText descText;

grid --> GG.scene();
titleText --> GG.scene();
descText --> GG.scene();

GG.camera().orthographic();
@(1, 1, 1) => GG.scene().ambient;
GG.bloom(true);
GG.bloomPass().intensity(0.6);
@(0, 0, 14) => GG.camera().pos;

titleText.font("chugl:proggy-clean");
titleText.size(.38);
titleText.color(@(.95, .95, 1));
titleText.pos(@(0, 5.2, 0));
"Performance monitor" => titleText.text;

descText.font("chugl:proggy-clean");
descText.size(.22);
descText.color(@(.7, .7, .78));
descText.pos(@(0, 4.5, 0));
"MIDI 36=1A/5 | 29–35=movements | 28=toggle" => descText.text;

fun void _sceneAnnounceListen()
{
    OscIn sceneIn;
    OscMsg msg;
    sceneIn.port(SCENE_PORT);
    sceneIn.addAddress("/ds9/scene/announce");
    while(true)
    {
        sceneIn => now;
        while(sceneIn.recv(msg))
        {
            msg.getString(0) => string t;
            msg.getString(1) => string d;
            t => titleText.text;
            d => descText.text;
        }
    }
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
            msg.getInt(1) => int role;
            msg.getInt(4) => int enabled;
            grid.setSlotStatus(slot, enabled, role);
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

spork ~ _sceneAnnounceListen();
spork ~ _statusListen();
spork ~ _pulseListen();

<<< "performanceDisplay — read-only | OSC", MULTICAST_ADDR >>>;

while(true)
{
    GG.nextFrame() => now;
    grid.tick();
}
