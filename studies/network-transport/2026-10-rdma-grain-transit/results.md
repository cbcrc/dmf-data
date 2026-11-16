<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# MXL grain transit between two hosts over MXL fabrics: detailed results

The executive summary is in [`README.md`](README.md). This page holds the evidence: setup, method, every
session and the caveats. The steps to run it again are in [`how-to-reproduce.md`](how-to-reproduce.md). The two lab hosts are called **host A** (the sender) and **host B**
(the receiver), the same machines as in the
[cross-NUMA study](../../infra/2026-10-cross-numa-grain-transit/results.md).

## Bottom line

A 1080p29.97 v210 flow (5.5 MB grains) was written on host A, carried to host B by the MXL fabrics demo over a
200 GbE RoCE link, and read on host B. Transit is the time from the writer stamping a grain on host A to a
reader on host B waking up with it.

- **Verbs provider (RDMA):** transit p50 **0.63-0.78 ms**, p99 0.65-0.82 ms. The spread p99 − p50 is
  0.02-0.06 ms.
- **TCP provider:** transit p50 **3.5-3.9 ms**, p99 5.1-5.5 ms, max up to 9.7 ms. The spread p99 − p50 is
  1.5-1.7 ms. (Ranges over the sessions of each kind, leaving out a 7-second test.)
- **Same-host reference:** a reader on the writer's own host sees 0.07 ms p50.
- **Nothing was lost.** Across 11 remote sessions and about 119 000 remote reads, no grain was skipped and no
  read failed while the flow was running. Every remote reader read at exactly 29.97 grains per second.
