// Per-role soundfont pools (filenames in data/).

public class RoleTimbres
{
    string parrot[0];
    string parakeet[0];
    string peacock[0];
    string emu[0];
    string falcon[0];
    string swan[0];
    string owl[0];

    fun RoleTimbres()
    {
        parrot << "xylophone.sf2";
        parrot << "nylon_end.sf2";
        parrot << "epiano.sf2";
        parrot << "chiffer.sf2";

        parakeet << "harp.sf2";

        peacock << "nylon_end.sf2";
        peacock << "harp.sf2";

        emu << "horn.sf2";

        falcon << "epiano.sf2";
        falcon << "harp.sf2";
        falcon << "chiffer.sf2";
        falcon << "flute.sf2";

        swan << "flute.sf2";

        owl << "flute.sf2";
        owl << "bowed_glass.sf2";
    }

    fun string[] poolForRole(int roleId)
    {
        if(roleId == 0) return parrot;
        if(roleId == 1) return parakeet;
        if(roleId == 3) return peacock;
        if(roleId == 4) return emu;
        if(roleId == 5) return falcon;
        if(roleId == 6) return swan;
        if(roleId == 7) return owl;
        string empty[0];
        return empty;
    }
}
