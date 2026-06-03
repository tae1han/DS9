@import "../lib/agent.ck"
@import "../conductor.ck"

// Role gains, baseline params, and chaos presets — keep in sync with agents/defaults.txt.
public class RoleConfig
{
    // --- Client instrument gain (sf2Util internal 2.5× load) ---

    fun float performanceGain(int role)
    {
        if(role == 0) return 1.28;
        if(role == 1) return 1.4;
        if(role == 2) return 1.4;
        if(role == 3) return 1.5;
        if(role == 4) return 1.3;
        if(role == 5) return 2.1;
        if(role == 6) return 2.2;
        if(role == 7) return 0.8;
        return 1.0;
    }

    // Movement 1A / 5 stagger gains (composition.txt).
    fun float chaosStaggerGain(int slot)
    {
        if(slot == 0) return 1.3;
        if(slot == 1) return 1.4;
        if(slot == 2) return 0.95;
        if(slot == 3) return 1.2;
        if(slot == 4) return 1.1;
        if(slot == 5) return 2.0;
        if(slot == 6) return 1.3;
        if(slot == 7) return 0.8;
        return 1.0;
    }

    // --- Client: reset agent to pre-chaos defaults ---

    fun void applyAgent(Agent @ a, int role)
    {
        if(a == null) return;
        a.setParam("eddiesEnabled", 0);
        a.setParam("phraseOnlyEddies", 1);
        a.setParam("maxHopDepth", 4);
        a.setParam("seedCooldownMs", 3000);
        a.setParam("delayMin", 0.0);
        a.setParam("delayMax", 0.0);
        a.setListenTarget(-1);

        if(role == 0)
        {
            a.setParam("mode", 0);
            a.setParam("developTechnique", -1);
            a.setParam("probability", 1.0);
            a.setParam("delayMin", 0.05);
            a.setParam("delayMax", 0.75);
            a.setParam("octaveDisplaceProb", 0.0);
            a.setParam("rhythmScale", 1.0);
            a.setParam("truncateMin", 0);
            a.setParam("truncateMax", 0);
            a.setParam("repeatsMin", 1);
            a.setParam("repeatsMax", 1);
        }
        else if(role == 1)
        {
            a.setParam("rtMode", 1);
            a.setParam("probability", 0.25);
            a.setParam("windowDurMin", 1.0);
            a.setParam("windowDurMax", 5.0);
            a.setParam("silenceMin", 3.0);
            a.setParam("silenceMax", 8.0);
            a.setParam("intervalMin", 3);
            a.setParam("intervalMax", 9);
            a.setParam("polyphony", 2);
            a.setParam("harmonyDirection", 1);
            a.setParam("harmonyVelScale", 0.95);
            a.setParam("minInputVel", 0.15);
        }
        else if(role == 2)
        {
            a.setParam("minNotes", 4);
            a.setParam("minPitchClasses", 4);
            a.setParam("trillProb", 0.28);
            a.setParam("trillRateMinHz", 4.5);
            a.setParam("trillRateMaxHz", 16.0);
            a.setParam("trillRampProb", 0.6);
            a.setParam("holdSecondsMin", 2.0);
            a.setParam("holdSecondsMax", 4.0);
            a.setParam("maxVoices", 2);
            a.setParam("velMin", 0.15);
            a.setParam("velMax", 0.35);
            a.setParam("delayMin", 0.5);
            a.setParam("delayMax", 5.0);
        }
        else if(role == 3)
        {
            a.setParam("timingScale", 1.5);
            a.setParam("probability", 0.5);
            a.setParam("minPitchClasses", 2);
        }
        else if(role == 4)
        {
            a.setParam("glideMode", 0);
            a.setParam("autoModeSwitch", 0);
            a.setParam("delayMin", 0.2);
            a.setParam("delayMax", 0.6);
        }
        else if(role == 5)
        {
            a.setParam("numNotesMin", 8);
            a.setParam("numNotesMax", 24);
            a.setParam("stepMsMin", 40.0);
            a.setParam("stepMsMax", 180.0);
            a.setParam("stepJitterMs", 20.0);
            a.setParam("noteDurMs", 400.0);
            a.setParam("probability", 0.5);
            a.setParam("reversalProb", 0.05);
        }
        else if(role == 6)
        {
            a.setParam("repeatSpeed", 0.5);
            a.setParam("repeatGapBeats", 0.25);
            a.setParam("timingScale", 0.3);
            a.setParam("probability", 0.5);
            a.setParam("repeatExtraMin", 0);
            a.setParam("repeatExtraMax", 3);
            a.setParam("minOrdered", 3);
            a.setParam("rootVel", 0.72);
            a.setParam("harmonyVel", 0.58);
        }
        else if(role == 7)
        {
            a.setParam("owlMode", 0);
            a.setParam("quantizeRecall", 0);
            a.setParam("seedProb", 0.5);
            a.setParam("postSeedQuietMin", 2.0);
            a.setParam("postSeedQuietMax", 4.0);
        }
    }

