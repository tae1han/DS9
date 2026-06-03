@import "conductor.ck"
@import "roleBaselines.ck"

// Server-side role params: chaos max preset + baseline reset.
public class RolePresets
{
    RoleBaselines _baselines;

    // Movement 1A / 5 stagger gains (composition.txt).
    fun float chaosGain(int slot)
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

    fun void sendChaosMax(Conductor @ c, int slot, int role, float gain)
    {
        if(c == null) return;
        c.sendParam(slot, "delayMin", 0.0);
        c.sendParam(slot, "delayMax", 0.0);

        if(role == ROLE_PARROT)
        {
            c.sendParam(slot, "mode", 1);
            c.sendParam(slot, "developTechnique", -1);
            c.sendParam(slot, "probability", 1.0);
            c.sendParam(slot, "delayMax", 0.05);
        }
        else if(role == ROLE_PARAKEET)
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
        else if(role == ROLE_ALBATROSS)
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
        else if(role == ROLE_PEACOCK)
        {
            c.sendParam(slot, "timingScale", 0.8);
            c.sendParam(slot, "probability", 1.0);
        }
        else if(role == ROLE_EMU)
            c.sendParam(slot, "glideMode", 1);
        else if(role == ROLE_FALCON)
        {
            c.sendParam(slot, "numNotesMin", 12);
            c.sendParam(slot, "numNotesMax", 24);
            c.sendParam(slot, "stepMsMin", 25.0);
            c.sendParam(slot, "stepMsMax", 90.0);
            c.sendParam(slot, "stepJitterMs", 12.0);
            c.sendParam(slot, "noteDurMs", 280.0);
            c.sendParam(slot, "probability", 0.9);
        }
        else if(role == ROLE_SWAN)
        {
            c.sendParam(slot, "repeatSpeed", 0.35);
            c.sendParam(slot, "repeatGapBeats", 0.25);
            c.sendParam(slot, "timingScale", 0.25);
            c.sendParam(slot, "repeatExtraMin", 0);
            c.sendParam(slot, "repeatExtraMax", 2);
            c.sendParam(slot, "probability", 0.55);
        }
        else if(role == ROLE_OWL)
        {
            c.sendParam(slot, "owlMode", 0);
            c.sendParam(slot, "quantizeRecall", 0);
            c.sendParam(slot, "seedCooldownMs", 400);
            c.sendParam(slot, "eddiesEnabled", 0);
            c.sendParam(slot, "phraseOnlyEddies", 1);
            c.sendParam(slot, "seedProb", 0);
        }

        if(role != ROLE_OWL)
        {
            c.sendParam(slot, "eddiesEnabled", 1);
            c.sendParam(slot, "phraseOnlyEddies", 0);
        }

        c.sendParam(slot, "roleGain", gain);
    }

    fun void sendBaseline(Conductor @ c, int slot, int role)
    {
        if(c == null) return;
        _baselines.sendParams(c, slot, role);
    }
}