- **Clocks were synchronised by NTP only.** The TCP-vs-Verbs difference and the spreads are robust; the absolute
  Verbs level carries an uncertainty of a few tenths of a millisecond at most ([Clock offset](#clock-offset)).

## Setup

| | Host A | Host B |
|---|---|---|
| Role | MXL writer, a local reader, and the fabrics **initiator** (sender) | Fabrics **target** (receiver), which writes the flow into host B's MXL domain, and the remote reader |
| CPU | 2 x Intel Xeon Silver 4510 (Sapphire Rapids), 12 cores and 30 MB L3 per socket | same |
| NIC | NVIDIA (Mellanox) ConnectX-7, firmware 28.44.1036, port 0 at 200 Gb/s Ethernet, RoCE, `mlx5_core` | same |
| NIC locality | NUMA node 1 | NUMA node 1 |
| RoCE active MTU | 1024 B | 1024 B |
| OS | Ubuntu 24.04, kernel 6.8.0-136, Docker 29.5.3 | same |
| Clock | `chrony`, NTP, the same stratum-2 server | same |

The NIC, OS and clock rows were read from the hosts in November 2026, after the runs. They were not changed in
between as far as we know, but they were not recorded at run time.

**Software.**
- **Bench:** ABI-tester, the earlier name of [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench), as of
  2026-09-21. One instance per host, in Docker, sharing the host's MXL domain.
- **Transport:** `mxl-fabrics-demo`, the MXL fabrics demo, built from MXL branch `fabrics-demo-v1.1.0` at commit
  `c36ac00` (a fork of [dmf-mxl/mxl](https://github.com/dmf-mxl/mxl)) and run from its Docker Compose example.
  The only difference between the two configurations is the libfabric provider: `--provider tcp` or
  `--provider verbs`.

**Not recorded at run time:** the CPU governor (the `performance` setting of the cross-NUMA study was applied on
2026-10-19, after these runs, so these probably ran under the default `schedutil`), CPU and memory pinning of the
containers (none was set as far as we know), and other workloads on host A, which is shared.

## Method

```
host A                                                   host B
 bench: writer (lane A) ──► MXL domain A ──► fabrics      fabrics  ──► MXL domain B ──► bench: remote reader
        local reader (lane B) ◄──┘           initiator ══► target                         (lane B)
                                         200 GbE RoCE, provider tcp or verbs
```

**Host A** runs a transit scenario in real time for up to 20 minutes:
- **Lane A** writes 1080p29.97 v210 grains (5 529 600 B). After filling each grain it stamps the grain's index
  and the current time (`mxlGetTime()`) into the first bytes, then commits it.
- **Lane B**, the local reader, blocks for each new grain (head+1), checks the stamp and logs the transit. It
  reads only the stamp, not the whole payload, as `10-transit-local-stamp` does today.
- **Lane C** is a once-per-second probe of the newest grain, used as a watchdog only. It is not reported: it
  measures where in the frame the probe lands, not latency.

**Host B** runs the reader half of the same scenario (today's `09-transit-remote-reader`): lanes B and C only,
against the same flow id in host B's domain. The fabrics initiator on host A watches the flow and sends each
committed grain to the target on host B, which writes and commits it into host B's domain.

| Metric | Meaning |
|---|---|
| `transit_ms` | The reader's wake-up time minus the writer's stamp. On host A both come from one clock. On host B the wake-up is on host B's clock and the stamp on host A's, so it includes the offset between the two clocks. |
| `age_ms` | The reader's wake-up time minus the media time the grain's index stands for. Same clock caveat on host B. |
| p99 − p50 | The spread of transit: how much later than usual the slowest 1 % of grains arrive. Insensitive to a constant clock offset. |
| lost grains | Indices between the first and last remote read that were never read. |

Each log file on each host appends several sessions. Sessions were split where the bench's event counter
restarts or the log pauses for more than two minutes, then each remote session was paired with the host A
writer session running at the same time. Every remote session was classified by provider; each test day ran TCP
first, then Verbs, and the user confirmed the order.

## Results

### Verbs vs TCP vs same-host

Headline figures, from the longest session of each kind:

| | Session | Reads | Transit p50 | p99 | max | p99 − p50 |
|---|---|---|---|---|---|---|
| Same host (host A local reader) | 2026-10-06 17:14 | 33 376 | 0.069 ms | 0.083 ms | 2.167 ms | 0.014 ms |
| **Verbs** | 2026-10-06 17:15 | 29 968 | **0.750 ms** | 0.784 ms | 2.854 ms | 0.034 ms |
| **Verbs** | 2026-09-23 19:59 | 28 177 | **0.642 ms** | 0.673 ms | 2.510 ms | 0.031 ms |
| **TCP** | 2026-09-23 16:00 | 13 271 | **3.612 ms** | 5.100 ms | 8.607 ms | 1.488 ms |

What it shows:
- **Verbs adds about 0.55-0.7 ms** over a same-host read, and its timing is almost as steady as a local read:
  99 % of grains arrive within 0.06 ms of the usual time.
- **TCP adds about 3.5 ms, five times as much,** and is much less steady: the slowest 1 % arrive 1.5-1.7 ms later
  than usual, and single grains up to 9.7 ms.
- Both fit easily in the 33.4 ms frame period, and neither lost a grain.

### Reliability

- **Lost grains: 0** in every session. The remote reader read every index from its first to its last read.
- **Read rate:** exactly 29.970 grains per second in every remote session, so neither provider fell behind.
- **Failed reads during the flow: 0.** All failed reads in the logs (3 095 in total) happened after the last good
  read of their session, when the writer or the fabrics target was being stopped: `MXL_ERR_OUT_OF_RANGE_TOO_EARLY`
  (the reader asking for grains that never came) and `MXL_ERR_FLOW_INVALID` (the flow being torn down).

### Clock offset

On host B, `transit_ms` = true transit + (host B clock − host A clock). With NTP only, the offset at run time is
unknown. What the data still bounds:

- **Physical floor.** A grain cannot be read on host B before all of it has crossed the link, and the stamp is
  written after the grain is filled, so true transit is at least the wire time: 5 529 600 B x 8 / 200 Gb/s =
  **0.221 ms**.
- **Upper bound on host B being ahead.** The smallest observed Verbs transit per session is 0.30-0.51 ms, so
  host B's clock was at most 0.08-0.29 ms ahead of host A's, depending on the session. A lower bound cannot be
  derived: host B's clock may have been behind, making true transit larger than observed.
- **Today.** In November 2026 `chrony` puts both hosts within 0.03 ms of the same NTP server. If that held during
  the runs, the absolute figures are good to about 0.05 ms.
- **Day-to-day.** Verbs p50 was 0.63-0.69 ms on 2026-09-23 and 2026-10-02, and 0.75-0.78 ms on 2026-10-05 and
  2026-10-06. Nothing was knowingly changed. A clock offset that moved by about 0.1 ms between days explains it,
  but a real change cannot be ruled out without PTP.

Not affected by the offset: the TCP-vs-Verbs difference within a day (2.8-3.1 ms on every day), the spreads,
the read rate and the loss counts.

### Bandwidth

One 1080p29.97 v210 flow is 5 529 600 B x 8 x 29.97 = **1.33 Gb/s**, under 1 % of the 200 Gb/s link.

### Figures in the WABE 2026 slides

The [slides](slides/wabe-2026-from-memory-to-fabric.html) of the talk given on 2026-10-06 show the 2026-10-05
sessions, the last test day before it:

| Slide figure | Session in the [raw-data tables](#raw-data-tables) | Value in the tables |
|---|---|---|
| Local, same host: median 0.07 ms, p99 0.09 ms | Host A local reader, writer session 2026-10-05 16:34 | p50 0.069, p99 0.086 ms |
| Across hosts, TCP: median 3.7 ms, p99 5.3 ms | 2026-10-05 16:24, TCP | p50 3.674, p99 5.299 ms |
| Across hosts, Verbs: median 0.78 ms, p99 0.82 ms | 2026-10-05 16:35, Verbs | p50 0.778, p99 0.819 ms |
| Verbs "reduces transit latency by 4.7×" | The two sessions above | 3.674 / 0.778 = 4.72 |

Where the slides and this page differ:

- **Clocks.** The slides say both hosts were synchronised by NTP "to a Meinberg grandmaster within tens of
  microseconds". The offset during the runs was not recorded; the 0.03 ms figure is the November reading (see
  [Clock offset](#clock-offset)). This page's bound applies.
- **Testbed.** The slides name the server model (Dell R760xs) and memory (256 GB), which [Setup](#setup) does
  not record.
- **Tool.** The slides point to the bench under its former name and location (ABI-tester, in
  `cbcrc/mxl-hands-on` under `test-tools`). It is now [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench).

The slides are published unchanged, as presented, under CC BY-ND 4.0 ([`LICENSES/LICENSE.md`](../../../LICENSES/LICENSE.md)).

## Raw-data tables

### Remote reader (host B), per session

Times are UTC, approximate to the minute. Transit in ms. "Duration" is from the first to the last good read.
"Teardown fails" are the failed reads after the last good read (see [Reliability](#reliability)). The local
columns are host A's own reader during the same writer session.

| Start | Provider | Duration (s) | Reads | Lost | Teardown fails | min | p10 | p50 | p90 | p99 | max | p99 − p50 | age p50 | Host A local p50 | Host A local p99 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-23 16:00 | TCP | 443 | 13 271 | 0 | 129 | 2.766 | 3.364 | 3.612 | 4.604 | 5.100 | 8.607 | 1.488 | 4.340 | 0.075 | 0.095 |
| 2026-09-23 19:59 | Verbs | 940 | 28 177 | 0 | 2 612 | 0.442 | 0.628 | 0.642 | 0.658 | 0.673 | 2.510 | 0.031 | 1.366 | 0.073 | 0.092 |
| 2026-10-02 19:06 | TCP | 161 | 4 832 | 0 | 242 | 2.491 | 2.789 | 3.542 | 4.703 | 5.283 | 5.590 | 1.741 | 4.285 | 0.077 | 0.096 |
| 2026-10-02 19:40 | Verbs | 218 | 6 548 | 0 | 0 | 0.462 | 0.617 | 0.629 | 0.639 | 0.653 | 1.161 | 0.024 | 1.352 | 0.073 | 0.094 |
| 2026-10-02 19:44 | Verbs | 240 | 7 200 | 0 | 33 | 0.429 | 0.615 | 0.688 | 0.736 | 0.746 | 0.958 | 0.058 | 1.383 | 0.073 | 0.094 |
| 2026-10-02 19:52 | TCP | 7 | 205 | 0 | 0 | 3.223 | 3.545 | 3.778 | 4.096 | 4.776 | 4.896 | 0.998 | 4.585 | 0.070 | 0.088 |
| 2026-10-05 16:24 | TCP | 374 | 11 222 | 0 | 32 | 2.490 | 3.411 | 3.674 | 4.859 | 5.299 | 9.735 | 1.625 | 4.406 | 0.071 | 0.097 |
| 2026-10-05 16:35 | Verbs | 368 | 11 024 | 0 | 0 | 0.513 | 0.762 | 0.778 | 0.799 | 0.819 | 1.326 | 0.040 | 1.499 | 0.069 | 0.086 |
| 2026-10-06 14:03 | TCP | 77 | 2 310 | 0 | 2 | 2.773 | 3.588 | 3.863 | 4.981 | 5.482 | 5.940 | 1.619 | 4.611 | 0.071 | 0.092 |
| 2026-10-06 17:10 | TCP | 136 | 4 085 | 0 | 5 | 2.571 | 3.278 | 3.523 | 4.760 | 5.224 | 9.449 | 1.702 | 4.331 | 0.070 | 0.092 |
| 2026-10-06 17:15 | Verbs | 1 000 | 29 968 | 0 | 40 | 0.300 | 0.736 | 0.750 | 0.766 | 0.784 | 2.854 | 0.034 | 1.471 | 0.069 | 0.083 |

The two Oct 2 Verbs sessions read from the same writer session on host A. The 7-second TCP session on Oct 2 is
a short test; it is listed for completeness and not used in the headline figures.

### Writer host (host A), local reader, per writer session

| Start | Writes | Local reads | Failed | min | p10 | p50 | p90 | p99 | max | age p50 |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-23 14:45 | 5 322 | 5 234 | 1 | 0.035 | 0.074 | 0.080 | 0.094 | 0.108 | 0.535 | 0.882 |
| 2026-09-23 15:47 | 36 000 | 35 913 | 87 | 0.030 | 0.071 | 0.075 | 0.084 | 0.095 | 0.758 | 0.811 |
| 2026-09-23 19:54 | 36 000 | 35 912 | 88 | 0.035 | 0.070 | 0.073 | 0.080 | 0.092 | 1.790 | 0.801 |
| 2026-10-02 18:36 | 36 000 | 35 912 | 13 | 0.030 | 0.072 | 0.077 | 0.092 | 0.137 | 2.754 | 0.876 |
| 2026-10-02 18:57 | 36 000 | 35 912 | 18 | 0.036 | 0.070 | 0.077 | 0.085 | 0.096 | 0.712 | 0.876 |
| 2026-10-02 19:17 | 36 000 | 35 912 | 20 | 0.028 | 0.067 | 0.072 | 0.080 | 0.091 | 1.461 | 0.871 |
| 2026-10-02 19:38 | 20 329 | 20 241 | 1 | 0.031 | 0.037 | 0.073 | 0.082 | 0.094 | 0.612 | 0.801 |
| 2026-10-02 19:50 | 4 566 | 4 478 | 1 | 0.038 | 0.063 | 0.070 | 0.079 | 0.088 | 0.218 | 0.867 |
| 2026-10-05 16:21 | 18 847 | 18 759 | 1 | 0.030 | 0.068 | 0.071 | 0.081 | 0.097 | 2.706 | 0.802 |
| 2026-10-05 16:34 | 12 964 | 12 876 | 1 | 0.032 | 0.062 | 0.069 | 0.074 | 0.086 | 0.633 | 0.792 |
| 2026-10-06 14:00 | 7 433 | 7 345 | 1 | 0.031 | 0.065 | 0.071 | 0.079 | 0.092 | 0.419 | 0.854 |
| 2026-10-06 17:08 | 8 494 | 8 406 | 1 | 0.030 | 0.066 | 0.070 | 0.078 | 0.092 | 0.794 | 0.868 |
| 2026-10-06 17:14 | 33 463 | 33 376 | 0 | 0.029 | 0.067 | 0.069 | 0.073 | 0.083 | 2.167 | 0.792 |

"Failed" counts every failed call of the session, including those at start-up and teardown. Three writer sessions
(2026-09-23 14:45, 2026-10-02 18:36 and 19:17) have no matching session in host B's logs.

### Receiver host (host B), local reference

One short local session on host B (a writer and a reader on host B, no fabrics), 2026-09-23 21:52: 1 863 reads,
transit min 0.027, p10 0.032, p50 0.070, p90 0.077, p99 0.086, max 0.584 ms. Host B on its own behaves like
host A.

## Caveats

- **Clocks: NTP only** (see [Clock offset](#clock-offset)). Absolute cross-host figures are bounded, not exact.
- **Governor, pinning and other workloads were not recorded** (see [Setup](#setup)). Under the default governor,
  the cross-NUMA study saw wake-up times vary by up to 2x; the local p50 of 0.07 ms here is in line with its
  `performance` figures, but tails may be wider than they would be on a tuned host.
- **One flow, 1080p, stamp-only reads.** The remote reader did not read the payload, so the figures say when the
  grain becomes available on host B, not how long a consumer takes to read it.
- **The NIC is on NUMA node 1** on both hosts; where the containers and the MXL domain memory sat relative to it
  was not recorded.
- **RoCE MTU was 1024 B**, not the 4096 B often used for RDMA. Not tuned.
- **The fabrics tool is a demo**, not a production transport.

## Open questions

- **PTP.** Re-run with both hosts on PTP to turn the bound into an absolute figure, and to tell whether the
  0.63 vs 0.78 ms day-to-day difference is real.
- **2160p** (22 MB grains): does Verbs transit scale with grain size (wire time 0.88 ms at 200 Gb/s)?
- **Several flows** at once, and **touching the payload** on host B.
- **Tuning:** RoCE MTU 4096, the `performance` governor, and containers pinned to the NIC's NUMA node.
- **Where the 0.6 ms goes:** wire time is 0.22 ms; the rest is the initiator noticing the commit, the transfer
  set-up, and the target's commit on host B. Not broken down.
