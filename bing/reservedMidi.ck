// Single source of truth for reserved control MIDI (literals — no import globals).
public class ReservedMidi
{
    fun static int isControl(int pitch)
    {
        if(pitch == 28) return 1;
        if(pitch >= 29 && pitch <= 35) return 1;
        return 0;
    }
}
