@import "conductor.ck"

// Client instrument gain (multiplies sf2Util's internal 2.5× load).
// Defaults from tests/eval.txt — used for all movements (chaos + performance arc).
public class RoleGains
{
    fun float performance(int role)
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

    fun float chaos(int role)
    {
        // Movement 1 (chaos): trim hot roles vs performance defaults.
        if(role == 2) return performance(role) * 0.7;   // Albatross −30%
        if(role == 3) return performance(role) * 0.85;  // Peacock −15%
        if(role == 4) return performance(role) * 0.9;   // Emu −10%
        if(role == 6) return performance(role) * 0.7;   // Swan −30%
        return performance(role);
    }

    fun void sendPerformance(Conductor @ c, int slot, int role)
    {
        if(c == null) return;
        c.sendParam(slot, "roleGain", performance(role));
    }

    fun void sendChaos(Conductor @ c, int slot, int role)
    {
        if(c == null) return;
        c.sendParam(slot, "roleGain", chaos(role));
    }
}
