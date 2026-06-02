@import "smuck"
@import {"smuck", "smuck/ezFluidInst.ck"}

// TimGM monitor for server.ck — same as ezFluidInst but skips reserved MIDI in noteOn/noteOff.
public class SlorkPianoMonitorInst extends ezFluidInst
{
    int _reserved[0];

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

    fun void setReservedPitches(int pitches[])
    {
        pitches.size() => int n;
        int copy[n];
        for(int i; i < n; i++)
            pitches[i] => copy[i];
        copy @=> _reserved;
    }

    fun int[] reservedPitches()
    {
        return _reserved;
    }

    fun int isReserved(int pitch)
    {
        for(int i; i < _reserved.size(); i++)
            if(_reserved[i] == pitch) return 1;
        return 0;
    }

    fun void noteOn(ezNote note, int voice)
    {
        note.pitch() $ int => int p;
        if(isReserved(p)) return;
        fs.noteOn(p, (note.velocity() * 127) $ int, 0);
    }

    fun void noteOff(ezNote note, int voice)
    {
        note.pitch() $ int => int p;
        if(isReserved(p)) return;
        fs.noteOff(p, 0);
    }
}
