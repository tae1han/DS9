@import "config.ck"
@import "conductor.ck"
@import "roleBaselines.ck"
@import "roleGains.ck"

// OSC scene presets (shared by localSend, GameTrak pad, score).
public class ConductorScenes
{
    Conductor @ _c;
    RoleBaselines _baselines;
    RoleGains _gains;
    int _n;
    int _sceneGen;
    string _currentMovement;

    fun ConductorScenes(Conductor @ c, int numSlots)
    {
        c @=> _c;
        numSlots => _n;
        0 => _sceneGen;
        "idle" => _currentMovement;
    }

    fun string currentMovement()
    {
        return _currentMovement;
    }

    fun void _announceMovement(string label)
    {
        label => _currentMovement;
        <<< "" >>>;
        <<< "========== CURRENT MOVEMENT:", label, "==========" >>>;
        <<< "" >>>;
    }

    fun void _announcePhase(string phase)
    {
        <<< "  >>", _currentMovement, "—", phase >>>;
    }

    // Cancel staged sporks (chaos2 stagger, movement timelines) and silence stuck notes.
    fun int _bumpSceneGen()
    {
        _sceneGen++;
        return _sceneGen;
    }

    fun void _resetActiveOnSlot(int slot)
    {
        _c.sendParam(slot, "resetBaseline", 1);
    }

    fun void _resetRoleBaseline(int slot, int role)
    {
        _baselines.sendParams(_c, slot, role);
        _gains.sendPerformance(_c, slot, role);
    }

    fun void _activateSlot(int slot, int role)
    {
        _c.sendRole(slot, role);
        _resetRoleBaseline(slot, role);
        if(role == 1)
            _c.sendTimbre(slot, 0);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _resumeHumanMidi()
    {
        _c.sendMidiForward(1);
    }

    fun void _silenceEnsemble()
    {
        // Pause feeder and cut clients before baseline/param OSC (feeder multicasts in parallel).
        _c.sendFeederPause(1);
        _c.sendPanicAll();
        _c.deactivateAll();
        120::ms => now;
        _c.sendFeederPause(1);
        for(0 => int s; s < _n; s++)
            _resetActiveOnSlot(s);
        80::ms => now;
        _c.sendFeederPause(1);
    }

    fun void _hardStopAll()
    {
        _bumpSceneGen();
        _silenceEnsemble();
    }

    fun void _chaosParams(int slot)
    {
        slot => int role;
        _c.sendParam(slot, "delayMin", 0.0);
        _c.sendParam(slot, "delayMax", 0.0);

        if(role == 0)
        {
            _c.sendParam(slot, "mode", 1);
            _c.sendParam(slot, "developTechnique", -1);
            _c.sendParam(slot, "probability", 1.0);
            _c.sendParam(slot, "delayMin", 0.0);
            _c.sendParam(slot, "delayMax", 0.05);
        }
        else if(role == 1)
        {
            _c.sendParam(slot, "rtMode", 1);
            _c.sendParam(slot, "polyphony", 2);
            _c.sendParam(slot, "intervalMin", 3);
            _c.sendParam(slot, "intervalMax", 9);
            _c.sendParam(slot, "probability", 0.65);
            _c.sendParam(slot, "windowDurMin", 0.5);
            _c.sendParam(slot, "windowDurMax", 2.0);
            _c.sendParam(slot, "silenceMin", 0.3);
            _c.sendParam(slot, "silenceMax", 1.5);
        }
        else if(role == 2)
        {
            _c.sendParam(slot, "minNotes", 2);
            _c.sendParam(slot, "minPitchClasses", 2);
            _c.sendParam(slot, "trillProb", 0.65);
            _c.sendParam(slot, "trillRateMinHz", 2.0);
            _c.sendParam(slot, "trillRateMaxHz", 22.0);
            _c.sendParam(slot, "trillRampProb", 0.75);
            _c.sendParam(slot, "holdSecondsMin", 1.0);
            _c.sendParam(slot, "holdSecondsMax", 2.5);
            _c.sendParam(slot, "maxVoices", 3);
            _c.sendParam(slot, "velMax", 0.45);
        }
        else if(role == 3)
        {
            _c.sendParam(slot, "timingScale", 0.8);
            _c.sendParam(slot, "probability", 1.0);
        }
        else if(role == 4)
            _c.sendParam(slot, "glideMode", 1);
        else if(role == 5)
        {
            _c.sendParam(slot, "numNotesMin", 12);
            _c.sendParam(slot, "numNotesMax", 24);
            _c.sendParam(slot, "stepMsMin", 25.0);
            _c.sendParam(slot, "stepMsMax", 90.0);
            _c.sendParam(slot, "stepJitterMs", 12.0);
            _c.sendParam(slot, "noteDurMs", 280.0);
            _c.sendParam(slot, "probability", 0.9);
        }
        else if(role == 6)
        {
            _c.sendParam(slot, "repeatSpeed", 0.35);
            _c.sendParam(slot, "repeatGapBeats", 0.25);
            _c.sendParam(slot, "timingScale", 0.25);
            _c.sendParam(slot, "repeatExtraMin", 0);
            _c.sendParam(slot, "repeatExtraMax", 2);
            _c.sendParam(slot, "probability", 0.55);
        }
        else if(role == 7)
        {
            _c.sendParam(slot, "owlMode", 0);
            _c.sendParam(slot, "quantizeRecall", 0);
            _c.sendParam(slot, "seedCooldownMs", 400);
        }

        _gains.sendChaos(_c, slot, role);
    }

    fun void _chaosRole(int slot)
    {
        slot => int role;
        _c.sendRole(slot, role);
        _chaosParams(slot);
    }

    fun void _m1Role(int slot)
    {
        slot => int role;
        _c.sendRole(slot, role);
        if(role == 0)
            _c.sendParam(slot, "mode", 0);
        else if(role == 1)
            _c.sendParam(slot, "rtMode", 0);
        else if(role == 4)
            _c.sendParam(slot, "glideMode", 0);
        else if(role == 7)
            _c.sendParam(slot, "owlMode", 0);
    }

    fun void applyChaos()
    {
        _announceMovement("CHAOS (movement 1)");
        for(0 => int s; s < _n; s++)
        {
            _chaosRole(s);
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 1);
        }
        _c.sendCueAll("Chaos — eight roles, max activity");
        <<< "scene: chaos (movement 1)" >>>;
    }

