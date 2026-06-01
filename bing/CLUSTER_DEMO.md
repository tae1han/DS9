# Nine-machine cluster demo (server + 8 clients)

One script per machine. Each laptop runs the same `DS9/v10-dev` tree (git pull / rsync so versions match).

## Roles

| Machine | Script | What runs |
|---------|--------|-----------|
| **Center** (piano + GameTrak) | `./scripts/parrot-server` | `server.ck` (your MIDI monitor) + `autonomousFeeder.ck` + `gametrakConductor.ck` |
| **Station 1** | `./scripts/parrot-client 1` | `client.ck:0:pkmn:flash` — Parrot + fullscreen flash |
| **Station 2** | `./scripts/parrot-client 2` | slot 1 — Parakeet (harp.sf2) |
| **Station 3** | `./scripts/parrot-client 3` | slot 2 — Albatross |
| **Station 4** | `./scripts/parrot-client 4` | slot 3 — Peacock |
| **Station 5** | `./scripts/parrot-client 5` | slot 4 — Emu |
| **Station 6** | `./scripts/parrot-client 6` | slot 5 — Falcon |
| **Station 7** | `./scripts/parrot-client 7` | slot 6 — Swan |
| **Station 8** | `./scripts/parrot-client 8` | slot 7 — Owl |

Default layout: **station N = slot N−1 = role N−1**.

## Network

- All machines on the **same Ethernet subnet** (wired strongly preferred).
- OSC uses **multicast `224.0.0.1`** (scripts do **not** use `:local`).
- Turn off Wi‑Fi on performance laptops if multicast is flaky (scripts try `networksetup -setairportpower en0 off` on macOS).
- Allow UDP multicast between machines (no AP “client isolation”).

## Startup order

1. On **each station laptop 1–8** (can be parallel):
   ```bash
   cd /path/to/DS9/v10-dev
   chmod +x scripts/parrot-client
   ./scripts/parrot-client 1   # use 2, 3, … 8 on the other laptops
   ```
   Each window should print `v10 client N ready` and show **fullscreen black/white flash** when that agent plays.

2. On the **center** laptop:
   ```bash
   cd /path/to/DS9/v10-dev
   chmod +x scripts/parrot-server scripts/parrot-stop
   ./scripts/parrot-server "USB Midi Cable"
   ```
   Adjust the MIDI name to match `chuck --probe` on that machine.

3. Wait **~1.2 s** after GameTrak reports ready, then use pedals (or keyboard **1–9** on the server machine if GameTrak uses the keyboard fallback).

## Performance arc (GameTrak on server)

| Step | Action |
|------|--------|
| 1 | Pedal 1 — Chaos2 + feeder on |
| MIDI | First note — mute all agents |
| 2–7 | Movements 2–7 |
| 8 | All Parakeet harmonize you → **stations fade out one by one** (~12s + 2.5s each) |
| 9 | Solo |

**Current movement** prints to `.cluster-logs/gametrak.log` on the server:

```bash
tail -f .cluster-logs/gametrak.log
```

## Logs (server machine)

| File | Content |
|------|---------|
| `.cluster-logs/server.log` | (foreground terminal) |
| `.cluster-logs/feeder.log` | Atonal feeder |
| `.cluster-logs/gametrak.log` | Pedals + movement banners |

Client issues: watch the client terminal or re-run that station’s `parrot-client`.

## Stop

- **Server:** Ctrl+C in the server terminal (stops server + feeder + gametrak), or `./scripts/parrot-stop` on any machine that might be running chuck from this repo.
- **Clients:** Ctrl+C on each station.

## Prerequisites (each machine)

- [ChucK](https://chuck.cs.princeton.edu/) in `PATH`
- Same `v10-dev` checkout including `data/*.sf2`
- ChuGL available for `:flash` on clients (ChucK built with ChuGL)

## One-machine rehearsal

Use `./scripts/local-perform` instead — all processes on one host with `:local` multicast loopback. Cluster scripts are for the real 9-laptop install only.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Clients silent, no OSC | Multicast blocked; use Ethernet; same repo version |
| Flash works, no agent audio | `data/*.sf2` missing on that laptop; read client startup log |
| GameTrak does nothing | `./scripts/parrot-server` log; try keyboard `1` on server |
| Wrong station sound | Re-run `parrot-client` with correct station number 1–8 |
| Loud burst on pedal press | Conductor should send `activate(0)` before role changes; restart clients after updates |
