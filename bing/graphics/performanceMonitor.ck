@import "smuck"
@import "../conductor.ck"
@import "pulseGrid.ck"

// Server/read-only ChuGL monitor: movement title + pulse grid + slot roles.
public class PerformanceMonitor
{
    PulseGrid grid;
    GText titleText;
    GText descText;

    fun PerformanceMonitor()
    {
        _buildScene();
    }

    fun void setMovement(string title, string desc)
    {
        title => titleText.text;
        desc => descText.text;
    }

    fun void _buildScene()
    {
        FlatMaterial bgMat;
        @(0.06, 0.06, 0.08) => bgMat.color;
        GPlane bg --> GG.scene();
        bg.material(bgMat);
        bg.pos(@(0, 0, -1));
        bg.sca(@(48, 48, 1));

        grid --> GG.scene();
        titleText --> GG.scene();
        descText --> GG.scene();

        GG.camera().orthographic();
        @(0.55, 0.55, 0.6) => GG.scene().ambient;
        GG.bloom(true);
        GG.bloomPass().intensity(0.6);
        @(0, 0, 14) => GG.camera().pos;

        titleText.font("chugl:proggy-clean");
        titleText.size(.48);
        titleText.align(0);
        titleText.color(@(1, 1, 1));
        titleText.pos(@(0, 5.8, 0));
        "—" => titleText.text;

        descText.font("chugl:proggy-clean");
        descText.size(.22);
        descText.align(0);
        descText.color(@(.72, .72, .8));
        descText.pos(@(0, 5.0, 0));
        "MIDI 100=1A | 36=5 | 29–35=movements | 28=toggle" => descText.text;
    }

    fun void _statusListen()
    {
        OscIn statusIn;
        OscMsg msg;
        8889 => statusIn.port;
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
        8891 => pulseIn.port;
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

    fun void _sceneAnnounceListen()
    {
        OscIn sceneIn;
        OscMsg msg;
        9111 => sceneIn.port;
        sceneIn.addAddress("/ds9/scene/announce");
        while(true)
        {
            sceneIn => now;
            while(sceneIn.recv(msg))
            {
                setMovement(msg.getString(0), msg.getString(1));
            }
        }
    }

    fun void run(int listenSceneAnnounce)
    {
        spork ~ _statusListen();
        spork ~ _pulseListen();
        if(listenSceneAnnounce) spork ~ _sceneAnnounceListen();
        <<< "performanceMonitor — ChuGL active" >>>;
        while(true)
        {
            GG.nextFrame() => now;
            grid.tick();
        }
    }
}
