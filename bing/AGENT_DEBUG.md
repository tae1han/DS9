# Agent debug (single station)

Isolate **one client** with PKMN soundfonts. Server keeps live piano monitor; **no auto score**.

## Run

```bash
cd DS9/v10-dev
./scripts/local-debug "USB Midi Cable" 0
```

Slot `0` = first station (Parrot by default layout). Optional `display` for projected stage.

## Control (second terminal)

Same OSC messages the conductor will use in performance (`9100 + slot`).

### Hear Parrot respond

1. Run `./scripts/local-debug "USB Midi Cable" 0`
2. Second terminal: `chuck tests/localSend.ck:parrot:0`
3. Play **at least 2 notes**, then **pause ~0.3s** (phrase boundary)
4. Parrot echoes after a short delay (up to ~4s)

Check `.local-logs/client-0.log` for lines like `sf2: flute.sf2 prog 13` (not `prog 0`). If you see `No preset found`, restart after pulling latest code.

### Parrot on slot 0

```bash
# Start: Parrot, echo mode, timbre 0 (Xylophone), listen to soloist
chuck tests/localSend.ck:parrot:0

# Mode switching (live — no re-activate needed)
chuck tests/localSend.ck:echo:0
chuck tests/localSend.ck:develop:0          # random develop technique
chuck tests/localSend.ck:developTech:0:2    # force inversion (0=retro 1=seq 2=inv 3=aug 4=dim)
chuck tests/localSend.ck:delay:0:0.05:0.5   # response delay after phrase (seconds)

# Timbre (live swap if already active)
chuck tests/localSend.ck:timbre:0:1    # Nylon Guitar
chuck tests/localSend.ck:timbre:0:2    # E. Piano
chuck tests/localSend.ck:timbre:0:3    # Chiffer Lead

# Re-activation (tests timbre on deactivate → activate)
chuck tests/localSend.ck:deactivate:0
chuck tests/localSend.ck:timbre:0:2
chuck tests/localSend.ck:activate:0:1

# Or one shot: reactivate with new timbre
chuck tests/localSend.ck:reactivate:0:3
chuck tests/localSend.ck:reactivate:0:-1   # random timbre from pool
```

### Parrot timbre pool (index → file)

| Index | File (`data/`) |
|-------|----------------|
| 0 | xylophone.sf2 |
| 1 | nylon_end.sf2 |
| 2 | epiano.sf2 |
| 3 | chiffer.sf2 |

### Low-level (any agent later)

```bash
chuck tests/localSend.ck:role:0:0
chuck tests/localSend.ck:param:0:mode:0
chuck tests/localSend.ck:listen:0:-1
chuck tests/localSend.ck:activate:0:1
chuck tests/localSend.ck:deactivate:0
```

## Workflow for next agents

1. Change slot in `local-debug` (or run `./scripts/local-debug "USB Midi Cable" 3` for Peacock).
2. Add matching commands to `tests/localSend.ck` (mirror conductor API).
3. When satisfied, fold calls into `score/movements.ck`.
