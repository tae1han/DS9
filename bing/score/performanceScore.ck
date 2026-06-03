@import "../conductor.ck"
@import "../graphics/monitor.ck"
@import "roleConfig.ck"

// Performance score — mirrors score/composition.txt. Single server-owned scene engine.
public class PerformanceScore
{
    Conductor @ _c;
    Monitor @ _monitor;
    RoleConfig _roles;
    int _n;
    int _gen;
    int _toggleArmed;   // 0 none, 1 = 2C, 2 = 3B
    int _toggleOn;      // 1 = ON (chain), 0 = OFF (human listen)
    int _padAfterChaosReady;

    fun PerformanceScore(Conductor @ c, int numSlots, Monitor @ monitor)
    {
        c @=> _c;
        monitor @=> _monitor;
        numSlots => _n;
        0 => _gen;
        0 => _toggleArmed;
        1 => _toggleOn;
        0 => _padAfterChaosReady;
    }

    fun int bumpGen()
    {
        _gen++;
        0 => _toggleArmed;
        0 => _padAfterChaosReady;
        return _gen;
    }

    fun void disarmToggle()
    {
        0 => _toggleArmed;
    }

    fun int padAfterChaosReady() { return _padAfterChaosReady; }

    fun void _announce(string title, string desc)
    {
        <<< "==========", title, "==========" >>>;
        <<< desc >>>;
        if(_monitor != null) _monitor.setMovement(title, desc);
        _c.sendSceneAnnounce(title, desc);
        _c.sendCueAll(title);
    }

    fun void _slotOff(int slot)
    {
        if(slot < 0 || slot >= _n) return;
        _c.sendPanic(slot);
        _c.sendActivate(slot, 0);
    }

    fun void _slotOn(int slot, int role, float gain, int listen)
    {
        if(slot < 0 || slot >= _n) return;
        _c.sendRole(slot, role);
        _roles.sendBaseline(_c, slot, role);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _owlSeed(int slot, float gain, int listen)
    {
        if(slot < 0 || slot >= _n) return;
        _c.sendRole(slot, RoleIds.owl());
        _c.sendParam(slot, "owlMode", 1);
        _c.sendParam(slot, "eddiesEnabled", 1);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "seedProb", 0.72);
        _c.sendParam(slot, "quantizeRecall", 0);
        _c.sendParam(slot, "seedCooldownMs", 200);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _owlDevelop(int slot, float gain, int listen)
    {
        if(slot < 0 || slot >= _n) return;
        _c.sendRole(slot, RoleIds.owl());
        _c.sendParam(slot, "owlMode", 0);
        _c.sendParam(slot, "eddiesEnabled", 0);
        _c.sendParam(slot, "phraseOnlyEddies", 1);
        _c.sendParam(slot, "seedProb", 0.5);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _parrotEcho(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.parrot());
        _c.sendParam(slot, "mode", 0);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "delayMin", 0.25);
        _c.sendParam(slot, "delayMax", 1.5);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _parrotDevelop(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.parrot());
        _c.sendParam(slot, "mode", 1);
        _c.sendParam(slot, "developTechnique", -1);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "delayMin", 0.25);
        _c.sendParam(slot, "delayMax", 1.5);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _swan(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.swan());
        _roles.sendBaseline(_c, slot, RoleIds.swan());
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _peacock(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.peacock());
        _roles.sendBaseline(_c, slot, RoleIds.peacock());
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _parakeetMirror(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.parakeet());
        _c.sendParam(slot, "rtMode", 0);
        _c.sendParam(slot, "polyphony", 1);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _parakeetHarmonize(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.parakeet());
        _c.sendParam(slot, "rtMode", 1);
        _c.sendParam(slot, "polyphony", 1);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _albatross(int slot, float gain, int listen)
    {
        _slotOn(slot, RoleIds.albatross(), gain, listen);
    }

