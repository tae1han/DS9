@import "smuck"
@import {"smuck", "smuck/ezFluidInst.ck"}
@import "../conductor.ck"

// TimGM monitor — never sounds on MIDI 28–36 (reserved control keys in conductor.ck).
public class SlorkPianoMonitorInst extends ezFluidInst
{
    fun int _isControl(int pitch)
    {
        return ReservedMidi.isControl(pitch);
    }
    fun SlorkPianoMonitorInst()
    {
    }

    fun SlorkPianoMonitorInst(string filename)
    {
        open(filename);
        progChange(0);
    }

    fun SlorkPianoMonitorInst(string filename, int instrument)
    {
        open(filename);
        progChange(instrument);
    }

    fun void silencePitch(int pitch)
    {
        fs.noteOff(pitch, 0);
    }

    fun void noteOn(ezNote note, int voice)
    {
        note.pitch() $ int => int p;
        if(_isControl(p)) return;
        fs.noteOn(p, (note.velocity() * 127) $ int, 0);
    }

    fun void noteOff(ezNote note, int voice)
    {
        note.pitch() $ int => int p;
        if(_isControl(p)) return;
        fs.noteOff(p, 0);
    }
}
