<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Leaving the host: moving MXL video between servers over RDMA

**Measured:** September and October 2026 · **Hardware:** two servers with Intel Xeon Silver 4510 CPUs and
200 Gb/s NVIDIA ConnectX-7 network cards · **Details:** [`results.md`](results.md) ·
**Reproduce:** [`how-to-reproduce.md`](how-to-reproduce.md) · **Presented:** WABE 2026
([slides](slides/wabe-2026-from-memory-to-fabric.pdf))

## The question

In a Dynamic Media Facility (DMF), the EBU's architecture for a software broadcast facility, small programs
called media functions hand video to each other through **MXL** (the Media eXchange Layer). Inside one server,
MXL keeps each video frame (a **grain**) in memory that every program on the server can read. One program, the
**writer**, puts a stream of grains (a **flow**) there; other programs, the **readers**, take them. A reader on
the same server can read a grain about 0.07 ms after it is written.

A facility needs more than one server, though. **MXL fabrics** is the part of MXL that carries a flow from one
server's memory into another's, so that a reader on the second server sees it as if it were local. It can use
two kinds of transport, which it calls **providers**:

- **TCP**, the ordinary network protocol: the operating system on each side copies the data through its network
  software.
- **Verbs**, which uses **RDMA** (remote direct memory access): the network card writes the grain straight into
  the other server's memory, without either operating system copying it. Our cards do this over ordinary
  Ethernet, a variant called **RoCE** (RDMA over Converged Ethernet).

We asked: **how long after a grain is written on one server can a program on another server read it, with each
provider? And is it steady and reliable enough for live video?**

## How we measured it

We used [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench), a test tool that writes a live, uncompressed
1080p flow at 29.97 frames per second through MXL. Each grain is 5.5 MB and lasts 33.4 ms. The writer stamps the
time into each grain as it writes it, and each reader notes the time it receives the grain. Our readers read only
that stamp, not the picture, so the figures say when a grain becomes available, not how long a program takes to
process it.

On the first server (host A), a local reader timed each grain as a reference. The demonstration program that
ships with MXL fabrics carried the flow over a 200 Gb/s link to the second server (host B), where a second reader
timed its arrival. On four days we ran TCP first, then Verbs: 11 sessions in all (6 TCP, 5 Verbs) of a few
seconds to 20 minutes each, about 119 000 grains read on host B, or about 66 minutes of video.

We report two figures per session. **p50** is the typical grain: half arrive sooner, half later. **p99** is the
slowest 1 %: 99 % of grains arrive sooner. The difference between them, the **spread**, says how steady the
transport is.

## What could fool us: two clocks

Within one server, writer and reader share a clock, so "read time minus write time" is exact. Across two servers,
the write time comes from host A's clock and the read time from host B's. Any difference between the two clocks
(the **offset**) shows up as transit time. Our servers were synchronised with **NTP**, the ordinary network time
service, which keeps clocks close but not to the microsecond. **PTP**, the precise time protocol used for
broadcast timing, was not set up.

So we checked what the clocks could and could not distort:

- **The difference between TCP and Verbs is real.** Both ran on the same day, minutes apart, against the same
  clocks.
- **Steadiness is real.** A steady clock offset moves the p50 and the p99 by the same amount, so the spread
  between them does not change.
- **The absolute Verbs number is probably right, but not proven.** No grain can arrive faster than the wire
  allows: 0.22 ms for 5.5 MB at 200 Gb/s. Our fastest grains took 0.30 to 0.51 ms, so the clocks cannot have
  been far off in the direction that would make transit look longer than it is. The other direction, which would
  make it look shorter, the data cannot rule out. In November, both servers' clocks were within 0.03 ms of the
  NTP server they share. If they were that close during the runs too, the Verbs figures are right to about
  0.05 ms.

## The answer

| | Typical transit (p50) | Slowest 1 % (p99) | Spread (p99 − p50) |
|---|---|---|---|
| Same server (reference) | 0.07 ms | 0.08-0.14 ms | 0.01-0.06 ms |
| **Verbs (RDMA)** | **0.63-0.78 ms** | 0.65-0.82 ms | 0.02-0.06 ms |
| **TCP** | **3.5-3.9 ms** | 5.1-5.5 ms | 1.5-1.7 ms |

