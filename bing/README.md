# DS10 Studio

Local development clone of **v10-dev**: eight-agent ensemble with a **ChuGL conductor GUI** instead of GameTrak. Iterate on movements, levels, and modes on one machine before the cluster performance.

## Quick start

```bash
cd DS9/v10-studio
./scripts/local-studio "USB Midi Cable"
```

Opens the studio GUI (movements + 8 slot panels) plus server and headless clients. Full guide: [STUDIO.md](STUDIO.md).

**Single agent tuning** (unchanged from v10-dev):

```bash
./scripts/local-debug "USB Midi Cable" 7 flash
chuck tests/localSend.ck:owlSeed:7
```

**Cluster deploy:** copy `v10-dev/` (not this folder) — see [CLUSTER_DEMO.md](CLUSTER_DEMO.md).

## What's new in v10-studio

```
v10-studio/
├── studioConductor.ck          # ChuGL GUI conductor (replaces GameTrak locally)
├── graphics/studioGrid.ck      # 8-slot pulse grid behind the UI
├── STUDIO.md                   # studio workflow
└── scripts/local-studio        # server + 8 clients + feeder + GUI
    scripts/studio-gui          # GUI only
```

Everything else matches v10-dev: same agents, OSC (`/ds9/...`), `conductorScenes.ck`, soundfonts under `data/`.

## Client flags

`chuck client.ck:<slot>[:local][:headless][:sim][:pkmn][:flash]`

Studio local stack uses `local:pkmn:headless:sim` (no per-client flash — pulse grid is in the conductor GUI).

## Removed from v9

Same as v10-dev — see v10-dev README.
