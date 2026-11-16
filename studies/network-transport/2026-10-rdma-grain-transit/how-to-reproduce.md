<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# How to reproduce: moving MXL video between servers over RDMA

This page re-runs one session of the study: a live 1080p29.97 flow written on host A, carried to host B by the MXL
fabrics demo, and read on both hosts, once with the **Verbs** (RDMA) provider and once with **TCP**. It gives the
figures in the [raw-data tables](results.md#raw-data-tables) of `results.md`.

A full session is 20 minutes of video per provider; you can stop earlier, as the study's shorter sessions did.

## What you need

- **Two Linux servers** with Docker and Docker Compose, each with an RDMA-capable network card, connected by a
  network that carries RDMA (for RoCE, Ethernet switches configured for it). Ours: Intel Xeon Silver 4510,
  NVIDIA ConnectX-7 at 200 Gb/s, Ubuntu 24.04, kernel 6.8, `rdma-core`.
- `jq`, `curl` and `python3` on both.
- **Clock synchronisation** between the two servers. The study used NTP only, which limits the absolute
  cross-server figure (see [Clock offset](results.md#clock-offset)). **Use PTP if you can.**
- [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench) on both servers.
- **The MXL fabrics demo** (`mxl-fabrics-demo`) and its Docker Compose example, on both servers. The study used MXL
  branch `fabrics-demo-v1.1.0` at commit `c36ac00`, a fork of [dmf-mxl/mxl](https://github.com/dmf-mxl/mxl).

Below, `HOST_A_IP` and `HOST_B_IP` are each server's address **on the RDMA network**, not its management address.

## 1. Check the RDMA link (both servers)

```sh
ibv_devinfo | grep -E 'hca_id|state|active_mtu|link_layer'   # the port you use: PORT_ACTIVE
ethtool <interface> | grep Speed                              # e.g. 200000Mb/s
```

Note the RoCE MTU (`active_mtu`); the study ran at 1024 bytes.

## 2. Record the host state (both servers)

The study did not record these at run time, and it is the first thing a reader of your results will ask:

```sh
chronyc tracking            # or, with PTP: pmc -u -b 0 'GET TIME_STATUS_NP'
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
docker ps                   # anything else running?
```

## 3. Create the MXL domain and start the bench (both servers)

```sh
mkdir -p /dev/shm/domain_1
git clone https://github.com/cbcrc/mxl-api-bench.git && cd mxl-api-bench
mkdir -p logs && rm -f logs/events*.ndjson     # one fresh log per session
MXL_DOMAIN_DEVICE=/dev/shm/domain_1 docker compose -f docker-compose.published.yml up -d
until curl -sf localhost:9607/health; do sleep 0.2; done
```

The bench answers on port 9607 and logs every call to `logs/events.ndjson`.

## 4. Host A: start the writer and its local reader

The study read only each grain's timestamp, not the picture, so it used the stamp-only scenario:

```sh
curl -sS -X POST localhost:9607/scenario -H 'Content-Type: application/json' \
  -d @scenarios/10-transit-local-stamp.json
curl -sS -X POST localhost:9607/run -d ''
```

Lane A now writes 1080p29.97 v210 grains for 20 minutes into host A's domain, and lane B reads each one locally:
that is the same-server reference.

## 5. Host B: prepare the flow description

The fabrics target must create the same flow on host B: same id, same format. Take it from the scenario, in the
MXL repository's `examples/` directory:

```sh
jq -r '.lanes.A[] | select(.id=="a1").args.flow_def' \
  <path to mxl-api-bench>/scenarios/10-transit-local-stamp.json > flow-configs/flow-video-v210.json
jq -r .id flow-configs/flow-video-v210.json      # a1b2c3d4-0008-4000-8000-000000000008
```

## 6. Write the Compose file for the fabrics demo (both servers)

Save this as `examples/docker-compose-fabrics-rdma.yaml` in the MXL repository, on both servers. Set `PROVIDER` to
`verbs` for the RDMA run and `tcp` for the TCP run.

```yaml
name: mxl-example-fabrics

x-rdma-settings: &rdma-settings
  network_mode: "host"
  cap_add: [IPC_LOCK]
  ulimits:
    memlock: -1
  devices:
    - /dev/infiniband:/dev/infiniband
  shm_size: '2gb'

services:
  # Host B: the receiver
  fabrics-target-video:
    <<: *rdma-settings
    build: { dockerfile: examples/Dockerfile, context: .., target: mxl }
    volumes:
      - { type: bind, source: /dev/shm/domain_1, target: /mxl-domain }
      - { type: bind, source: flow-configs, target: /home/mxl/flow-configs }
    entrypoint: ["/usr/bin/mxl-fabrics-demo"]
    command: >
      -d /mxl-domain
      -f flow-configs/flow-video-v210.json
      --node ${HOST_B_IP}
      --service 5000
      --provider ${PROVIDER}
      -t @/home/mxl/flow-configs/target.json

  # Host A: the sender
  fabrics-initiator-video:
    <<: *rdma-settings
    build: { dockerfile: examples/Dockerfile, context: .., target: mxl }
    volumes:
      - { type: bind, source: /dev/shm/domain_1, target: /mxl-domain }
    entrypoint: ["/usr/bin/mxl-fabrics-demo"]
    command: >
      -i
      -d /mxl-domain
      -f a1b2c3d4-0008-4000-8000-000000000008
      --node ${HOST_A_IP}
      --service 5000
      --provider ${PROVIDER}
      --target-info "${TARGET_INFO:-}"
```

## 7. Start the transport: the target first, then the initiator

From the MXL repository's `examples/` directory on each server:

```sh
# Host B
PROVIDER=verbs HOST_B_IP=<host B RDMA address> \
  docker compose -f docker-compose-fabrics-rdma.yaml up -d fabrics-target-video
cat flow-configs/target.json      # the target's connection info; it changes on every target start

# Host A, with the contents of host B's target.json
PROVIDER=verbs HOST_A_IP=<host A RDMA address> TARGET_INFO='<contents of target.json>' \
  docker compose -f docker-compose-fabrics-rdma.yaml up -d fabrics-initiator-video
```

## 8. Host B: start the remote reader

Check that the flow has appeared in host B's domain and is advancing, for example with `mxl-info` from the MXL
tools pointed at `/dev/shm/domain_1`. Then load the remote-reader scenario. Today it also reads the picture
(`touch_payload`); remove that to match the study's stamp-only reads:

```sh
jq 'del(.lanes.B[].args.touch_payload)' scenarios/09-transit-remote-reader.json > /tmp/remote.json
curl -sS -X POST localhost:9607/scenario -H 'Content-Type: application/json' -d @/tmp/remote.json
curl -sS -X POST localhost:9607/run -d ''
```

## 9. Wait, then collect the logs

Let the writer finish (20 minutes), or stop both benches earlier with `curl -X POST localhost:9607/reset`. Keep each host's
`logs/events.ndjson`; reads that fail after the writer or the transport stops are expected (see
[Reliability](results.md#reliability)).

## 10. Run it again with TCP

Stop the transport on both servers (`docker compose -f docker-compose-fabrics-rdma.yaml down`), clear the bench
logs, and repeat steps 4 to 9 with `PROVIDER=tcp`. The study always ran TCP and Verbs on the same day, minutes
apart, so that the clock offset was about the same for both.

## 11. Compute the figures

```sh
./mxl-transit-stats.py --lane B <host A events.ndjson> <host B events.ndjson>
```

- **Lane B on host A** is the same-server reference.
- **Lane B on host B** is the cross-server transit.

If a log holds more than one session (the bench appends to it across runs), split it first: a new session starts
where the event `seq` restarts at 1, or where the log pauses for more than two minutes.

## 12. Compare with the study

| | Transit p50 | p99 | p99 − p50 |
|---|---|---|---|
| Same server (host A, lane B) | 0.07 ms | 0.08-0.14 ms | 0.01-0.06 ms |
| Verbs (host B, lane B) | 0.63-0.78 ms | 0.65-0.82 ms | 0.02-0.06 ms |
| TCP (host B, lane B) | 3.5-3.9 ms | 5.1-5.5 ms | 1.5-1.7 ms |

With PTP on both servers, your Verbs figure is absolute; with NTP, compare the Verbs-to-TCP difference (2.8-3.1 ms
in the study) and the spreads, which do not depend on the clock offset.