    fun void _emuGlide(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.emu());
        _roles.sendBaseline(_c, slot, RoleIds.emu());
        _c.sendParam(slot, "glideMode", 1);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _emuBass(int slot, float gain, int listen)
    {
        _c.sendRole(slot, RoleIds.emu());
        _roles.sendBaseline(_c, slot, RoleIds.emu());
        _c.sendParam(slot, "glideMode", 0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, listen);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _falconPreset(int slot, float gain, int nMin, int nMax,
        float sMin, float sMax, float jitter, int lo, int hi)
    {
        _c.sendRole(slot, RoleIds.falcon());
        _roles.sendBaseline(_c, slot, RoleIds.falcon());
        _c.sendParam(slot, "numNotesMin", nMin);
        _c.sendParam(slot, "numNotesMax", nMax);
        _c.sendParam(slot, "stepMsMin", sMin);
        _c.sendParam(slot, "stepMsMax", sMax);
        _c.sendParam(slot, "stepJitterMs", jitter);
        _c.sendParam(slot, "lowMidi", lo $ float);
        _c.sendParam(slot, "highMidi", hi $ float);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "roleGain", gain);
        _c.sendListenTarget(slot, -1);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _clearAllMemory()
    {
        for(int s; s < _n; s++)
            _c.sendParam(s, "clearMemory", 1);
    }

    fun void applyPadBreak(int forPostChaos)
    {
        bumpGen();
        _c.sendFeederPause(1);
        _c.sendMidiForward(0);
        _c.sendPanicAll();
        for(int s; s < _n; s++)
        {
            _c.sendActivate(s, 0);
            _c.sendParam(s, "clearMemory", 1);
        }
        if(forPostChaos)
            _announce("Movement 5 end - human solo", "All agents off; phrase memory cleared");
        else
            _announce("Movement 1B - Human solo", "All agents off; play contemplative solo");
    }

    fun void _staggerChaos(int gen, int setPostChaosPad)
    {
        _c.deactivateAll();
        150::ms => now;
        for(0 => int s; s < _n; s++)
        {
            if(gen != _gen) return;
            s => int role;
            _c.sendRole(s, role);
            _roles.sendChaosMax(_c, s, role, _roles.chaosStaggerGain(s));
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 0);
            80::ms => now;
            if(gen != _gen) return;
            _c.sendActivate(s, 1);
            <<< "chaos: slot", s, "on role", role >>>;
            if(s < _n - 1)
            {
                2::second => now;
                if(gen != _gen) return;
            }
        }
        if(gen != _gen) return;
        if(setPostChaosPad) 1 => _padAfterChaosReady;
    }

    // Movement 1A — MIDI 100 (E7)
    fun void apply1A()
    {
        bumpGen() => int gen;
        _announce("Movement 1A - Chaos", "Autonomous chaos; feeder on");
        _c.sendFeederPause(0);
        _c.sendMidiForward(1);
        spork ~ _staggerChaos(gen, 0);
    }

