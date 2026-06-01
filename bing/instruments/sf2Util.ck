@import {"smuck", "smuck/ezFluidInst.ck"}

// Cached loads from data/*.sf2 (dedupes shared timbres; reads embedded preset from file).
public class Sf2Util
{
    string _dataRoot;
    string _cacheNames[0];
    ezFluidInst @ _cacheInsts[0];

    fun Sf2Util()
    {
        me.dir() + "../data/" => _dataRoot;
    }

    fun int _presetProgram(string path)
    {
        FileIO sf;
        if(!sf.open(path, FileIO.READ | FileIO.BINARY)) return 0;

        int bytes[0];
        while(sf.more())
        {
            sf.readInt(IO.UINT8) => int b;
            bytes << b;
        }
        sf.close();

        for(0 => int i; i < bytes.size() - 30; i++)
        {
            if(bytes[i] == 112 && bytes[i + 1] == 104 &&
               bytes[i + 2] == 100 && bytes[i + 3] == 114)
            {
                i + 8 + 20 => int off;
                if(off + 1 < bytes.size())
                    return bytes[off] | (bytes[off + 1] << 8);
            }
        }
        return 0;
    }

    fun ezFluidInst @ load(string file)
    {
        if(file == "") return null;

        for(0 => int i; i < _cacheNames.size(); i++)
            if(_cacheNames[i] == file)
                return _cacheInsts[i];

        _dataRoot + file => string path;
        FileIO f;
        if(!f.open(path, FileIO.READ))
        {
            <<< "sf2: missing", path >>>;
            return null;
        }
        f.close();

        _presetProgram(path) => int prog;
        new ezFluidInst() @=> ezFluidInst @ inst;
        inst.open(path);
        inst.progChange(prog);
        2.5 => inst.gain;
        <<< "sf2:", file, "prog", prog >>>;

        _cacheNames << file;
        _cacheInsts << inst;
        return inst;
    }
}
