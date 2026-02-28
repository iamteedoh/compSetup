# Fix Audio — Douk DAC Recovery

Recovers the Douk Audio USB DAC when PipeWire gets stuck in a broken state.

## Problem

The Douk Audio DAC (C-Media "USB HIFI AUDIO") occasionally loses audio output because PipeWire's ALSA node enters a `(null)` error state and locks the device open. This can also happen if the default sink switches to the wrong device (e.g., the motherboard's onboard USB audio).

## Usage

```
fix-audio.sh
```

## What it does

1. Stops PipeWire, PipeWire-Pulse, and WirePlumber
2. Waits for the ALSA device to be released
3. Restarts all three services
4. Finds the Douk Audio node and sets it as the default sink
5. Sets volume to 10%

## Related config

- `~/.config/wireplumber/wireplumber.conf.d/51-douk-audio.conf` — WirePlumber rule that prevents node suspension and adds USB buffer headroom for the Douk Audio DAC

## Installation

Deployed automatically by the `fix_audio` Ansible role in compSetup. Enable it via the Custom Installation menu (option 7 on Fedora) or pass `--install-fix-audio` on the command line.

Files installed:
- `~/.local/bin/fix-audio.sh` — recovery script (mode 0755)
- `~/.config/wireplumber/wireplumber.conf.d/51-douk-audio.conf` — WirePlumber config (mode 0644)