    // Movement 5 — MIDI 36 (C2); all slots on immediately
    fun void apply5()
    {
        bumpGen() => int gen;
        _announce("Movement 5 - Return to chaos", "Instant octet chaos; pad after trigger");
        _c.sendFeederPause(0);
        _c.sendMidiForward(1);
        _c.deactivateAll();
        150::ms => now;
        if(gen != _gen) return;
        for(0 => int s; s < _n; s++)
        {
            if(gen != _gen) return;
            s => int role;
            _c.sendRole(s, role);
            _roles.sendChaosMax(_c, s, role, _roles.chaosStaggerGain(s));
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 0);
            80::ms => now;
            if(gen != _gen) return;
            _c.sendActivate(s, 1);
        }
        if(gen != _gen) return;
        1 => _padAfterChaosReady;
    }

    fun void _timeline2A(int gen)
    {
        8::second => now;
        if(gen != _gen) return;
        _owlSeed(OwlSlots.b(), 1.4, -1);
        <<< "2A: Owl slot", OwlSlots.b(), "seed @ 8s" >>>;
    }

    fun void apply2A()
    {
        bumpGen() => int gen;
        _announce("Movement 2A - Owl Duet", "Owl 7 seed now; Owl 5 @ 8s");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        _c.deactivateAll();
        80::ms => now;
        _owlSeed(OwlSlots.a(), 1.4, -1);
        spork ~ _timeline2A(gen);
    }

    fun void _timeline2B(int gen)
    {
        5::second => now;
        if(gen != _gen) return;
        _parrotEcho(4, 1.2, OwlSlots.a());
        5::second => now;
        if(gen != _gen) return;
        _swan(1, 1.3, OwlSlots.b());
        _parrotDevelop(0, 1.2, OwlSlots.b());
        2::second => now;
        if(gen != _gen) return;
        _peacock(3, 1.2, OwlSlots.a());
        _parrotDevelop(4, 1.2, OwlSlots.a());
    }

    fun void apply2B()
    {
        bumpGen() => int gen;
        _announce("Movement 2B - Growing chain", "Parrots; Swan->5, Peacock->7");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        _parrotEcho(0, 1.2, OwlSlots.b());
        spork ~ _timeline2B(gen);
    }

    fun void _timeline2C(int gen)
    {
        8::second => now;
        if(gen != _gen) return;
        _emuGlide(1, 0.8, OwlSlots.b());
        _emuBass(3, 0.6, OwlSlots.a());
        1 => _toggleArmed;
        1 => _toggleOn;
        <<< "2C: Emu on; E1 toggle armed (ON)" >>>;
    }

    fun void apply2C()
    {
        bumpGen() => int gen;
        _announce("Movement 2C - Quartet", "Owls develop; chain thickens @ 8s");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        _owlDevelop(OwlSlots.b(), 0.8, -1);
        _owlDevelop(OwlSlots.a(), 0.8, -1);
        _parrotDevelop(0, 1.2, OwlSlots.b());
        _parrotDevelop(4, 1.2, OwlSlots.a());
        _slotOff(1);
        _slotOff(3);
        _albatross(2, 1.0, OwlSlots.b());
        _albatross(6, 1.0, OwlSlots.a());
        spork ~ _timeline2C(gen);
    }

    fun void _applyToggle2C()
    {
        if(_toggleOn)
        {
            _owlSeed(OwlSlots.b(), 0.8, -1);
            _owlSeed(OwlSlots.a(), 0.8, -1);
            _c.sendListenTarget(0, OwlSlots.b());
            _c.sendListenTarget(2, OwlSlots.b());
            _c.sendListenTarget(1, OwlSlots.b());
            _c.sendListenTarget(4, OwlSlots.a());
            _c.sendListenTarget(6, OwlSlots.a());
            _c.sendListenTarget(3, OwlSlots.a());
        }
        else
        {
            _owlDevelop(OwlSlots.b(), 0.8, -1);
            _owlDevelop(OwlSlots.a(), 0.8, -1);
            _c.sendListenTarget(0, OwlSlots.b());
            _c.sendListenTarget(2, -1);
            _c.sendListenTarget(1, -1);
            _c.sendListenTarget(4, OwlSlots.a());
            _c.sendListenTarget(6, -1);
            _c.sendListenTarget(3, -1);
        }
    }

    fun void _applyToggle3B()
    {
        if(_toggleOn)
        {
            _owlSeed(OwlSlots.b(), 0.8, -1);
            _owlSeed(OwlSlots.a(), 0.8, -1);
            _c.sendListenTarget(0, OwlSlots.b());
            _c.sendListenTarget(1, OwlSlots.b());
            _c.sendListenTarget(6, OwlSlots.b());
            _c.sendListenTarget(2, OwlSlots.a());
            _c.sendListenTarget(3, OwlSlots.a());
            _c.sendListenTarget(4, OwlSlots.a());
        }
        else
        {
            _owlDevelop(OwlSlots.b(), 0.8, -1);
            _owlDevelop(OwlSlots.a(), 0.8, -1);
            for(int s; s < _n; s++)
            {
                if(s == OwlSlots.a() || s == OwlSlots.b()) continue;
                _c.sendListenTarget(s, -1);
            }
        }
    }

    fun void toggleListenChain()
    {
        if(_toggleArmed == 0) return;
        if(_toggleOn) 0 => _toggleOn;
        else 1 => _toggleOn;
        if(_toggleArmed == 1) _applyToggle2C();
        else if(_toggleArmed == 2) _applyToggle3B();
        <<< "E1 toggle:", _toggleOn ? "ON (chain)" : "OFF (human)" >>>;
    }

    fun void _falconGroup(int slots[], float gain, int nMin, int nMax,
        float sMin, float sMax, float jitter, int lo, int hi)
    {
        for(int i; i < slots.size(); i++)
            _falconPreset(slots[i], gain, nMin, nMax, sMin, sMax, jitter, lo, hi);
    }

    fun void _deactivateSlots(int slots[])
    {
        for(int i; i < slots.size(); i++)
            _slotOff(slots[i]);
    }

    fun void _timeline3A(int gen)
    {
        int lowGrp[5]; 0 => lowGrp[0]; 1 => lowGrp[1]; 2 => lowGrp[2]; 3 => lowGrp[3]; 4 => lowGrp[4];
        int highGrp[3]; 5 => highGrp[0]; 6 => highGrp[1]; 7 => highGrp[2];

        4::second => now;
        if(gen != _gen) return;
        _deactivateSlots(highGrp);
        _falconGroup(lowGrp, 1.5, 5, 8, 40, 50, 5, 48, 60);

        4::second => now;
        if(gen != _gen) return;
        _deactivateSlots(lowGrp);
        _falconGroup(highGrp, 1.5, 6, 15, 40, 70, 10, 72, 84);

        4::second => now;
        if(gen != _gen) return;
        _deactivateSlots(highGrp);
        _falconGroup(lowGrp, 1.5, 6, 15, 40, 70, 10, 48, 60);

        4::second => now;
        if(gen != _gen) return;
        int gA[3]; 0 => gA[0]; 1 => gA[1]; 5 => gA[2];
        int gB[2]; 2 => gB[0]; 6 => gB[1];
        int gC[3]; 3 => gC[0]; 4 => gC[1]; 7 => gC[2];
        _falconGroup(gA, 1.5, 6, 12, 120, 180, 20, 48, 60);
        _falconGroup(gB, 1.5, 12, 21, 75, 120, 10, 60, 72);
        _falconGroup(gC, 1.5, 18, 36, 40, 50, 10, 72, 84);
    }

    fun void apply3A()
    {
        bumpGen() => int gen;
        _announce("Movement 3A - Falcon Soli", "Alternating high/low falcon groups");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        for(int s; s < _n; s++) _slotOff(s);
        int highGrp[3]; 5 => highGrp[0]; 6 => highGrp[1]; 7 => highGrp[2];
        _falconGroup(highGrp, 1.5, 5, 8, 40, 50, 5, 72, 84);
        spork ~ _timeline3A(gen);
    }

    fun void _timeline3B(int gen)
    {
        4::second => now;
        if(gen != _gen) return;
        _owlSeed(OwlSlots.b(), 0.8, -1);
        _owlSeed(OwlSlots.a(), 0.8, -1);
        2::second => now;
        if(gen != _gen) return;
        _emuBass(6, 0.7, OwlSlots.b());
        2::second => now;
        if(gen != _gen) return;
        _albatross(1, 1.0, OwlSlots.b());
        _albatross(3, 1.0, OwlSlots.a());
        2::second => now;
        if(gen != _gen) return;
        _emuGlide(0, 0.7, OwlSlots.b());
        _emuGlide(4, 0.7, OwlSlots.a());
        2::second => now;
        if(gen != _gen) return;
        _albatross(2, 1.0, OwlSlots.a());
        2 => _toggleArmed;
        1 => _toggleOn;
        _applyToggle3B();
        <<< "3B: E1 toggle armed (ON)" >>>;
    }

    fun void apply3B()
    {
        bumpGen() => int gen;
        _announce("Movement 3B - Albatross + Emu", "Clear memory; Owls seed @ 4s");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        _c.deactivateAll();
        _clearAllMemory();
        spork ~ _timeline3B(gen);
    }

    fun void apply4A()
    {
        bumpGen();
        _announce("Movement 4A - Octet chaos", "All roles, max chaos, human listen");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        for(0 => int s; s < _n; s++)
        {
            s => int role;
            _c.sendRole(s, role);
            _roles.sendChaosMax(_c, s, role, _roles.chaosStaggerGain(s));
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 0);
            40::ms => now;
            _c.sendActivate(s, 1);
        }
    }

    fun void apply4B()
    {
        bumpGen();
        _announce("Movement 4B - Parakeet Soli", "1-3 random Parakeets harmonize you");
        _c.sendFeederPause(1);
        _c.sendMidiForward(1);
        _clearAllMemory();
        for(int s; s < _n; s++)
            _c.sendParam(s, "clearPitchSet", 1);
        Math.random2(1, 3) => int nPick;
        int picks[0];
        while(picks.size() < nPick)
        {
            Math.random2(0, _n - 1) => int s;
            int dup;
            for(int i; i < picks.size(); i++)
                if(picks[i] == s) 1 => dup;
            if(!dup) picks << s;
        }
        for(int s; s < _n; s++) _slotOff(s);
        for(int i; i < picks.size(); i++)
            _parakeetHarmonize(picks[i], 1.4, -1);
        <<< "4B: Parakeet slots", picks.size(), "active" >>>;
    }

    fun void applyMovement(int pitch)
    {
        if(pitch == MidiCtl.chaos1A()) apply1A();
        else if(pitch == MidiCtl.chaos5()) apply5();
        else if(pitch == 29) apply2A();
        else if(pitch == 30) apply2B();
        else if(pitch == 31) apply2C();
        else if(pitch == 32) apply3A();
        else if(pitch == 33) apply3B();
        else if(pitch == 34) apply4A();
        else if(pitch == 35) apply4B();
    }
}
