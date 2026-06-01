@import "smuck"

// Eight-slot pulse grid for the studio conductor (reacts to /ds9/pulse).
public class StudioGrid extends GGen
{
    8 => int NUM_SLOTS;
    .82 => float DECAY;

    GCircle _disc[8];
    GCircle _frame[8];
    GText _label[8];
    float _env[8];
    vec3 _colors[8];
    int _active[8];

    fun StudioGrid()
    {
        _buildCells();
    }

    fun void _buildCells()
    {
        for(0 => int i; i < NUM_SLOTS; i++)
        {
            Color.hsv2rgb(@(((i $ float) * 45.0) % 360.0, 0.75, 0.55)) => _colors[i];
            0 => _active[i];

            GCircle frame --> GG.scene();
            frame @=> _frame[i];
            frame.pos(_cellPos(i));
            frame.sca(@(1.35, 1.35, 1));
            @(0.12, 0.12, 0.14) => vec3 dim;
            dim => frame.color;

            GCircle c --> GG.scene();
            c @=> _disc[i];
            c.pos(_cellPos(i));
            c.sca(@(1.15, 1.15, 1));
            0 => _env[i];
            _applyCell(i);

            GText lbl --> GG.scene();
            lbl @=> _label[i];
            lbl.font("chugl:proggy-clean");
            lbl.size(.22);
            lbl.color(@(.85, .85, .9));
            lbl.pos(_cellPos(i) + @(0, -.95, 0));
            ("S" + i) => lbl.text;
        }
    }

    fun vec3 _cellPos(int slot)
    {
        slot % 4 => int col;
        Math.floor(slot / 4.0) $ int => int row;
        col * 3.4 - 5.1 => float x;
        row * 3.0 - 1.5 => float y;
        return @(x, y, 0.5);
    }

    fun void setActive(int slot, int on)
    {
        if(slot < 0 || slot >= NUM_SLOTS) return;
        on => _active[slot];
        _applyCell(slot);
    }

    fun void triggerPulse(int slot, float vel)
    {
        if(slot < 0 || slot >= NUM_SLOTS) return;
        if(vel > _env[slot]) vel => _env[slot];
    }

    fun void tick()
    {
        for(0 => int i; i < NUM_SLOTS; i++)
        {
            _env[i] * DECAY => _env[i];
            _applyCell(i);
        }
    }

    fun void _applyCell(int i)
    {
        _colors[i] * _env[i] => vec3 c;
        if(_env[i] < 0.04)
        {
            if(_active[i]) _colors[i] * 0.18 => c;
            else @(0.08, 0.08, 0.1) => c;
        }
        c => _disc[i].color;

        if(_active[i]) @(0.35, 0.35, 0.42) => _frame[i].color;
        else @(0.12, 0.12, 0.14) => _frame[i].color;
    }
}
