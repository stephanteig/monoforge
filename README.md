# MonoForge

> ⚠️ **Status: work in progress — not functional yet.** The script launches and shows its GUI, but the audio channel mapping does not work reliably. Do not use on real projects.

Bulk audio channel router for **DaVinci Resolve**. Built for interview recordings where each microphone sits on its own channel in a multichannel WAV: instead of re-mapping audio clip by clip in *Clip Attributes*, MonoForge re-maps the channels on every selected clip at once.

## Planned functionality

- Scan the active timeline and list its audio tracks
- Route a chosen source channel to L/R on all clips on a track — in bulk
- Debug mode that logs the applied mapping per clip

## Install

Copy `MonoForge.lua` to Resolve's Utility scripts folder, then run it from **Workspace → Scripts → Utility → MonoForge**.

## Debugging

The script writes a log to `~/Desktop/MonoForge.log` on every run — check it if the GUI never appears or a mapping fails.

## Roadmap

The current blocker is the `AudioMapping` XML not being accepted consistently by the Resolve API. A rewrite is planned once the approach is validated (possibly via [resolve-mcp-studio](https://github.com/stephanteig/resolve-mcp-studio) tooling).
