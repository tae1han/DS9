@import "config.ck"
@import "SMIR.ck"
@import {"smuck", "smuck/ezFluidInst.ck"}
@import {"bufferState.ck", "oscBufferState.ck", "agent.ck", "phraseMemory.ck"}
@import {"instruments/sf2Util.ck", "instruments/roleTimbres.ck"}
@import {"instruments/albatrossSynthInst.ck", "instruments/glideBassInst.ck", "instruments/arpInst.ck"}
@import {"agents/parrot.ck", "agents/parakeet.ck", "agents/albatross.ck", "agents/peacock.ck"}
@import {"agents/emu.ck", "agents/falcon.ck", "agents/swan.ck", "agents/owl.ck"}
@import "roleBaselines.ck"
@import "roleGains.ck"
@import {"graphics/clientFlash.ck"}

8 => int NUM_AGENT_SLOTS;
4 => int ROLE_EMU;
7 => int ROLE_OWL;

9000 => int OSC_LISTEN_PORT_BASE;
8889 => int SERVER_STATUS_PORT;
9100 => int CLIENT_CONTROL_PORT_BASE;
8891 => int SERVER_PULSE_PORT;
8892 => int SERVER_LINK_PORT;
8893 => int SERVER_LINK_REPLY_PORT;
9200 => int AGENT_BUS_PORT_BASE;
2.0 => float LINK_TIMEOUT_SEC;
"224.0.0.1" => string MULTICAST_ADDR;

if(me.args() < 1) { <<< "usage: chuck client.ck:<0-7>[:local][:headless][:sim][:flash][:pkmn]" >>>; me.exit(); }
Std.atoi(me.arg(0)) => int myIndex;
if(myIndex < 0 || myIndex >= NUM_AGENT_SLOTS) me.exit();

0 => int HEADLESS;
0 => int SIM_MIX;
0 => int USE_FLASH;
0 => int USE_PKMN_TIMBRES;
for(1 => int i; i < me.args(); i++)
{
    me.arg(i) => string a;
    if(a == "local") "127.0.0.1" => MULTICAST_ADDR;
    else if(a == "headless") 1 => HEADLESS;
    else if(a == "sim") 1 => SIM_MIX;
    else if(a == "flash") 1 => USE_FLASH;
    else if(a == "pkmn") 1 => USE_PKMN_TIMBRES;
}

oscBufferState obs;
obs.oscPort(OSC_LISTEN_PORT_BASE + myIndex);

Gain master => LPF lpf => Dyno comp => NRev rev;
if(SIM_MIX) master.gain(0.38);
else master.gain(0.9);
lpf.freq(7000);
comp.limit();
rev.mix(0.05);
for(int i; i < dac.channels(); i++) rev => dac.chan(i);

RoleTimbres timbres;
Sf2Util sf2;
if(USE_PKMN_TIMBRES)
{
    for(0 => int r; r < 8; r++)
    {
        timbres.poolForRole(r) @=> string pool[];
        for(int j; j < pool.size(); j++) sf2.load(pool[j]);
    }
}

albatrossSynthInst instAlba;
glideBassInst instGlide; instGlide.gain(0.85);
arpInst instFallback; instFallback.gain(1.0);

Parrot parrot; Parakeet parakeet; Albatross albatross; Peacock peacock;
Emu emu; Falcon falcon; Swan swan; Owl owl;
Agent @ agents[8];
ezInstrument @ insts[8];
PhraseMemory phraseMem;
-1 => int activeRole;
myIndex => int pendingRole;
-2 => int pendingTimbre;

RoleGains roleGains;

fun void _applyInstGain(int role, float g)
{
    if(role < 0 || role >= 8) return;
    if(insts[role] != null) insts[role].gain(g);
}

fun float _roleGain(int role)
{
    return roleGains.performance(role);
}

fun int _isOwlParam(string p)
{
    return p == "owlMode" || p == "eddiesEnabled" || p == "phraseOnlyEddies"
        || p == "seedProb" || p == "quantizeRecall" || p == "seedCooldownMs"
        || p == "postSeedQuietMin" || p == "postSeedQuietMax"
        || p == "developTechnique" || p == "clearMemory";
}

parrot @=> agents[0]; parakeet @=> agents[1]; albatross @=> agents[2];
peacock @=> agents[3]; emu @=> agents[4]; falcon @=> agents[5];
swan @=> agents[6]; owl @=> agents[7];
RoleBaselines roleBaselines;
instAlba @=> insts[2];
instGlide @=> insts[4];

