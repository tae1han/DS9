// Automated cue timeline for eight-station sim (server :score).
// Edit sections here; mirror quick tests with tests/localSend.ck:scene:*.
@import "../conductor.ck"

public class ScoreMovements
{
    Conductor @ _c;
    int _n;

    fun ScoreMovements(Conductor @ c, int numSlots)
    {
        c @=> _c;
        numSlots => _n;
    }

    // Slot i → role i, with sensible default params per bird.
    fun void _assignStationRole(int slot)
    {
        slot => int role;
        _c.sendRole(slot, role);
        if(role == 0) // Parrot
            _c.sendParam(slot, "mode", 0);
        else if(role == 1) // Parakeet
            _c.sendParam(slot, "rtMode", 0);
        else if(role == 4) // Emu
            _c.sendParam(slot, "glideMode", 0);
        else if(role == 7) // Owl
            _c.sendParam(slot, "owlMode", 0);
    }

    fun void _assignStationRoleDevelop(int slot)
    {
        slot => int role;
        _c.sendRole(slot, role);
        if(role == 0) // Parrot
            _c.sendParam(slot, "mode", 1);
        else if(role == 1) // Parakeet
            _c.sendParam(slot, "rtMode", 1);
        else if(role == 4) // Emu
            _c.sendParam(slot, "glideMode", 0);
        else if(role == 7) // Owl
            _c.sendParam(slot, "owlMode", 0);
    }

    fun void _assignAllStations()
    {
        for(0 => int i; i < _n; i++)
            _assignStationRole(i);
    }

    fun void runTimeline()
    {
        _c.sendCueAll("DS10 — movement 1: eight roles (solo)");
        _c.sendSoloistCue("Sparse opening — one agent per station");

        _assignStationRole(0);
        _c.sendListenTarget(0, -1);
        _c.sendActivate(0, 1);
        6::second => now;

        for(1 => int i; i < _n; i++)
        {
            _assignStationRole(i);
            _c.sendListenTarget(i, -1);
            _c.sendActivate(i, 1);
            if(i < _n - 1) 2::second => now;
        }
        15::second => now;

        _c.sendCueAll("Movement 2 — forward chain (each bird echoes upstream)");
        _c.sendSoloistCue("Play phrases — chain will ripple");
        for(int i; i < _n; i++)
        {
            _assignStationRole(i);
            if(i == 0) _c.sendListenTarget(i, -1);
            else _c.sendListenTarget(i, i - 1);
            _c.sendActivate(i, 1);
        }
        25::second => now;

        _c.sendCueAll("Movement 3 — reverse develop chain");
        for(int i; i < _n; i++)
        {
            _assignStationRoleDevelop(i);
            _n - 1 - i => int listen;
            if(listen < 0) _c.sendListenTarget(i, -1);
            else _c.sendListenTarget(i, listen);
            _c.sendActivate(i, 1);
        }
        25::second => now;

        _c.sendCueAll("Movement 4 — parakeet harmonize + peacock rolls");
        _c.sendSoloistCue("Dense harmony — chordal material");
        for(int i; i < _n; i++)
        {
            _assignStationRole(i);
            if(i == 1) // Parakeet slot
                _c.sendParam(i, "rtMode", 1);
            _c.sendListenTarget(i, -1);
            _c.sendActivate(i, 1);
        }
        25::second => now;

        _c.sendCueAll("Movement 5 — albatross + emu");
        for(int i; i < _n; i++)
        {
            _assignStationRole(i);
            if(i == 4) // Emu slot
                _c.sendParam(i, "glideMode", 0);
            _c.sendListenTarget(i, -1);
            _c.sendActivate(i, 1);
        }
        20::second => now;

        _c.sendCueAll("Movement 6 — eddy window (Owl on slot 7)");
        _c.sendSoloistCue("Sparse — Owl seeds from memory");
        for(int i; i < _n; i++)
        {
            _c.sendParam(i, "eddiesEnabled", 1);
            _c.sendParam(i, "phraseOnlyEddies", 1);
        }
        for(int i; i < _n; i++)
        {
            _assignStationRole(i);
            if(i == 7) // Owl slot
            {
                _c.sendParam(i, "owlMode", 1);
                _c.sendParam(i, "quantizeRecall", 0);
            }
            _c.sendListenTarget(i, -1);
            _c.sendActivate(i, 1);
        }
        30::second => now;
        for(int i; i < _n; i++)
        {
            _c.sendParam(i, "eddiesEnabled", 0);
            _c.sendParam(i, "phraseOnlyEddies", 0);
            if(i == 7) // Owl slot
                _c.sendParam(i, "owlMode", 0);
        }

        _c.sendCueAll("Movement 7 — falcon + swan");
        for(int i; i < _n; i++)
        {
            _assignStationRole(i);
            _c.sendListenTarget(i, -1);
            _c.sendActivate(i, 1);
        }
        25::second => now;

        _c.sendCueAll("Movement 8 — fade");
        for(_n - 1 => int s; s >= 0; s--)
        {
            _c.sendActivate(s, 0);
            2::second => now;
        }
        _c.sendCueAll("End");
    }
}