    fun void _chaos2Extras(int slot)
    {
        // Owl slots: develop (not seed), no eddies — avoids atonal phrase recall into M2.
        if(slot == 7 || slot == 5)
        {
            _c.sendParam(slot, "owlMode", 0);
            _c.sendParam(slot, "eddiesEnabled", 0);
            _c.sendParam(slot, "phraseOnlyEddies", 1);
            _c.sendParam(slot, "quantizeRecall", 0);
            _c.sendParam(slot, "seedProb", 0);
            return;
        }
        _c.sendParam(slot, "eddiesEnabled", 1);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
    }

    // Staged activation (~2s per station). Run in parallel with autonomousFeeder so
    // early slots play while later ones are still off.
    fun void applyChaos2()
    {
        _announceMovement("CHAOS 2");
        _c.sendFeederPause(0);
        _bumpSceneGen() => int gen;
        _c.deactivateAll();
        150::ms => now;
        _c.sendCueAll("Chaos 2 — introducing agents one by one");
        for(0 => int s; s < _n; s++)
        {
            if(gen != _sceneGen) return;
            s => int role;
            _c.sendRole(s, role);
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 0);
            80::ms => now;
            if(gen != _sceneGen) return;
            // Params after deactivate (matches studio GUI reactivate flow).
            _chaosParams(s);
            _chaos2Extras(s);
            _c.sendListenTarget(s, -1);
            80::ms => now;
            _c.sendActivate(s, 1);
            <<< "chaos2: slot", s, "on (role", role, ")" >>>;
            if(s < _n - 1)
            {
                2::second => now;
                if(gen != _sceneGen) return;
            }
        }
        if(gen != _sceneGen) return;
        _c.sendCueAll("Chaos 2 — full ensemble");
        _announceMovement("CHAOS 2 (full ensemble)");
        <<< "scene: chaos2 — all slots active" >>>;
    }

    fun void applyM1()
    {
        _announceMovement("MOVEMENT 1 (eight roles)");
        for(0 => int s; s < _n; s++)
        {
            _m1Role(s);
            if(s == 1)
                _c.sendTimbre(s, 0);
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 1);
        }
        _c.sendCueAll("Movement 1 — eight roles, solo listen");
        <<< "scene: m1" >>>;
    }

    fun void applyMute()
    {
        _announceMovement("MUTE (sparse — all agents off)");
        _hardStopAll();
        _c.sendCueAll("Sparse — all agents off");
        <<< "scene: mute" >>>;
    }

    fun void _owlMovementGain(int slot)
    {
        _c.sendParam(slot, "roleGain", 2.0);
    }

    fun void _parakeetMovementGain(int slot)
    {
        _c.sendParam(slot, "roleGain", 0.8);
    }

    fun void _clearOwlMemory(int slot)
    {
        _c.sendParam(slot, "clearMemory", 1);
    }

    // Pad break / M2 entry: drop chaos phrase recall and seed state on owl slots.
    fun void endChaosOwls(int owlA, int owlB)
    {
        int slots[0];
        slots << owlA << owlB;
        for(int si; si < slots.size(); si++)
        {
            slots[si] => int slot;
            if(slot < 0 || slot >= _n) continue;
            _c.sendPanic(slot);
            _clearOwlMemory(slot);
            _c.sendParam(slot, "owlMode", 0);
            _c.sendParam(slot, "eddiesEnabled", 0);
            _c.sendParam(slot, "phraseOnlyEddies", 1);
            _c.sendParam(slot, "seedProb", 0);
            _c.sendActivate(slot, 0);
        }
        // Second pulse so clients flush phraseMem + listen buffers before M2 develop.
        80::ms => now;
        _clearOwlMemory(owlA);
        _clearOwlMemory(owlB);
    }

    fun void sendOwlToggleMode(int isSeed, int owlA, int owlB)
    {
        int slots[2];
        owlA => slots[0];
        owlB => slots[1];
        for(0 => int si; si < 2; si++)
        {
            slots[si] => int slot;
            if(slot < 0 || slot >= _n) continue;
            if(isSeed)
            {
                _owlSeedDefaults(slot);
                _c.sendParam(slot, "owlMode", 1);
            }
            else
            {
                _owlDevelopDefaults(slot);
                _c.sendParam(slot, "owlMode", 0);
            }
        }
    }

    fun void _owlDevelopDefaults(int slot)
    {
        _c.sendParam(slot, "owlMode", 0);
        _c.sendParam(slot, "developTechnique", -1);
        _c.sendParam(slot, "quantizeRecall", 0);
        _c.sendParam(slot, "seedProb", 0.5);
        _c.sendParam(slot, "postSeedQuietMin", 0.5);
        _c.sendParam(slot, "postSeedQuietMax", 1.0);
        _c.sendParam(slot, "seedCooldownMs", 250);
        _c.sendParam(slot, "eddiesEnabled", 0);
        _c.sendParam(slot, "phraseOnlyEddies", 1);
        _c.sendParam(slot, "verbose", 0);
        _c.sendTimbre(slot, 0);
    }

    fun void applyAllParrotEcho()
    {
        for(0 => int s; s < _n; s++)
        {
            _c.sendRole(s, 0);
            _c.sendParam(s, "mode", 0);
            _c.sendParam(s, "probability", 1.0);
            _c.sendListenTarget(s, -1);
            _c.sendActivate(s, 1);
        }
        _c.sendCueAll("All Parrot — echo");
        <<< "scene: all Parrot echo" >>>;
    }

    fun void _owlSeedDefaults(int slot)
    {
        _c.sendParam(slot, "owlMode", 1);
        _c.sendParam(slot, "eddiesEnabled", 1);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "seedProb", 0.72);
        _c.sendParam(slot, "quantizeRecall", 0);
        _c.sendParam(slot, "postSeedQuietMin", 0.25);
        _c.sendParam(slot, "postSeedQuietMax", 1.0);
        _c.sendParam(slot, "seedCooldownMs", 200);
        _c.sendTimbre(slot, 0);
    }

    fun void _owlActivateSeed(int slot)
    {
        _c.sendRole(slot, 7);
        _clearOwlMemory(slot);
        _owlSeedDefaults(slot);
        _c.sendListenTarget(slot, -1);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _owlActivateDevelop(int slot)
    {
        _c.sendRole(slot, 7);
        _clearOwlMemory(slot);
        _owlDevelopDefaults(slot);
        _owlMovementGain(slot);
        _c.sendListenTarget(slot, -1);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _movement2Timeline(int gen, int owlA, int owlB)
    {
        10::second => now;
        if(gen != _sceneGen) return;
        _owlActivateSeed(owlA);
        _owlMovementGain(owlA);
        _announcePhase("Owl A → seed mode");
        _c.sendCueAll("Movement 2 — Owl A seed");
        <<< "movement 2: Owl A seed (slot", owlA, ") @ 10s" >>>;

        8::second => now;
        if(gen != _sceneGen) return;
        _owlActivateSeed(owlB);
        _owlMovementGain(owlB);
        _c.sendParam(owlB, "postSeedQuietMin", 0.15);
        _c.sendParam(owlB, "postSeedQuietMax", 0.85);
        _announcePhase("Owl B → seed mode");
        _c.sendCueAll("Movement 2 — Owl B seed");
        <<< "movement 2: Owl B seed (slot", owlB, ") @ 18s" >>>;
    }

    // Owl A develop @ onset → seed @ 10s; Owl B seed @ 18s. Defaults: slots 7 & 5.
    fun void applyMovement2(int owlA, int owlB)
    {
        if(owlA < 0) 7 => owlA;
        if(owlB < 0) 5 => owlB;
        if(owlA >= _n) _n - 1 => owlA;
        if(owlB >= _n) _n - 1 => owlB;

        _resumeHumanMidi();
        _c.sendFeederPause(1);
        _bumpSceneGen() => int gen;
        _announceMovement("MOVEMENT 2 (Owls)");
        _silenceEnsemble();
        80::ms => now;
        endChaosOwls(owlA, owlB);
        120::ms => now;
        _c.sendActivate(owlB, 0);
        _c.sendPanic(owlB);
        _announcePhase("Owl A develop (listen to you)");
        _c.sendCueAll("Movement 2 — Owl A develop");
        _owlActivateDevelop(owlA);
        _resumeHumanMidi();
        <<< "movement 2: Owl A develop slot", owlA, "→ seed 10s | Owl B seed @ 18s" >>>;
        spork ~ _movement2Timeline(gen, owlA, owlB);
    }

    fun void _parrotEchoOnSlot(int slot, int listenTo)
    {
        _c.sendRole(slot, 0);
        _c.sendParam(slot, "mode", 0);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "delayMin", 0.35);
        _c.sendParam(slot, "delayMax", 1.1);
        _c.sendListenTarget(slot, listenTo);
        _c.sendTimbre(slot, -1);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    fun void _parrotDevelopOnSlot(int slot, int listenTo)
    {
        _c.sendRole(slot, 0);
        _c.sendParam(slot, "mode", 1);
        _c.sendParam(slot, "developTechnique", -1);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendListenTarget(slot, listenTo);
        _c.sendTimbre(slot, -1);
        _c.sendActivate(slot, 0);
        80::ms => now;
        _c.sendActivate(slot, 1);
    }

    // Movement entry: harmonize upstream (not mirror). Baseline + listen + full activate.
    fun void _parakeetHarmonizeOnSlot(int slot, int listenTo)
    {
        _activateSlot(slot, 1);
        _c.sendParam(slot, "rtMode", 1);
        _c.sendParam(slot, "polyphony", 1);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "phraseOnlyEddies", 0);
        _c.sendParam(slot, "windowDurMin", 0.5);
        _c.sendParam(slot, "windowDurMax", 2.5);
        _c.sendParam(slot, "silenceMin", 0.0);
        _c.sendParam(slot, "silenceMax", 0.15);
        _c.sendListenTarget(slot, listenTo);
    }

    fun void _parakeetResetRt(int slot, int listenTo)
    {
        _c.sendPanic(slot);
        _c.sendParam(slot, "enabled", 0);
        80::ms => now;
        _c.sendListenTarget(slot, listenTo);
        _c.sendParam(slot, "enabled", 1);
    }

    fun void _movement8FadeOut(int gen)
    {
        12::second => now;
        if(gen != _sceneGen) return;
        for(0 => int s; s < _n; s++)
        {
            if(gen != _sceneGen) return;
            _c.sendPanic(s);
            _c.sendActivate(s, 0);
            _announcePhase("station " + s + " off");
            if(s < _n - 1)
                2.5::second => now;
        }
        _announceMovement("MOVEMENT 8 (complete — all off)");
        _c.sendCueAll("Movement 8 — silence");
    }

    fun void _movement3Timeline(int gen, int owlA, int owlB, int parrotA, int parrotB,
        int parakeetA, int parakeetB)
    {
        8::second => now;
        if(gen != _sceneGen) return;
        _announcePhase("Parrots develop");
        _c.sendParam(parrotA, "mode", 1);
        _c.sendParam(parrotB, "mode", 1);
        _c.sendParam(parrotA, "developTechnique", -1);
        _c.sendParam(parrotB, "developTechnique", -1);
        _c.sendCueAll("Movement 3 — Parrots develop");
        <<< "movement 3: Parrots develop (slots", parrotA, parrotB, ")" >>>;

        8::second => now;
        if(gen != _sceneGen) return;
        _announcePhase("Parakeets harmonize Owls");
        _parakeetHarmonizeOnSlot(parakeetA, owlB);
        _parakeetMovementGain(parakeetA);
        _parakeetHarmonizeOnSlot(parakeetB, owlA);
        _parakeetMovementGain(parakeetB);
        _c.sendCueAll("Movement 3 — Parakeets harmonize Owls");
        <<< "movement 3: Parakeets harmonize Owls (", parakeetA, "→", owlB, ",",
            parakeetB, "→", owlA, ")" >>>;
    }

    // Parrots 0→Owl 5, 4→Owl 7; develop @ 8s; parakeets 1→5, 3→7 @ 16s.
    fun void applyMovement3(int owlA, int owlB, int parrotA, int parrotB,
        int parakeetA, int parakeetB)
    {
        _resumeHumanMidi();
        if(owlA < 0) 7 => owlA;
        if(owlB < 0) 5 => owlB;
        if(parrotA < 0) 0 => parrotA;
        if(parrotB < 0) 4 => parrotB;
        if(parakeetA < 0) 1 => parakeetA;
        if(parakeetB < 0) 3 => parakeetB;

        _bumpSceneGen() => int gen;
        _announceMovement("MOVEMENT 3 (Parrots + Parakeets)");
        _c.sendFeederPause(1);
        for(0 => int s; s < _n; s++)
        {
            if(s != owlA && s != owlB && s != parrotA && s != parrotB
                && s != parakeetA && s != parakeetB)
            {
                _resetActiveOnSlot(s);
                _c.sendPanic(s);
                _c.sendActivate(s, 0);
            }
        }
        150::ms => now;
        _owlMovementGain(owlA);
        _owlMovementGain(owlB);
        _announcePhase("Parrots echo Owls");
        _c.sendCueAll("Movement 3 — Parrots echo Owls");
        _parrotEchoOnSlot(parrotA, owlB);
        _parrotEchoOnSlot(parrotB, owlA);
        <<< "movement 3: Parrot", parrotA, "→ Owl", owlB, "| Parrot", parrotB,
            "→ Owl", owlA, "| develop 8s, Parakeets 16s" >>>;
        spork ~ _movement3Timeline(gen, owlA, owlB, parrotA, parrotB, parakeetA, parakeetB);
    }

    fun void _emuOnSlot(int slot, int glideMode)
    {
        _activateSlot(slot, 4);
        _c.sendParam(slot, "glideMode", glideMode);
        _c.sendListenTarget(slot, -1);
    }

    fun void _albatrossOnSlot(int slot)
    {
        _activateSlot(slot, 2);
        _c.sendListenTarget(slot, -1);
    }

    fun void _peacockOnSlot(int slot)
    {
        _activateSlot(slot, 3);
        _c.sendParam(slot, "probability", 1.0);
        _c.sendParam(slot, "roleGain", 1.2);
    }

    fun void _swanOnSlot(int slot)
    {
        _activateSlot(slot, 6);
        _c.sendParam(slot, "probability", 0.85);
    }

    // Peacock + Swan listen to Parrots; Owls → Parrot develop; parakeets drop out.
    fun void applyMovement4(int peacockSlot, int peacockListen, int swanSlot, int swanListen)
    {
        _resumeHumanMidi();
        if(peacockSlot < 0) 6 => peacockSlot;
        if(peacockListen < 0) 0 => peacockListen;
        if(swanSlot < 0) 2 => swanSlot;
        if(swanListen < 0) 4 => swanListen;
        7 => int owlA;
        5 => int owlB;
        1 => int parakeetA;
        3 => int parakeetB;

        _bumpSceneGen();
        _announceMovement("MOVEMENT 4 (Peacock + Swan)");
        _c.sendFeederPause(1);
        80::ms => now;
        _announcePhase("Owls → Parrot develop; Peacock & Swan → Parrots");
        _c.sendCueAll("Movement 4 — Owls develop, Peacock & Swan listen to Parrots");
        _parrotDevelopOnSlot(owlA, -1);
        _parrotDevelopOnSlot(owlB, -1);
        _c.sendPanic(parakeetA);
        _c.sendActivate(parakeetA, 0);
        _c.sendPanic(parakeetB);
        _c.sendActivate(parakeetB, 0);
        _peacockOnSlot(peacockSlot);
        _c.sendListenTarget(peacockSlot, peacockListen);
        _swanOnSlot(swanSlot);
        _c.sendListenTarget(swanSlot, swanListen);
        <<< "movement 4: Owls", owlA, owlB, "→ Parrot develop | parakeets off",
            "| Peacock", peacockSlot, "→ Parrot", peacockListen,
            "| Swan", swanSlot, "→ Parrot", swanListen >>>;
    }

    fun void _falconOnSlot(int slot)
    {
        _c.sendPanic(slot);
        60::ms => now;
        _activateSlot(slot, 5);
    }

    // Emu + Albatross layer; Parrot develop on 5 & 7 unchanged from M4.
    fun void applyMovement5()
    {
        _resumeHumanMidi();
        _bumpSceneGen();
        _announceMovement("MOVEMENT 5 (Emu + Albatross)");
        _c.sendFeederPause(1);
        80::ms => now;
        _c.sendCueAll("Movement 5 — Emu bass/glide, Albatross drones");
        _emuOnSlot(0, 1);
        _emuOnSlot(1, 0);
        _albatrossOnSlot(3);
        _albatrossOnSlot(4);
        <<< "movement 5: Emu 0 glide, 1 bassline | Albatross 3, 4 | Parrot develop 5, 7 unchanged" >>>;
    }

    // All stations Falcon, listening to you.
    fun void applyMovement6()
    {
        _resumeHumanMidi();
        _bumpSceneGen();
        _announceMovement("MOVEMENT 6 (all Falcon)");
        _c.sendFeederPause(1);
        _silenceEnsemble();
        80::ms => now;
        _c.sendCueAll("Movement 6 — all Falcon");
        for(0 => int s; s < _n; s++)
        {
            _falconOnSlot(s);
            _c.sendListenTarget(s, -1);
        }
        <<< "movement 6: all Falcon (8 slots)" >>>;
    }

    // Eight roles (slot i = role i), established defaults, solo listen.
    fun void applyMovement7()
    {
        _resumeHumanMidi();
        _bumpSceneGen();
        _announceMovement("MOVEMENT 7 (eight roles, defaults)");
        _c.sendFeederPause(1);
        _silenceEnsemble();
        80::ms => now;
        _c.sendCueAll("Movement 7 — eight roles (defaults)");
        for(0 => int s; s < _n; s++)
        {
            _activateSlot(s, s);
            _m1Role(s);
            _c.sendListenTarget(s, -1);
        }
        <<< "movement 7: eight roles, baseline defaults" >>>;
    }

    // All Parakeet harmonizing your playing, then gradual station fade-out.
    fun void applyMovement8()
    {
        _resumeHumanMidi();
        _bumpSceneGen() => int gen;
        _announceMovement("MOVEMENT 8 (all Parakeet harmonize you)");
        _c.sendFeederPause(1);
        _silenceEnsemble();
        80::ms => now;
        _c.sendCueAll("Movement 8 — all Parakeet harmonize you");
        for(0 => int s; s < _n; s++)
            _parakeetHarmonizeOnSlot(s, -1);
        <<< "movement 8: all Parakeet harmonize human | fade in 12s" >>>;
        spork ~ _movement8FadeOut(gen);
    }

    // Owls stop following your phrases but keep seeding; you solo in monitor.
    fun void applySoloMode(int owlA, int owlB)
    {
        _resumeHumanMidi();
        if(owlA < 0) 7 => owlA;
        if(owlB < 0) 5 => owlB;
        _bumpSceneGen();
        _announceMovement("SOLO (Owls seed only)");
        _c.sendListenTarget(owlA, 0);
        _c.sendListenTarget(owlB, 0);
        _c.sendParam(owlA, "owlMode", 1);
        _c.sendParam(owlB, "owlMode", 1);
        _c.sendParam(owlA, "eddiesEnabled", 1);
        _c.sendParam(owlB, "eddiesEnabled", 1);
        _c.sendParam(owlA, "phraseOnlyEddies", 0);
        _c.sendParam(owlB, "phraseOnlyEddies", 0);
        _c.sendCueAll("Solo — Owls seed only; play over the ensemble");
        <<< "solo: Owls", owlA, owlB, "detached from human (seed recall continues)" >>>;
    }
}
