# DS10 local debug

From `DS9/v10-dev`:

```bash
./scripts/local-debug "USB Midi Cable" 7 flash
chuck tests/localSend.ck:owlSeed:7
```

- **Server:** MIDI → TimGM monitor + OSC to clients (`data/TimGM6mb.sf2`)
- **Client:** `:pkmn` loads from `data/*.sf2`; `:flash` = fullscreen black/white on **this client's agent** notes only
- **Agents:** same eight birds as v9; see `AGENT_DEBUG.md` for per-role commands

Logs: `.local-logs/client-<slot>.log`
