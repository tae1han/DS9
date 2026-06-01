@import "smuck"

// Per-client fullscreen flash: black at rest, white on local agent note activity.
public class ClientFlash extends GGen
{
    GPlane @ _plane;
    FlatMaterial @ _mat;
    24.0 => float decayPerSec; // higher = shorter tail (better for fast notes)
    float _env;
    int _homeSlot;

    fun ClientFlash(int homeSlot)
    {
        homeSlot => _homeSlot;

        FlatMaterial mat;
        @(0, 0, 0) => mat.color;
        mat @=> _mat;

        GPlane p --> GG.scene();
        p @=> _plane;
        _mat => _plane.material;
        p.pos(@(0, 0, 0));
        p.sca(@(48, 48, 1));
        0 => _env;
        _apply();
    }

    fun void trigger(float vel)
    {
        // Fast attack: each note retriggers a full peak, then tick() decays.
        1.0 => float peak;
        if(vel > 0.05 && vel < peak) vel => peak;
        if(peak > _env) peak => _env;
    }

    fun void triggerPulse(int slot, float vel)
    {
        if(slot == _homeSlot) trigger(vel);
    }

    fun void tick()
    {
        Math.exp(-decayPerSec * GG.dt()) => float k;
        _env * k => _env;
        _apply();
    }

    fun void _apply()
    {
        if(_mat == null) return;

        _env * 2.0 => float v;
        if(v < 0.004) 0.0 => v;
        @(v, v, v) => _mat.color;
    }
}