obs @=> parrot.source; obs @=> parakeet.source; obs @=> albatross.source;
obs @=> peacock.source; obs @=> emu.source; obs @=> falcon.source;
obs @=> swan.source; obs @=> owl.source;
owl.bindMemory(phraseMem);

OscOut agentOut;
OscOut pulseOut;
pulseOut.dest(MULTICAST_ADDR, SERVER_PULSE_PORT);

for(0 => int r; r < 8; r++)
{
    if(r == 2) instAlba @=> insts[r];
    else if(r == 4) instGlide @=> insts[r];
    else
    {
        if(USE_PKMN_TIMBRES)
        {
            timbres.poolForRole(r) @=> string pool[];
            if(pool.size() > 0)
            {
                sf2.load(pool[0]) @=> ezFluidInst @ def;
                if(def != null) def @=> insts[r];
            }
            else instFallback @=> insts[r];
        }
        else instFallback @=> insts[r];
    }
    if(insts[r] != null)
        insts[r].gain(_roleGain(r));
    insts[r] @=> agents[r].inst;
    agents[r].masterRef(master);
    agents[r].run();
    agents[r].disable();
    agents[r].bindAgentBus(agentOut, myIndex, MULTICAST_ADDR, AGENT_BUS_PORT_BASE, NUM_AGENT_SLOTS);
    agents[r].bindPulseOut(pulseOut);
}

ClientFlash @ flash;
0 => int _linkConnected;
time _linkDeadline;

fun void _updateFlashRoleTint()
{
    if(flash == null) return;
    if(activeRole >= 0) flash.setRoleTint(activeRole);
    else if(pendingRole >= 0) flash.setRoleTint(pendingRole);
    else flash.setRoleTint(myIndex);
}

fun void _serverLinkBus()
{
    OscIn linkIn;
    OscMsg linkMsg;
    OscOut linkOut;
    linkIn.port(SERVER_LINK_PORT);
    linkIn.addAddress("/ds9/link/ping");
    linkOut.dest(MULTICAST_ADDR, SERVER_LINK_REPLY_PORT);

    while(true)
    {
        linkIn => now;
        while(linkIn.recv(linkMsg))
        {
            now + LINK_TIMEOUT_SEC::second => _linkDeadline;
            if(!_linkConnected)
            {
                1 => _linkConnected;
                if(flash != null) flash.setLinked(1);
                <<< "v10 client", myIndex, "linked to server" >>>;
            }
            linkOut.start("/ds9/link/pong");
            myIndex => linkOut.add;
            linkOut.send();
        }
    }
}

fun void _linkWatchdog()
{
    while(true)
    {
        200::ms => now;
        if(_linkConnected && now > _linkDeadline)
        {
            0 => _linkConnected;
            if(flash != null) flash.setLinked(0);
            <<< "v10 client", myIndex, "server link lost" >>>;
        }
    }
}

if(USE_FLASH)
{
    ClientFlash f(myIndex) --> GG.scene();
    f @=> flash;
    GG.camera().orthographic();
    @(1, 1, 1) => GG.scene().ambient;
    GG.bloom(true);
    GG.bloomPass().intensity(1.5);
    GG.fullscreen();
    @(0, 0, 14) => GG.camera().pos;
    flash.setLinked(0);
    <<< "v10 client", myIndex, "fullscreen flash (white until server link)" >>>;
    spork ~ _serverLinkBus();
    spork ~ _linkWatchdog();
}

fun void _pickTimbre(int role, int idx)
{
    if(!USE_PKMN_TIMBRES) return;
    if(role == 2 || role == 4) return;
    timbres.poolForRole(role) @=> string pool[];
    if(pool.size() == 0) return;
    if(idx == -2) return;
    if(idx < 0) Math.random2(0, pool.size() - 1) => idx;
    idx % pool.size() => idx;
    sf2.load(pool[idx]) @=> ezInstrument @ ni;
    if(ni == null)
    {
        <<< "client", myIndex, "timbre missing for role", role, "idx", idx >>>;
        return;
    }
    if(activeRole == role)
    {
        if(insts[role] != null) insts[role] =< master;
        ni.gain(_roleGain(role));
        ni @=> insts[role];
        agents[role].setInstrument(ni);
        agents[role].enable();
        <<< "client", myIndex, "timbre", idx, "role", role, pool[idx] >>>;
    }
    else if(pendingRole == role)
    {
        ni.gain(_roleGain(role));
        ni @=> insts[role];
    }
}

fun void _releaseAllVoices(ezInstrument @ i)
{
    if(i == null) return;
    for(0 => int v; v < i.numVoices(); v++)
    {
        ezNote off(0, 0.01, 60, 0);
        i.noteOff(off, v);
        i.release_voice(v);
    }
}

