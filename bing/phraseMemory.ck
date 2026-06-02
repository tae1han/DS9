@import "smuck"
@import "SMIR.ck"

// Ring buffer of recent human phrases (all stations keep one for role-fluid Owl recall).
public class PhraseMemory
{
    12 => int _cap;
    int _count;
    int _head;
    int _lastRecallWhich;
    SMIR _buf[12];

    fun PhraseMemory()
    {
    }

    fun void push(ezNote notes[])
    {
        if(notes == null || notes.size() == 0) return;
        _head % _cap => int idx;
        // SMIR.set() aliases the array; snapshot each phrase so the ring keeps distinct copies.
        ezNote snap[0];
        for(int i; i < notes.size(); i++)
        {
            ezNote n(notes[i].onset(), notes[i].beats(), notes[i].pitch(), notes[i].velocity());
            snap << n;
        }
        SMIR.finalizePhraseDurations(snap, 0.12, 0.35);
        _buf[idx].set(snap);
        _head + 1 => _head;
        if(_count < _cap) _count + 1 => _count;
    }

    fun ezNote[] recallRandom()
    {
        ezNote out[0];
        if(_count == 0) return out;
        Math.random2(0, _count - 1) => int which;
        if(_count > 1 && which == _lastRecallWhich)
            (which + 1) % _count => which;
        which => _lastRecallWhich;
        (_head - 1 - which + _cap * 8) % _cap => int idx;
        for(int i; i < _buf[idx].notes.size(); i++)
        {
            _buf[idx].notes[i] @=> ezNote n;
            ezNote c(n.onset(), n.beats(), n.pitch(), n.velocity());
            out << c;
        }
        return out;
    }

    fun void clear()
    {
        0 => _count;
        0 => _head;
        -1 => _lastRecallWhich;
    }

    fun int count() { return _count; }
    fun int lastRecallWhich() { return _lastRecallWhich; }
}