    // --- Server: OSC baseline reset before movement-specific params ---

    fun void sendBaseline(Conductor @ c, int slot, int role)
    {
        if(c == null) return;
        c.sendParam(slot, "eddiesEnabled", 0);
        c.sendParam(slot, "phraseOnlyEddies", 1);
        c.sendParam(slot, "maxHopDepth", 4);
        c.sendParam(slot, "seedCooldownMs", 3000);
        c.sendParam(slot, "delayMin", 0.0);
        c.sendParam(slot, "delayMax", 0.0);

        if(role == 0)
        {
            c.sendParam(slot, "mode", 0);
            c.sendParam(slot, "developTechnique", -1);
            c.sendParam(slot, "probability", 1.0);
            c.sendParam(slot, "delayMin", 0.05);
            c.sendParam(slot, "delayMax", 0.75);
            c.sendParam(slot, "octaveDisplaceProb", 0.0);
            c.sendParam(slot, "rhythmScale", 1.0);
            c.sendParam(slot, "truncateMin", 0);
            c.sendParam(slot, "truncateMax", 0);
            c.sendParam(slot, "repeatsMin", 1);
            c.sendParam(slot, "repeatsMax", 1);
        }
        else if(role == 1)
        {
            c.sendParam(slot, "rtMode", 1);
            c.sendParam(slot, "probability", 0.25);
            c.sendParam(slot, "windowDurMin", 1.0);
            c.sendParam(slot, "windowDurMax", 5.0);
            c.sendParam(slot, "silenceMin", 3.0);
            c.sendParam(slot, "silenceMax", 8.0);
            c.sendParam(slot, "intervalMin", 3);
            c.sendParam(slot, "intervalMax", 9);
            c.sendParam(slot, "polyphony", 2);
            c.sendParam(slot, "harmonyDirection", 1);
            c.sendParam(slot, "harmonyVelScale", 0.95);
            c.sendParam(slot, "minInputVel", 0.15);
        }
        else if(role == 2)
        {
            c.sendParam(slot, "minNotes", 4);
            c.sendParam(slot, "minPitchClasses", 4);
            c.sendParam(slot, "trillProb", 0.28);
            c.sendParam(slot, "trillRateMinHz", 4.5);
            c.sendParam(slot, "trillRateMaxHz", 16.0);
            c.sendParam(slot, "trillRampProb", 0.6);
            c.sendParam(slot, "holdSecondsMin", 2.0);
            c.sendParam(slot, "holdSecondsMax", 4.0);
            c.sendParam(slot, "maxVoices", 2);
            c.sendParam(slot, "velMin", 0.15);
            c.sendParam(slot, "velMax", 0.35);
            c.sendParam(slot, "delayMin", 0.5);
            c.sendParam(slot, "delayMax", 5.0);
        }
        else if(role == 3)
        {
            c.sendParam(slot, "timingScale", 1.5);
            c.sendParam(slot, "probability", 0.5);
            c.sendParam(slot, "minPitchClasses", 2);
        }
        else if(role == 4)
        {
            c.sendParam(slot, "glideMode", 0);
            c.sendParam(slot, "autoModeSwitch", 0);
            c.sendParam(slot, "delayMin", 0.2);
            c.sendParam(slot, "delayMax", 0.6);
        }
        else if(role == 5)
        {
            c.sendParam(slot, "numNotesMin", 8);
            c.sendParam(slot, "numNotesMax", 24);
            c.sendParam(slot, "stepMsMin", 40.0);
            c.sendParam(slot, "stepMsMax", 180.0);
            c.sendParam(slot, "stepJitterMs", 20.0);
            c.sendParam(slot, "noteDurMs", 400.0);
            c.sendParam(slot, "probability", 0.5);
            c.sendParam(slot, "reversalProb", 0.05);
        }
        else if(role == 6)
        {
            c.sendParam(slot, "repeatSpeed", 0.5);
            c.sendParam(slot, "repeatGapBeats", 0.25);
            c.sendParam(slot, "timingScale", 0.3);
            c.sendParam(slot, "probability", 0.5);
            c.sendParam(slot, "repeatExtraMin", 0);
            c.sendParam(slot, "repeatExtraMax", 3);
            c.sendParam(slot, "minOrdered", 3);
            c.sendParam(slot, "rootVel", 0.72);
            c.sendParam(slot, "harmonyVel", 0.58);
        }
        else if(role == 7)
        {
            c.sendParam(slot, "owlMode", 0);
            c.sendParam(slot, "quantizeRecall", 0);
            c.sendParam(slot, "seedProb", 0.5);
            c.sendParam(slot, "postSeedQuietMin", 2.0);
            c.sendParam(slot, "postSeedQuietMax", 4.0);
        }
    }