fun void _deactivateCurrent()
{
    instGlide.allOff();
    instAlba.allOff();
    if(activeRole >= 0)
    {
        agents[activeRole].disable();
        if(insts[activeRole] != null)
        {
            insts[activeRole] =< master;
            _releaseAllVoices(insts[activeRole]);
        }
    }
    -1 => activeRole;
}

fun void _panicAllAgents()
{
    instGlide.allOff();
    instAlba.allOff();
    for(0 => int r; r < 8; r++)
    {
        agents[r].disable();
        if(insts[r] != null)
        {
            insts[r] =< master;
            _releaseAllVoices(insts[r]);
        }
    }
    -1 => activeRole;
    -1 => pendingRole;
    -2 => pendingTimbre;
}

fun void _activate(int role)
{
    if(role < 0)
    {
        // Keep pendingRole/pendingTimbre — conductor sends activate(0) then (1).
        _deactivateCurrent();
        return;
    }
    if(activeRole >= 0)
    {
        agents[activeRole].disable();
        if(insts[activeRole] != null) insts[activeRole] =< master;
    }
    role => activeRole;
    if(pendingTimbre >= -1)
    {
        _pickTimbre(role, pendingTimbre);
        -2 => pendingTimbre;
    }
    if(insts[role] != null)
        insts[role] =< master;
    agents[role].setInstrument(insts[role]);
    agents[role].enable();
    _updateFlashRoleTint();
}

spork ~ obs.oscListen();
spork ~ obs.rollingReaper();
fun void _pushMem() { while(true) { obs.phraseCompleteEvent => now; phraseMem.push(obs.completedPhrase.notes()); } }
spork ~ _pushMem();

fun void _routeHumanMidi()
{
    int on[1];
    int pitch[1];
    float vel[1];

    while(true)
    {
        obs.midiQueueEvent => now;
        while(obs.mqPop(on, pitch, vel))
        {
            if(SMIR.skipForPitchSet(pitch[0])) continue;
            // Flash only follows agent /ds9/pulse (this slot), not server-forwarded MIDI OSC.
            if(activeRole < 0) continue;
            if(!agents[activeRole].enabled || !agents[activeRole].shouldActivate()) continue;

            if(on[0])
            {
                ezNote n(0.0, 0.0, pitch[0], vel[0]);
                agents[activeRole].onNote(n);
            }
            else
            {
                agents[activeRole].onNoteOff(pitch[0]);
            }
        }
    }
}

fun void _flashPulseBus()
{
    OscIn pulseIn;
    OscMsg pulseMsg;
    SERVER_PULSE_PORT => pulseIn.port;
    pulseIn.addAddress("/ds9/pulse");

    while(true)
    {
        pulseIn => now;
        if(!USE_FLASH || flash == null) continue;
        while(pulseIn.recv(pulseMsg))
        {
            pulseMsg.getInt(0) => int slot;
            pulseMsg.getFloat(1) => float vel;
            flash.triggerPulse(slot, vel);
        }
    }
}

OscOut statusOut; statusOut.dest(MULTICAST_ADDR, SERVER_STATUS_PORT);
fun void _status()
{
    while(true)
    {
        100::ms => now;
        statusOut.start("/ds9/status");
        myIndex => statusOut.add;
        activeRole => statusOut.add;
        if(activeRole >= 0)
        {
            agents[activeRole].displayStatus => statusOut.add;
            agents[activeRole].displayBody => statusOut.add;
            1 => statusOut.add;
            agents[activeRole].listenTarget => statusOut.add;
        }
        else { 0 => statusOut.add; "" => statusOut.add; 0 => statusOut.add; -1 => statusOut.add; }
        statusOut.send();
    }
}
spork ~ _status();

OscIn agentIn; OscMsg agentMsg;
AGENT_BUS_PORT_BASE + myIndex => agentIn.port;
agentIn.addAddress("/ds9/agent/noteOn");
agentIn.addAddress("/ds9/agent/phraseComplete");
fun void _agentBus()
{
    while(true)
    {
        agentIn => now;
        while(agentIn.recv(agentMsg))
        {
            if(activeRole < 0) continue;
            if(agentMsg.address == "/ds9/agent/noteOn")
            {
                agentMsg.getInt(4) => int hop;
                if(!agents[activeRole].acceptAgentHop(hop)) continue;
                agents[activeRole].onAgentNote(agentMsg.getInt(0), agentMsg.getInt(1), agentMsg.getFloat(2), agentMsg.getFloat(3), hop);
            }
            else
            {
                agentMsg.getInt(1) => int nn;
                agentMsg.getInt(2) => int hop;
                ezNote ph[0];
                for(int i; i < nn; i++)
                {
                    3 + i * 4 => int b;
                    ezNote n(agentMsg.getFloat(b+3), agentMsg.getFloat(b+2), agentMsg.getInt(b), agentMsg.getFloat(b+1));
                    ph << n;
                }
                if(!agents[activeRole].acceptAgentHop(hop)) continue;
                agents[activeRole].onAgentPhrase(agentMsg.getInt(0), ph, hop);
            }
        }
    }
}
spork ~ _agentBus();

