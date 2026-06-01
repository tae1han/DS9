# Eight-station local simulation

Run the full **server + 8 clients** on one machine to hear agent interactions (roles, listen targets, params) without ChuGL or eight laptops.

## Start

```bash
cd DS9/v10-dev
./scripts/local-run "USB Midi Cable"
```

- **8 clients** — `headless` (no flash), `pkmn` (real soundfonts), `sim` (lower master gain so eight DACs do not clip)
- **Server** — your MIDI → TimGM monitor + OSC to all slots; optional automated timeline

Stop: **Ctrl+C** in the server terminal, or `./scripts/local-stop`.

### One-terminal performance (recommended)

```bash
./scripts/local-perform "USB Midi Cable"
```

Starts **8 clients**, **autonomous feeder** (idle until pedal 1), **GameTrak conductor**, and the **server** in one shell. Logs: `.local-logs/`.

### Flags

| Flag | Effect |
|------|--------|
| *(default)* | No auto timeline — apply setups manually via `localSend` |
| `score` / `cues` | Run `score/movements.ck` after first MIDI note |
| `solo` | Server monitor only (no clients) |

## Manual setups (default)

Start sim, then apply one configuration at a time:

```bash
**Autonomous chaos (no keyboard until you want):**

```bash
./scripts/local-autonomous   # feeder idle, waiting for GameTrak
./scripts/local-gametrak     # pedal 1 starts chaos2
```

**Pedal 1** applies chaos2 (staggered agents) and unpauses the atonal feeder. **First MIDI** mutes. **Pedal 2** → movement 2 (Owl). Pitch-set agents (Falcon, Peacock, Swan, Albatross, etc.) respond on phrase boundaries; Parakeet gets notes in real time during each injected gesture. Owl on slot 7 is in **seed mode** with eddies enabled so silence gaps can trigger memory playback.

Manual: `chuck tests/localSend.ck:scene:chaos2` then `chuck autonomousFeeder.ck:local`

**Performance arc (GameTrak pedals):**

| Pedal | Scene |
|-------|--------|
| 1 | Chaos2 + feeder on (wait **~1.2s** after start before first pedal) |
| *(first MIDI)* | Mute all |
| 2 | **Owl A** (slot 7) echo → seed @ 10s; **Owl B** (slot 6) seed @ 18s — both listen to you |
| 3 | Parrots 0–1 echo Owls 7 & 6 → develop @ 8s → Parakeets 2–3 harmonize Owls @ 16s |
| 4 | Peacock (slot 5) + Swan (slot 6) listen to **you** → Owl 7 @ 10s |
| 5 | **4 Peacock** (slots 0–3) + **4 Swan** (slots 4–7), all listen to you |
| 6 | **All Falcon** (8 slots) |
| 7 | **Eight roles** (slot *i* = role *i*), baseline defaults, solo listen |
| 8 | **All Parakeet** harmonizing you → fade out stations one by one |
| 9 | **Solo** — Owls 7 & 6 detach from you, keep seeding |

Keyboard fallback: keys **1–9** advance one pedal each (same order as table).

Or manually:

```bash
chuck tests/localSend.ck:scene:chaos
chuck tests/localSend.ck:scene:mute
chuck tests/localSend.ck:scene:parrotEcho
```
```

Movement 1 matches `score/movements.ck` (Parrot echo, Parakeet mirror, Emu bass, Owl echo + quantize recall, etc.) but **activates all eight stations at once** instead of the staged 6s/2s cue timeline.

Other presets: `scene:chain`, `scene:develop`, `scene:owlSeed`.

## Scheduling cues (optional)

Pass **`score`** to `local-run` to enable automation. Edit **`score/movements.ck`**. The server `Conductor` sends the same OSC as `tests/localSend.ck`:

- `sendRole(slot, roleId)`
- `sendListenTarget(slot, target)` — `-1` = human MIDI, `0–7` = another slot’s agent bus
- `sendParam(slot, name, value)`
- `sendActivate(slot, 0|1)`
- `sendCueAll("text")` — prints to server log (projector cues in performance)

Timeline starts when you play the first MIDI note into the server.

Default layout: **slot *i* → role *i*** (Parrot on 0, Owl on 7).

## Manual scenes (no timeline)

Per-slot tuning still uses the existing commands (`parrot:3`, `owlSeed:7`, `listen:5:4`, `param:…`, etc.).

## What you hear

- **Server** — TimGM piano on your keyboard input
- **Each client** — one agent when activated; all share the same machine audio output
- **Agent bus** — multicast `/ds9/agent/…` between slots (listen targets)

Play phrases on the keyboard; agents on active slots react according to role + listen target.

## Logs

`.local-logs/client-0.log` … `client-7.log` — startup, `sf2:` loads, errors.

## CPU note

Eight ChucK + FluidSynth processes is heavy. Close other audio apps; if a client dies, check its log and re-run `./scripts/local-stop` then `local-run`.
