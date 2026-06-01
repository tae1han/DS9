@import "ds10Config.ck"
@import "smuck"

public class Conductor
{
    OscOut @ _out;
    string _addr;
    int _numSlots;
    9100 => int _portBase;
    9110 => int _cuePort;
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

    fun void sendSoloistCue(string text)
    {
        <<< "SOLOIST:", text >>>;
    }

    fun void sendTriggerPhrase(int slot, ezNote notes[])
    {
        _out.dest(_addr, _portBase + slot);
        _out.start("/ds9/control/triggerPhrase");
        slot => _out.add;
        notes.size() => _out.add;
        for(int i; i < notes.size(); i++)
        {
            notes[i].pitch() $ int => _out.add;
            notes[i].velocity() => _out.add;
            notes[i].beats() => _out.add;
            notes[i].onset() => _out.add;
        }
        _out.send();
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

    // Tell server.ck to forward (or block) human MIDI / phrases to client buffers.
    fun void sendMidiForward(int enabled)
    {
        _out.dest(_addr, _serverCtlPort);
        _out.start("/ds9/control/midiForward");
        enabled => _out.add;
        _out.send();
    }

}
