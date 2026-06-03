@import "smuck"

// Shared bing constants (OSC paths use /ds9/ prefix).
// Module globals below are for documentation only — use static accessor classes
// (RoleIds, OwlSlots, NumSlots, MidiCtl, ReservedMidi) from classes and functions
// in imported files; ChucK cannot read module globals across import boundaries.
8 => int NUM_AGENT_SLOTS;
0 => int ROLE_PARROT;
1 => int ROLE_PARAKEET;
2 => int ROLE_ALBATROSS;
3 => int ROLE_PEACOCK;
4 => int ROLE_EMU;
5 => int ROLE_FALCON;
6 => int ROLE_SWAN;
7 => int ROLE_OWL;

28 => int MIDI_TOGGLE;
29 => int MIDI_MOVEMENT_FIRST;
35 => int MIDI_MOVEMENT_LAST;
36 => int MIDI_CHAOS;

5 => int OWL_SLOT_B;
7 => int OWL_SLOT_A;

["Parrot", "Parakeet", "Albatross", "Peacock", "Emu", "Falcon", "Swan", "Owl"] @=> string ROLE_NAMES[];

// Static accessors — classes in imported files cannot read module globals above.
public class RoleIds
{
    fun static int parrot() { return 0; }
    fun static int parakeet() { return 1; }
    fun static int albatross() { return 2; }
    fun static int peacock() { return 3; }
    fun static int emu() { return 4; }
    fun static int falcon() { return 5; }
    fun static int swan() { return 6; }
    fun static int owl() { return 7; }

    fun static string name(int role)
    {
        if(role == 0) return "Parrot";
        if(role == 1) return "Parakeet";
        if(role == 2) return "Albatross";
        if(role == 3) return "Peacock";
        if(role == 4) return "Emu";
        if(role == 5) return "Falcon";
        if(role == 6) return "Swan";
        if(role == 7) return "Owl";
        return "off";
    }
}

public class OwlSlots
{
    fun static int b() { return 5; }
    fun static int a() { return 7; }
}

public class NumSlots
{
    fun static int count() { return 8; }
}

public class MidiCtl
{
    fun static int toggle() { return 28; }
    fun static int movementFirst() { return 29; }
    fun static int movementLast() { return 35; }
    fun static int chaos() { return 36; }
}

public class ReservedMidi
{
    fun static int isControl(int pitch)
    {
        if(pitch == MidiCtl.toggle()) return 1;
        if(pitch >= MidiCtl.movementFirst() && pitch <= MidiCtl.movementLast()) return 1;
        if(pitch == MidiCtl.chaos()) return 1;
        return 0;
    }
}

public class Conductor
{
    OscOut @ _out;
    string _addr;
    int _numSlots;
    9100 => int _portBase;
    9110 => int _cuePort;
    9111 => int _scenePort;
    9112 => int _feederPort;
    9113 => int _serverCtlPort;

    fun Conductor(OscOut @ out, string addr, int numSlots)
    {
        out @=> _out;
        addr => _addr;
        numSlots => _numSlots;
    }

    fun void sendActivate(int slot, int enabled)
    {
        _out.dest(_addr, _portBase + slot);
        _out.start("/ds9/control/activate");
        slot => _out.add;
        enabled => _out.add;
        _out.send();
    }

    fun void sendRole(int slot, int roleId)
    {
        _out.dest(_addr, _portBase + slot);
        _out.start("/ds9/control/setRole");
        slot => _out.add;
        roleId => _out.add;
        _out.send();
    }

    fun void sendListenTarget(int slot, int target)
    {
        _out.dest(_addr, _portBase + slot);
        _out.start("/ds9/control/setListenTarget");
        slot => _out.add;
        target => _out.add;
        _out.send();
    }

    fun void sendParam(int slot, string param, float value)
    {
        _out.dest(_addr, _portBase + slot);
        _out.start("/ds9/control/setParam");
        slot => _out.add;
        param => _out.add;
        value => _out.add;
        _out.send();
    }

    fun void sendTimbre(int slot, int timbreIndex)
    {
        sendParam(slot, "timbreIndex", timbreIndex $ float);
    }

    fun void sendCueAll(string text)
    {
        _out.dest(_addr, _cuePort);
        _out.start("/ds9/cue/text");
        0 => _out.add;
        text => _out.add;
        _out.send();
        <<< "CUE:", text >>>;
    }

    fun void sendSceneAnnounce(string title, string description)
    {
        _out.dest(_addr, _scenePort);
        _out.start("/ds9/scene/announce");
        title => _out.add;
        description => _out.add;
        _out.send();
    }

    fun void deactivateAll()
    {
        for(int i; i < _numSlots; i++)
        {
            sendPanic(i);
            sendActivate(i, 0);
        }
    }

    fun void sendPanic(int slot)
    {
        sendParam(slot, "panic", 1);
    }

    fun void sendPanicAll()
    {
        for(int i; i < _numSlots; i++)
            sendPanic(i);
    }

    fun void sendFeederPause(int paused)
    {
        _out.dest(_addr, _feederPort);
        _out.start("/ds9/control/feeder");
        paused => _out.add;
        _out.send();
    }

    fun void sendMidiForward(int enabled)
    {
        _out.dest(_addr, _serverCtlPort);
        _out.start("/ds9/control/midiForward");
        enabled => _out.add;
        _out.send();
    }
}