OscIn controlIn; OscMsg controlMsg;
CLIENT_CONTROL_PORT_BASE + myIndex => controlIn.port;
controlIn.addAddress("/ds9/control/activate");
controlIn.addAddress("/ds9/control/setRole");
controlIn.addAddress("/ds9/control/setListenTarget");
controlIn.addAddress("/ds9/control/setParam");
fun void _control()
{
    while(true)
    {
        controlIn => now;
        while(controlIn.recv(controlMsg))
        {
            if(controlMsg.getInt(0) != myIndex) continue;
            if(controlMsg.address == "/ds9/control/activate")
            {
                if(controlMsg.getInt(1) > 0)
                {
                    if(pendingRole >= 0) _activate(pendingRole);
                    else if(activeRole >= 0) agents[activeRole].enable();
                }
                else _activate(-1);
            }
            else if(controlMsg.address == "/ds9/control/setRole")
            {
                controlMsg.getInt(1) => pendingRole;
                _updateFlashRoleTint();
            }
            else if(controlMsg.address == "/ds9/control/setListenTarget")
            {
                controlMsg.getInt(1) => int t;
                if(activeRole >= 0) agents[activeRole].setListenTarget(t);
                else agents[pendingRole].setListenTarget(t);
            }
            else if(controlMsg.address == "/ds9/control/setParam")
            {
                controlMsg.getString(1) => string p;
                controlMsg.getFloat(2) => float v;
                if(p == "timbreIndex")
                {
                    v $ int => pendingTimbre;
                    int r;
                    if(activeRole >= 0) activeRole => r;
                    else if(pendingRole >= 0) pendingRole => r;
                    else myIndex => r;
                    if(r >= 0) _pickTimbre(r, pendingTimbre);
                    -2 => pendingTimbre;
                }
                else if(p == "glideMode" && (activeRole == ROLE_EMU || pendingRole == ROLE_EMU))
                {
                    agents[ROLE_EMU].setParam(p, v);
                    if(v > 0) instGlide @=> insts[ROLE_EMU];
                    else _pickTimbre(ROLE_EMU, -1);
                    if(activeRole == ROLE_EMU || pendingRole == ROLE_EMU)
                        insts[ROLE_EMU] @=> agents[ROLE_EMU].inst;
                }
                else if(p == "panic")
                {
                    _panicAllAgents();
                }
                else if(p == "roleGain")
                {
                    int r;
                    if(pendingRole == ROLE_OWL) ROLE_OWL => r;
                    else if(activeRole >= 0) activeRole => r;
                    else if(pendingRole >= 0) pendingRole => r;
                    else myIndex => r;
                    _applyInstGain(r, v);
                }
                else if(p == "resetBaseline")
                {
                    int r;
                    if(activeRole >= 0) activeRole => r;
                    else if(pendingRole >= 0) pendingRole => r;
                    else myIndex => r;
                    roleBaselines.applyAgent(agents[r], r);
                    _applyInstGain(r, roleGains.performance(r));
                }
                else if(_isOwlParam(p))
                    agents[ROLE_OWL].setParam(p, v);
                else if(activeRole >= 0) agents[activeRole].setParam(p, v);
                else if(pendingRole >= 0) agents[pendingRole].setParam(p, v);
            }
        }
    }
}
spork ~ _control();

<<< "v10 client", myIndex, "OSC in", OSC_LISTEN_PORT_BASE + myIndex,
    "control", CLIENT_CONTROL_PORT_BASE + myIndex,
    "agentBus", AGENT_BUS_PORT_BASE + myIndex >>>;

<<< "v10 client", myIndex, "ready (default role", myIndex, ")" >>>;

spork ~ _routeHumanMidi();
if(USE_FLASH) spork ~ _flashPulseBus();

while(true)
{
    if(USE_FLASH && flash != null) { flash.tick(); GG.nextFrame() => now; }
    else 100::ms => now;
}
