<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Infra

Studies of the compute hosts themselves: CPU sockets and NUMA, caches, memory bandwidth, and power and frequency
settings. The question is usually "where on this server should a media function run, and how should the server
be set up?"

- [The cross-NUMA cost of MXL](2026-10-cross-numa-grain-transit/) (October 2026): reading a 4K frame written on
  the other CPU socket costs about 1 ms, well within a frame; the CPU governor matters more.