    // --- Server: max-chaos preset (movements 1A, 4A, 5) ---

    fun void sendChaosMax(Conductor @ c, int slot, int role, float gain)
    {
        if(c == null) return;
        c.sendParam(slot, "delayMin", 0.0);
        c.sendParam(slot, "delayMax", 0.0);

        if(role == RoleIds.parrot())
        {
            c.sendParam(slot, "mode", 1);
            c.sendParam(slot, "developTechnique", -1);
            c.sendParam(slot, "probability", 1.0);
            c.sendParam(slot, "delayMax", 0.05);
        }
        else if(role == RoleIds.parakeet())
        {
            c.sendParam(slot, "rtMode", 1);
            c.sendParam(slot, "polyphony", 2);
            c.sendParam(slot, "intervalMin", 3);
            c.sendParam(slot, "intervalMax", 9);
            c.sendParam(slot, "probability", 0.65);
            c.sendParam(slot, "windowDurMin", 0.5);
            c.sendParam(slot, "windowDurMax", 2.0);
            c.sendParam(slot, "silenceMin", 0.3);
            c.sendParam(slot, "silenceMax", 1.5);
        }
        else if(role == RoleIds.albatross())
        {
            c.sendParam(slot, "minNotes", 2);
            c.sendParam(slot, "minPitchClasses", 2);
            c.sendParam(slot, "trillProb", 0.65);
            c.sendParam(slot, "trillRateMinHz", 2.0);
            c.sendParam(slot, "trillRateMaxHz", 22.0);
            c.sendParam(slot, "trillRampProb", 0.75);
            c.sendParam(slot, "holdSecondsMin", 1.0);
            c.sendParam(slot, "holdSecondsMax", 2.5);
            c.sendParam(slot, "maxVoices", 3);
            c.sendParam(slot, "velMax", 0.45);
        }
        else if(role == RoleIds.peacock())
        {
            c.sendParam(slot, "timingScale", 0.8);
            c.sendParam(slot, "probability", 1.0);
        }
        else if(role == RoleIds.emu())
            c.sendParam(slot, "glideMode", 1);
        else if(role == RoleIds.falcon())
        {
            c.sendParam(slot, "numNotesMin", 12);
            c.sendParam(slot, "numNotesMax", 24);
            c.sendParam(slot, "stepMsMin", 25.0);
            c.sendParam(slot, "stepMsMax", 90.0);
            c.sendParam(slot, "stepJitterMs", 12.0);
            c.sendParam(slot, "noteDurMs", 280.0);
            c.sendParam(slot, "probability", 0.9);
        }
        else if(role == RoleIds.swan())
        {
            c.sendParam(slot, "repeatSpeed", 0.35);
            c.sendParam(slot, "repeatGapBeats", 0.25);
            c.sendParam(slot, "timingScale", 0.25);
            c.sendParam(slot, "repeatExtraMin", 0);
            c.sendParam(slot, "repeatExtraMax", 2);
            c.sendParam(slot, "probability", 0.55);
        }
        else if(role == RoleIds.owl())
        {
            c.sendParam(slot, "owlMode", 0);
            c.sendParam(slot, "quantizeRecall", 0);
            c.sendParam(slot, "seedCooldownMs", 400);
            c.sendParam(slot, "eddiesEnabled", 0);
            c.sendParam(slot, "phraseOnlyEddies", 1);
            c.sendParam(slot, "seedProb", 0);
        }

        if(role != RoleIds.owl())
        {
            c.sendParam(slot, "eddiesEnabled", 1);
            c.sendParam(slot, "phraseOnlyEddies", 0);
        }

        c.sendParam(slot, "roleGain", gain);
    }
}
