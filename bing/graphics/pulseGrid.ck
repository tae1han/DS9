@import "smuck"
@import "../conductor.ck"

// Eight-slot pulse grid + role label per cell (read-only monitor).
public class PulseGrid extends GGen
{
    8 => int NUM_SLOTS;
    .82 => float DECAY;

    GCircle _disc[8];
    GCircle _frame[8];
    GText _slotLabel[8];
    GText _roleLabel[8];
    float _env[8];
    vec3 _colors[8];
    int _active[8];
    int _roles[8];

    fun PulseGrid()
    {
        for(0 => int i; i < NUM_SLOTS; i++)
        {
            -1 => _roles[i];
            Color.hsv2rgb(@(((i $ float) * 45.0) % 360.0, 0.75, 0.55)) => _colors[i];
        }
        _buildCells();
    }

    fun void _buildCells()
    {
        for(0 => int i; i < NUM_SLOTS; i++)
        {
            0 => _active[i];
            GCircle frame --> GG.scene();
            frame @=> _frame[i];
            frame.pos(_cellPos(i));
            frame.sca(@(1.35, 1.35, 1));
            @(0.12, 0.12, 0.14) => frame.color;

            GCircle c --> GG.scene();
            c @=> _disc[i];
            c.pos(_cellPos(i));
            c.sca(@(1.15, 1.15, 1));
            0 => _env[i];
            _applyCell(i);

            GText sl --> GG.scene();
            sl @=> _slotLabel[i];
            sl.font("chugl:proggy-clean");
            sl.size(.22);
            sl.color(@(.85, .85, .9));
            sl.pos(_cellPos(i) + @(0, -.75, 0));
            ("S" + i) => sl.text;

            GText rl --> GG.scene();
            rl @=> _roleLabel[i];
            rl.font("chugl:proggy-clean");
            rl.size(.18);
            rl.color(@(.65, .65, .72));
            rl.pos(_cellPos(i) + @(0, -1.05, 0));
            "off" => rl.text;
        }
    }

    fun vec3 _cellPos(int slot)
    {
        slot % 4 => int col;
        Math.floor(slot / 4.0) $ int => int row;
        col * 3.1 - 4.65 => float x;
        row * 3.35 - 1.675 => float y;
        return @(x, y, 0.5);
    }

    fun void setSlotStatus(int slot, int active, int role)
    {
        if(slot < 0 || slot >= NUM_SLOTS) return;
        active => _active[slot];
        role => _roles[slot];
        _applyCell(slot);
        if(active && role >= 0 && role <= 7)
            RoleIds.name(role) => _roleLabel[slot].text;
        else
            "off" => _roleLabel[slot].text;
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
