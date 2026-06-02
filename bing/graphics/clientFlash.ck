@import "smuck"

// Fullscreen flash: white until server link, black when linked, tinted white on activity.
public class ClientFlash extends GGen
{
    GPlane @ _plane;
    FlatMaterial @ _mat;
    24.0 => float decayPerSec;
    float _env;
    int _homeSlot;
    int _linked;
    float _tintR;
    float _tintG;
    float _tintB;

    fun void _setTintForRole(int role)
    {
        if(role == 0) { 1.0 => _tintR; 0.22 => _tintG; 0.22 => _tintB; }      // Parrot red
        else if(role == 1) { 0.25 => _tintR; 1.0 => _tintG; 0.3 => _tintB; } // Parakeet green
        else if(role == 2) { 0.25 => _tintR; 0.85 => _tintG; 1.0 => _tintB; } // Albatross cyan
        else if(role == 3) { 0.3 => _tintR; 0.45 => _tintG; 1.0 => _tintB; }  // Peacock blue
        else if(role == 4) { 0.65 => _tintR; 0.35 => _tintG; 0.95 => _tintB; } // Emu purple
        else if(role == 5) { 1.0 => _tintR; 0.95 => _tintG; 0.25 => _tintB; }  // Falcon yellow
        else if(role == 6) { 1.0 => _tintR; 0.55 => _tintG; 0.15 => _tintB; }  // Swan orange
        else if(role == 7) { 0.92 => _tintR; 0.86 => _tintG; 0.72 => _tintB; }  // Owl beige
        else { 1.0 => _tintR; 1.0 => _tintG; 1.0 => _tintB; }
    }

    fun ClientFlash(int homeSlot)
    {
        homeSlot => _homeSlot;
        _setTintForRole(homeSlot);

        FlatMaterial mat;
        @(1, 1, 1) => mat.color;
        mat @=> _mat;

        GPlane p --> GG.scene();
        p @=> _plane;
        _mat => _plane.material;
        p.pos(@(0, 0, 0));
        p.sca(@(48, 48, 1));
        0 => _env;
        0 => _linked;
        _apply();
    }

    fun void setLinked(int linked)
    {
        if(linked) 1 => _linked;
        else 0 => _linked;
        _apply();
    }

    fun void setRoleTint(int role)
    {
        _setTintForRole(role);
        _apply();
    }

    fun void trigger(float vel)
    {
        if(!_linked) return;
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
        if(!_linked) return;
        Math.exp(-decayPerSec * GG.dt()) => float k;
        _env * k => _env;
        _apply();
    }

    fun void _apply()
    {
        if(_mat == null) return;

        if(!_linked)
        {
            @(1, 1, 1) => _mat.color;
            return;
        }

        _env * 2.0 => float v;
        if(v < 0.004) 0.0 => v;

        if(v <= 0.0)
        {
            @(0, 0, 0) => _mat.color;
            return;
        }

        // Role tint on white flash (stronger than before).
        0.58 => float w;
        0.42 => float t;
        v * w + _tintR * v * t => float r;
        v * w + _tintG * v * t => float g;
        v * w + _tintB * v * t => float b;
        @(r, g, b) => _mat.color;
    }
}
