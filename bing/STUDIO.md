# DS10 Studio — local 8-slot sim with ChuGL conductor

`v10-studio` is a clone of `v10-dev` for **single-machine iteration**: server + eight headless clients + a ChuGL GUI that replaces GameTrak. Use it to try movements, tune levels, and experiment with role/mode combinations before the live performance.

## Start everything

```bash
cd DS9/v10-studio
./scripts/local-studio "USB Midi Cable"
```

This launches:

| Process | Purpose |
|---------|---------|
| 8 × `client.ck` | Headless agents (`local:pkmn:headless:sim`) |
| `autonomousFeeder.ck` | Atonal phrase injector (paused until you enable it) |
| `studioConductor.ck` | **ChuGL GUI** — movements + per-slot controls |
| `server.ck` | Your MIDI → TimGM monitor + OSC to all slots |

Stop with **Ctrl+C** in the server terminal, or `./scripts/local-stop`.

## Studio GUI

Two ImGui windows plus an 8-cell pulse grid:

### Movements

One-click presets matching the GameTrak performance arc:

- **Chaos2 + feeder** — staggered activation (pedal 1)
- **Movement 2–8, Solo** — same scenes as `conductorScenes.ck`
- **M1, Chaos, Mute, All Parrot echo**
- **Feeder paused** / **MIDI forward** toggles
- **Deactivate all** / **Default layout**

After **Chaos2**, the first piano note triggers **mute** (server `:pad` behavior).

### Slots (0–7)

Per station:

| Control | OSC |
|---------|-----|
| Active | `/ds9/control/activate` |
| Role | `/ds9/control/setRole` |
| Listen | `/ds9/control/setListenTarget` (−1 = you, 0–7 = agent) |
| Gain | `roleGain` param |
| Probability | `probability` param |
| Mode | Role-specific (`mode`, `rtMode`, `glideMode`, `owlMode`) |
| Apply slot | Full deactivate → configure → activate |
| Reset baseline | `resetBaseline` + performance gain |

The pulse grid flashes when agents play (via `/ds9/pulse`). Slot frames highlight when active.

### GUI only (stack already running)

```bash
./scripts/studio-gui
```

## Workflow tips

1. Start `./scripts/local-studio`, wait for the ChuGL window.
2. Click **M1 baseline** or configure slots manually.
3. Play piano — hear TimGM on the server plus active agents.
4. Adjust **Gain** live while a slot is active (Parakeet/Swan defaults are hot).
5. Try **Movement** buttons to audition full arc sections.
6. Use **Reset baseline** after chaos/mute to restore `agents/defaults.txt` values.

For fine param tweaks beyond the GUI, still use:

```bash
chuck tests/localSend.ck:param:3:timingScale:0.5
```

## vs v10-dev

| | v10-dev | v10-studio |
|--|---------|------------|
| Conductor | GameTrak / keyboard 1–9 | ChuGL GUI |
| Clients | headless or `:flash` per laptop | always headless + sim mix |
| Purpose | cluster performance | local tuning & movement design |

Core agents, OSC wire format, and `conductorScenes.ck` are unchanged.

## Logs

`.local-logs/client-*.log`, `feeder.log`, `studio.log`

If the studio window fails to open, check `studio.log` — ChuGL must be built into your `chuck` binary.