The ranges are over the test sessions.

1. **Verbs is fast and steady.** A grain written on host A is readable on host B about **0.7 ms** later, around
   2 % of a frame. It is almost as steady as a local read: 99 % of grains arrive within 0.06 ms of the usual time.
2. **TCP is five times slower and much less steady.** About **3.6 ms** typical; the slowest 1 % arrive 1.5 ms
   later still, and the single slowest grain took 9.7 ms. That still fits in a 33.4 ms frame, but every hop
   between servers adds to a facility's total delay, and TCP's hops are both longer and less predictable.
3. **Both were reliable.** Not one grain was lost: the reader on host B received every grain, at exactly
   29.97 per second, on both providers. No reader got an error while the flow was running; the only errors came
   when the flow was being shut down at the end of a session.
4. **The link was nearly idle.** One 1080p flow uses 1.3 Gb/s, under 1 % of the 200 Gb/s link. How many flows fit,
   and at 4K, is still to be measured.

## Rules of thumb

1. **Use the Verbs (RDMA) provider between servers.** It is five times faster than TCP and far steadier, for the
   same reliability. It needs RDMA-capable network cards on both servers.
2. **Keep TCP as a fallback** for servers without them. Budget about 4 ms typical and up to 10 ms worst case for
   a 1080p grain.
3. **Budget about 1 ms for a 1080p grain to cross between servers over RDMA**, against 0.07 ms within a server.
   That covers the slowest 1 % (0.82 ms at most) with some margin, as long as the clocks were about as close
   during the runs as they were in November; a run with PTP would confirm it.
4. **Measure cross-server timing only between servers on PTP.** With NTP alone, the clocks can disagree by
   tenths of a millisecond, the same size as what you are trying to measure.

## Still open

- **A run with PTP**, to turn the Verbs bound into an exact figure. It would also tell whether the small
  difference between days (0.63 ms on two days, 0.75-0.78 ms on the other two) is real or clock drift.
- **4K (2160p) grains, several flows at once**, and readers that read the whole picture.
- **Tuning that was not tried:** the CPU `performance` governor (see the
  [cross-NUMA study](../../infra/2026-10-cross-numa-grain-transit/)); running the programs on the CPU socket the
  network card is attached to, which saves data a trip between sockets; and a larger RDMA packet size (the MTU,
  1024 bytes here).
- **Where the 0.7 ms goes.** Only about 0.22 ms of it is the wire. The rest is the sender noticing the new grain,
  setting up the transfer, and the receiver making it available to readers on host B; we did not time each step.
- **The network between the two servers**, and whether its switches were configured for RoCE, was not recorded.
  RoCE usually needs switch settings that prevent packet loss; a facility network must be checked for them.

## Presented at WABE 2026

We showed this measurement at WABE 2026 in Vancouver, on 6 October 2026, in the talk *From memory to fabric:
MXL at WABE 2026*. The slides come in two forms:

- [**PDF**](slides/wabe-2026-from-memory-to-fabric.pdf), which GitHub displays directly.
- [**HTML**](slides/wabe-2026-from-memory-to-fabric.html), the deck as presented, where you can click the
  architecture diagram to zoom into each part. GitHub shows it as source code: download it and open it in a
  browser. It needs no network connection.

The slides give the figures of one test day, 5 October: a typical 0.07 ms on the same server, 0.78 ms over Verbs
and 3.7 ms over TCP. They fall within the ranges above. One statement on the slides goes further than this study
can: that the two servers' clocks were within tens of microseconds of each other. That was true when we checked
in November, but nobody measured it during the runs (see "What could fool us" above). Where the slides and this
page differ, this page is right. The slides are published as they were presented.

The per-session tables, the setup and the clock analysis are in [`results.md`](results.md). The steps to run it
again between two servers of your own are in [`how-to-reproduce.md`](how-to-reproduce.md).
