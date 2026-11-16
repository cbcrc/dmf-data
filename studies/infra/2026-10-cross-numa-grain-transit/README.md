<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# The journey across the socket: the cross-NUMA cost of MXL

**Measured:** October 2026 · **Hardware:** two identical servers, each with two Intel Xeon Silver 4510
(Sapphire Rapids) CPUs · **Details:** [`results.md`](results.md)

## The question

In a Dynamic Media Facility (DMF), the EBU's architecture for a software broadcast facility, small programs
called media functions hand video to each other through **MXL** (the Media eXchange Layer). MXL keeps each
video frame (a **grain**) in memory that every program on the server can read. One program, the **writer**,
puts a stream of frames (a **flow**) there; other programs, the **readers**, take them. No network is involved.

Modern servers are essentially two computers glued together. Each of our lab servers has two CPU chips, called
**sockets** 0 and 1. Each socket has its own cores and its own main memory.

Each socket also has a **cache**: a small, very fast memory on the chip that keeps recently used data, here
30 MB per socket. Reading from the cache is much faster than from main memory.

The two sockets talk to each other over a bridge called **UPI**. A program on socket 1 can read memory attached
to socket 0, but the data has to cross that bridge. Linux calls each socket and its memory a **NUMA node**.

So we asked: **what does it cost when a video flow is written into socket 0's memory, but read by a program
running on socket 1?** We expected that cost to fit well inside the 33.4 ms a frame lasts at 29.97 fps. What we
needed was a measured number, so that whoever places media functions on CPUs (a person, or Kubernetes) knows
what crossing the bridge costs.

We measured with [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench), a test tool that writes and reads live
video flows through MXL and times every step. Below, a **local** reader runs on the writer's socket and a
**remote** reader on the other one. The hardware did not give up its secrets easily.

## What fooled us

### Plot twist 1: the governor's deception

Our very first test said that reading a frame from the other socket was *faster* than from the same socket.

That was an illusion caused by the CPU's power-saving setting, the **governor**. The default one slows down cores
that have been idle. Our readers wait 33 ms between frames, so their cores kept slowing down, and each reader
ended up running either fast or about half as fast, at random. In the first run, the remote reader happened to
land in the fast state.

**The fix:** we set the governor to `performance`, which keeps every core at full speed. The two-speed pattern
vanished, and the time for a reader to wake up after a new frame dropped by half, to about 0.03-0.06 ms.

### Plot twist 2: escaping the cache

With the cores at full speed, we tested 1080p video. The results were too good to be true. MXL keeps the last
five frames of a flow in a ring that keeps overwriting its oldest frame. At 1080p, the whole ring (about 28 MB)
fits in a socket's 30 MB cache. We were measuring the cache, not the trip to memory.

So we moved to 4K (2160p), where a single frame is 22 MB. The CPU caught us again: a frame read right after it is
written is still partly in the writer's cache, and a read served from there, even across the bridge, is not the
trip to main memory we wanted to measure.

**The fix:** we made the reader read the frame three behind the newest one. By then, three newer 4K frames
(66 MB) have been written over the cache, more than twice its size, so the frame has to come from main memory.

### Plot twist 3: the readers fed each other

Even then, crossing the socket looked almost free: a remote reader took only 4 % longer to copy a frame than a
local one.

We were fooled a third time. Several readers of the same flow were running at once. The CPU's built-in event
counters showed that once the first reader on socket 1 had fetched a frame across the bridge, the other readers
on socket 1 copied it from that reader's cache instead of making the trip themselves.

**The fix:** we ran a single reader on socket 1, alone, so that every read was a true trip to the other socket's
memory.

## The answer

With the illusions gone, a single reader on socket 1 reading a 4K frame from socket 0's memory costs two things:

1. **The reader pays a toll.** Copying the frame takes about **0.44 ms longer**: 1.90 ms instead of 1.47 ms
   (+30 %). A reader that takes the newest frame, as most real readers do, pays about the same: 0.41 ms more.
2. **The writer slows down too.** Surprisingly, filling each new frame also takes about **0.5 ms longer**:
   1.99 ms instead of 1.48 ms (+34 %). The CPUs keep a directory of which socket may hold a copy of each piece of
   memory. A remote read leaves a mark there. Before the writer can overwrite that memory with a later frame, it
   must ask socket 1 to drop its copy, and wait for the answer, even though there is nothing to drop.

Together (0.44 + 0.5 ms), crossing the socket costs about **1 ms per 4K frame**, about 3 % of the 33.4 ms frame period. Waking up
the reader when a frame arrives costs nothing extra across the bridge.

### Stressing the bridge

We then pushed harder: up to 6 remote readers on one flow, 4 simultaneous 4K flows, and an extra load generator
pushing about 95 GB/s through the memory.

- **The remote cost is per flow, not per remote reader.** More remote readers of the same flow do not slow the
  writer further: the frame crosses the bridge once.
- **Under load, remote reads slowed down about as much as local ones did**, so the gap between them stayed about
  the same.
- **The slowest 1 % of frames stayed under 5 ms** to read or write in every configuration, against about 1.5 to
  2 ms without load, and far below the 33.4 ms frame period.

## Rules of thumb

These hold for this hardware: two-socket Intel Sapphire Rapids servers, video up to 4K at about 30 frames per
second.

1. **Tame the governor.** Set the CPU governor to `performance` on MXL servers (for example
   `cpupower frequency-set -g performance`). Under the default, read times varied by a factor of two, which hides
   or fakes any socket effect.
2. **Prefer local when it costs nothing.** If a flow's writer and its readers can run on the same socket, put
   them there. It saves about 1 ms per 4K frame.
3. **Group remote readers.** If a flow must cross to the other socket, put all of its remote readers on the same
   socket. The flow pays the crossing once, however many readers there are.
4. **But do not fear the bridge.** When balancing the load means crossing sockets, cross. The cost is known and
   small against the frame period.

Placing a program on a socket means restricting it to that socket's cores and memory: with Docker's `cpuset`
options, or with the Kubernetes CPU and topology managers.

## Still open

- **Local readers slow the writer a little too.** With two or more readers on the writer's own socket, filling a
  frame takes about 0.2 ms longer. We have a guess, not a proof. It does not change the rules above.
- **Under heavy memory load, a remote reader still costs the writer about 0.35 ms**, and we could not find where
  all of it goes.
- **On the first server, a writer on socket 1 was slower for every reader.** This was seen once and not followed
  up, so there is no rule yet about which socket the writer should use.
- **How much spare capacity the bridge has** was estimated, not measured. It is the main unknown for packing many
  more flows on one server.
- **Higher frame rates** (50 or 59.94 fps) and **8K** were not measured. At 59.94 fps a frame lasts 16.7 ms, so
  the same 1 ms would be 6 % of it.

The full report, with every table, the counters, and how to reproduce it, is in [`results.md`](results.md).
