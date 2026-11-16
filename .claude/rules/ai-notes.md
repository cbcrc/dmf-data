<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Measurement traps (repo-wide)

Loaded into every Claude Code session; Copilot users open it explicitly (AGENTS.md).
Each entry: the trap, the symptom, the fix, and the study where it bit. Add a trap here
the moment one costs you a run; a study's caveats explain it for people, this file keeps
the next session from repeating it. Dense on purpose.

## Host

- **CPU governor.** `schedutil` (Ubuntu default) clocks idle cores down between frames.
  A reader that sleeps ~33 ms per grain wakes on a fast or slow core at random: 2x spread
  in read times, and cross-socket can look *faster* than local. Fix: `performance` on
  every core used, checked in `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor`
  before each run, recorded in Setup. Bit: infra/2026-10-cross-numa-grain-transit.
- **Ring fits in L3.** Xeon Silver 4510 L3 = 30 MB per socket. A 1080p v210 ring of 5
  grains = 27.6 MB, so reads hit cache, not DRAM. Use 2160p (22 MB grains) or compute
  `ring bytes` vs `L3 per socket` before trusting a memory-path number.
- **Freshly committed grain is warm.** Reading at head+1 right after commit pulls from the
  writer's L3, not DRAM. Lag the reader (head-3 at 2160p = 66 MB of newer writes > 30 MB
  L3). Scenarios `16`/`17-*-2160p-lag3` in mxl-api-bench do this.
- **Readers feed each other.** Several readers on the remote socket: the first pulls from
  DRAM over UPI, the rest snoop its cache. Cross-socket penalty shrinks to ~+4 %. Isolate
  one remote reader per run to measure a true remote read.
- **Remote reads slow the writer.** The directory marks lines read by the other socket;
  the writer's next RFO on that line waits for a snoop. Always report writer fill next to
  reader touch, not reader-only.
- **Shared hosts.** Other tenants (ffmpeg / ST 2110 containers, other users) move results.
  Record `docker ps` and load at run time; prefer an idle host.

## Clocks and cross-host timing

- **`transit_ms` across hosts = transport + clock offset.** `stamp.transit_ms` subtracts the
  writer's `mxlGetTime()` (host A clock) from the reader's (host B clock). With NTP only,
  the offset is unknown at run time and drifts between days. Robust: differences between
  runs close in time, and jitter (p99 − p50). Not robust: the absolute level. Bound it with
  the minimum observed transit vs. the wire time (grain bytes × 8 / link rate). Use PTP
  on both hosts for an absolute figure. Bit: network-transport/2026-10-rdma-grain-transit
  (Verbs p50 0.63 ms on two days, 0.75–0.78 ms on two others; the setup did not change
  knowingly, so clock offset is the first suspect).
- **`age_ms`** on a remote reader also mixes both clocks (grain origin time vs reader
  clock). Same caveat.
- Record `chronyc tracking` (or `pmc` for PTP) on both hosts at run time, not later.

## mxl-api-bench logs

- **Event logs append across runs.** `events.ndjson` keeps every session since the file
  was created; a `/reset` or restart starts `seq` at 1 again, and a new file is
  `events.N.ndjson`. Split on `seq == 1` or a time gap before computing stats, or a
  20-minute run is averaged with a 1-minute test.
- **Lane C is not latency.** The once-per-second non-blocking head probe measures where in
  the frame the probe lands (~half a frame at p50). Report lane B only.
- **`MXL_ERR_OUT_OF_RANGE_TOO_EARLY` after the writer stops** is a remote reader asking for
  grains that will never come; it is not a transport failure. Count failures inside the
  writer's active window only.
- `touch_ms` exists only when the run set `touch_payload`. The Sep–Oct 2026 RDMA runs logged
  none on either host (stamp-only reads), even though today's `09-transit-remote-reader`
  sets `touch_payload: "lines"`: check the log, not the scenario file.
- **Raw logs are not published** (AGENTS.md). Keep the per-run stats table and the exact
  command that produced it.
