<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# DMF data

Measured results from building a **Dynamic Media Facility** (DMF). The DMF is a reference architecture from the
EBU in which a broadcast facility is built from small pieces of software, called **media functions** (a converter,
a mixer, a multiviewer), each running in its own container on ordinary servers.

The media functions hand live video and audio to each other through [MXL](https://github.com/dmf-mxl/mxl), the
Media eXchange Layer. MXL puts each piece of media, a **grain** (one video frame, or a block of audio samples), in
memory that every program on the server can read. One program, the **writer**, puts a stream of grains (a
**flow**) there, and any number of **readers** take them. No network is involved inside one server.

Before we decide how to deploy media functions (on which server, which CPU, over which network transport, with
which Kubernetes settings), we measure. This repository publishes what we measured: one study per question, with
the numbers behind it and the steps to run it again. It is written for anyone who designs, deploys or operates
such a facility.

## How to read a study

Each study is a folder with three pages:

- **`README.md`, the executive summary.** The question, what fooled us on the way, the answer, and rules of
  thumb. A page and a half.
- **`results.md`, the detailed results.** The setup and hardware, the method, every number in per-run tables,
  and the caveats.
- **`how-to-reproduce.md`, the steps.** Numbered steps, with every command, to run the measurement again on your
  own hardware with public tools, and the figures to compare with.

A study that was presented in a talk also has a `slides/` folder with the deck, as it was shown.

The raw measurement logs are too large to publish; `results.md` holds the per-run statistics computed from them.
The results come from our lab hardware, described in each `results.md`; check how close yours is before reusing a
number.

## Studies

For comparison: at 29.97 frames per second, one frame lasts 33.4 ms.

### Infra

The servers themselves. A server with two CPU chips (**sockets**) is close to two computers sharing a box: each
socket has its own memory, and reaching the other socket's memory takes longer. Linux calls each socket and its
memory a **NUMA node**. Also caches, memory bandwidth, and CPU power-saving settings.
[All infra studies](studies/infra/)

- [**The cross-NUMA cost of MXL**](studies/infra/2026-10-cross-numa-grain-transit/) (October 2026). When a 4K flow
  is written on one socket and read on the other, each frame costs about 1 ms more, about 3 % of the frame
  period, shared between the reader and, surprisingly, the writer. A CPU power-saving setting (the **governor**)
  caused bigger delays than crossing sockets did: set it to `performance` first.

### Network and transport

Moving media between servers: **RDMA** (remote direct memory access, where the network card writes data straight
into the other server's memory), **MXL fabrics** (the part of MXL that carries a flow from one server to
another), network cards, ST 2110, and PTP time synchronisation.
[All network and transport studies](studies/network-transport/)

- [**Moving MXL video between servers over RDMA**](studies/network-transport/2026-10-rdma-grain-transit/)
  (September-October 2026). A 1080p frame carried by MXL fabrics is readable on another server about 0.7 ms after
  it is written with RDMA, and 3.6 ms with ordinary TCP. RDMA's slowest frames arrive within 0.06 ms of its usual
  time, TCP's up to 1.7 ms later. Not one frame was lost with either.

### Kubernetes cluster

Running media functions on a Kubernetes cluster: how it places them on CPUs, how well one is protected from busy
neighbours on the same server, and its quality-of-service classes.
[All Kubernetes cluster studies](studies/kubernetes-cluster/)

- No studies yet.

### MXL

The behaviour and cost of the MXL library itself, whatever server it runs on. [All MXL studies](studies/mxl/)

- No studies yet.

A **media functions** section, for the cost of specific functions, will be added with its first study.

## Contributing

Start from [`docs/study-template/`](docs/study-template/) and read [`docs/writing-guide.md`](docs/writing-guide.md).
The rules for contributors, and for the AI coding assistants some of us use, are in [`AGENTS.md`](AGENTS.md).
Because this repository is public, it holds no IP addresses, hostnames or raw logs.
`.github/scripts/docs-checks.sh` checks that, and CI runs it on every pull request.

## Licence

Documentation and results: [CC BY 4.0](LICENSES/CC-BY-4.0.txt). Scripts and configuration:
[Apache 2.0](LICENSES/Apache-2.0.txt). See [`LICENSES/LICENSE.md`](LICENSES/LICENSE.md).
