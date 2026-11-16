<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# How to reproduce: the cross-NUMA cost of MXL

This page re-runs the decisive measurement of the study: **one writer on socket 0 and one reader, alone, either on
socket 0 (local) or on socket 1 (cross), reading 4K grains three frames behind the newest one** (§6 of
[`results.md`](results.md)). It gives the headline figures: about +0.44 ms on the reader's copy and +0.5 ms on the
writer's fill. The other experiments in the report are variations of it, listed at the end.

Expect about 30 minutes, most of it waiting for runs.

## What you need

- **A two-socket Linux server** with Docker and Docker Compose. Ours: 2 x Intel Xeon Silver 4510, Ubuntu 24.04,
  kernel 6.8. Nothing else should run on it during the test.
- `jq`, `curl`, `python3`, and `cpupower` (package `linux-tools-common` on Ubuntu). `perf` only for the optional
  counters.
- Root access, for the governor and the counters.
- [mxl-api-bench](https://github.com/cbcrc/mxl-api-bench), with scenarios 12 to 17 (merged from
  [PR #2](https://github.com/cbcrc/mxl-api-bench/pull/2)).

**Tool version.** The study ran the image `ghcr.io/cbcrc/abi-tester:latest` = `hands-on-1cdb007`, the tool's
earlier name. Any later `ghcr.io/cbcrc/mxl-api-bench` image runs the same scenarios. The log variable was then
`ABI_TESTER_LOG_FILE`; it is now `MXL_API_BENCH_LOG_FILE`.

**Scenarios**, all in the tool's `scenarios/` directory:

| Scenario | Used in | What it does |
|---|---|---|
| `10-transit-local-stamp`, `08-transit-local-lines`, `11-transit-local-copy` | §1-3 | 1080p29.97 v210 writer (lane A) plus a reader at head+1 (lane B) that reads only the stamp, every line, or copies the grain |
| `13-transit-local-copy-lag3` | §4 | 11 with the reader at head-3 |
| `14-transit-local-lines-2160p`, `15-transit-local-copy-2160p` | §4-6 | 08 and 11 at 2160p (22 MB grains) |
| `16-transit-local-lines-2160p-lag3`, **`17-transit-local-copy-2160p-lag3`** | §4-10 | 2160p at head-3, so the grain is read from DRAM. **17 is the one that isolates the cross-NUMA cost**, and the one used below |

12 to 17 are generated from 08 and 11 by `scenarios/make-lag.sh` and `scenarios/make-2160p.sh`.

## 1. Check the topology

```sh
numactl --hardware
```

You need two nodes. On our servers node 0 is the even CPUs and node 1 the odd CPUs, and the hyperthread sibling of
CPU *n* is *n*+24. **If yours differ, change the three CPU lists in step 4** so that each container gets 6 whole
physical cores (both hyperthreads of each), the writer and the local reader on node 0, the cross reader on node 1,
and no two containers share a core.

## 2. Prepare the host

```sh
sudo cpupower frequency-set -g performance
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c   # every CPU: performance
mkdir -p /dev/shm/domain_1                                                  # the MXL domain (tmpfs)
```

Skipping the governor is the first trap of the study: under the default `schedutil`, read times vary by up to 2x
and can make the cross reader look faster.

## 3. Get the bench and add the three-container override

```sh
git clone https://github.com/cbcrc/mxl-api-bench.git && cd mxl-api-bench
mkdir -p logs/writer logs/reader logs/reader-local
```

Save this as `three-readers.yml` in the repository root. It takes every cpuset from the environment and adds a
third, reader-only container on the writer's node.

```yaml
services:
  abi-writer:
    cpuset: "${WRITER_CPUS}"
  abi-reader:
    cpuset: "${READER_CPUS}"
  abi-reader-local:
    platform: linux/amd64
    image: ghcr.io/cbcrc/mxl-api-bench:latest
    pull_policy: always
    container_name: abi-reader-local
    hostname: abi-reader-local
    cpuset: "${LOCAL_CPUS}"
    ports:
      - "9609:9600"
    volumes:
      - { type: bind, source: "${MXL_DOMAIN_DEVICE:-/dev/shm/domain_1}", target: /mxl-domain }
      - { type: bind, source: ./scenarios, target: /app/scenarios }
      - { type: bind, source: ./logs/reader-local, target: /app/logs }
    environment:
      - MXL_DOMAIN_ROOT=/mxl-domain
      - SCENARIO_DIR=/app/scenarios
      - MXL_API_BENCH_LOG_FILE=/app/logs/events.ndjson
```

## 4. Start the containers and pin their memory

```sh
export MXL_DOMAIN_DEVICE=/dev/shm/domain_1
export WRITER_CPUS=0,2,4,6,8,10,24,26,28,30,32,34      # node 0
export LOCAL_CPUS=12,14,16,18,20,22,36,38,40,42,44,46  # node 0
export READER_CPUS=1,3,5,7,9,11,25,27,29,31,33,35      # node 1

docker compose -f docker-compose.numa-writer-reader.yml -f three-readers.yml up -d --force-recreate
docker update --cpuset-mems 0 abi-writer
docker update --cpuset-mems 0 abi-reader-local
docker update --cpuset-mems 1 abi-reader
```

The three containers answer on these ports: writer 9607, cross reader (`abi-reader`) 9608, local reader
(`abi-reader-local`) 9609.

## 5. Check the placement

```sh
for c in abi-writer abi-reader-local abi-reader; do
  P=$(docker inspect -f '{{.State.Pid}}' $c)
  echo "$c $(grep -E 'Cpus_allowed_list|Mems_allowed_list' /proc/$P/status | tr -s '\t\n' '  ')"
done
```

Each container must show its own CPU list and `Mems_allowed_list` 0, 0 and 1 respectively.

## 6. Build the run bodies from scenario 17

Each run is 90 seconds. The writer container runs only lane A (writing), and the reader runs only lane B (reading
three grains behind the newest):

```sh
S=17-transit-local-copy-2160p-lag3
jq '(.lanes.A[] | select(.id=="a7").args.times) = 2699
  | (.lanes.B[] | select(.id=="b5").args.times) = 2549
  | (.lanes.C[] | select(.id=="c3").args.times) = 89' scenarios/$S.json > /tmp/short.json
jq 'del(.lanes.B, .lanes.C) | .name += "-writer-only"' /tmp/short.json > /tmp/writer.json
jq 'del(.lanes.A, .lanes.C) | .name += "-reader-only"' /tmp/short.json > /tmp/reader.json
```

These are, byte for byte apart from the log variable's name in the description, the bodies used in the study.

## 7. Run it twice: local, then cross

Do these steps once with `R=abi-reader-local RPORT=9609 RLOG=reader-local` (local), then once with
`R=abi-reader RPORT=9608 RLOG=reader` (cross). **Only one reader runs at a time;** that is the point of the test.

```sh
# a. Stop everything, empty the domain, clear the old logs
docker stop abi-writer abi-reader abi-reader-local
sudo rm -rf /dev/shm/domain_1/*
rm -f logs/writer/events*.ndjson logs/$RLOG/events*.ndjson

# b. Start the writer and the ONE reader of this run
docker start abi-writer $R
until curl -sf localhost:9607/health && curl -sf localhost:$RPORT/health; do sleep 0.2; done

# c. Load the bodies, then start the writer first
curl -sS -X POST localhost:9607/scenario   -H 'Content-Type: application/json' -d @/tmp/writer.json
curl -sS -X POST localhost:$RPORT/scenario -H 'Content-Type: application/json' -d @/tmp/reader.json
curl -sS -X POST localhost:9607/run -d ''
curl -sS -X POST localhost:$RPORT/run -d ''

# d. Wait until every lane has reached its last step (about 90 s).
#    /state.running stays true after the lanes finish, so compare each lane's "next" with its length.
done_() { curl -sf localhost:$1/state > /tmp/st.json && jq -e -n --slurpfile s $2 --slurpfile st /tmp/st.json \
  '[$s[0].lanes | to_entries[] | ($st[0].lanes[.key].next // 0) >= (.value | length)] | all' > /dev/null; }
until done_ 9607 /tmp/writer.json && done_ $RPORT /tmp/reader.json; do sleep 5; done
sleep 3   # let the log flush

# e. Keep the logs of this run
mkdir -p runs/$RLOG
cp logs/writer/events.ndjson runs/$RLOG/writer.ndjson
cp logs/$RLOG/events.ndjson  runs/$RLOG/reader.ndjson
docker exec $R sh -c 'grep mxl-domain /proc/1/numa_maps' > runs/$RLOG/numa_maps.txt
```

`numa_maps.txt` should show the grain pages on node 0 only (`N0=`).

To also reproduce the "newest frame" row of the results, repeat steps 6 and 7 with
`S=15-transit-local-copy-2160p`.

## 8. Compute the figures

**Reader copy time** (`touch_ms`), from the bench's analysis script:

```sh
./mxl-transit-stats.py --lane B runs/reader-local/reader.ndjson runs/reader/reader.ndjson
```

Half of the lane B calls are the waiters that keep the lag at three frames; the script lists them as "without a
valid stamp", and its transit and touch figures come from the measured reads only. `transit_ms` is about 100 ms (three frame periods) by construction; `touch_ms` is the
measure.

**Writer fill time**, which the script does not report. Drop the first 100 grains: the first fills take several
milliseconds because the memory pages are still being mapped.

```sh
for r in reader-local reader; do
  jq -r 'select(.call=="mxlFlowWriterOpenGrain" and .ok) | .fill.fill_us' runs/$r/writer.ndjson |
    tail -n +101 | sort -n | awk -v r=$r '{v[NR]=$1} END {printf "%s: writer fill p50 %.3f ms, p99 %.3f ms\n",
      r, v[int(NR*0.5)]/1000, v[int(NR*0.99)]/1000}'
done
```

## 9. Compare with the study

p50 / p99, in ms, from §6 of [`results.md`](results.md):

| 2160p copy, head-3 | Local reader running | Cross reader running | Cross − local |
|---|---|---|---|
| Reader copy (`touch_ms`) | 1.465 / 1.555 | 1.901 / 2.017 | +0.44 (+30 %) |
| Writer fill | 1.454 / 1.703 | 1.920 / 1.948 | +0.47 (+32 %) |

On other hardware the absolute times will differ. What should hold is the shape: the cross run is slower on
**both** the reader's copy and the writer's fill, by a similar amount.

## 10. Clean up

```sh
docker compose -f docker-compose.numa-writer-reader.yml -f three-readers.yml down
sudo cpupower frequency-set -g schedutil   # or whatever the host used before
```

## Optional: the CPU counters

The study's explanation (where each cache line comes from, the directory snoops) comes from hardware counters taken
with `perf stat` for 30 s, starting 30 s into each run, on each container's CPU list. For example, for §6:

```sh
EV=ocr.reads_to_core.any_response,ocr.reads_to_core.l3_hit,ocr.reads_to_core.l3_hit.snoop_hitm,\
ocr.reads_to_core.l3_hit.snoop_hit_with_fwd,ocr.reads_to_core.remote_cache.snoop_hitm,\
ocr.reads_to_core.remote_cache.snoop_fwd,ocr.reads_to_core.local_dram,ocr.reads_to_core.remote_dram
sudo perf stat -C "$READER_CPUS" -e "$EV" -x, -o ocr-reader.csv -- sleep 30
```

The event names are specific to Sapphire Rapids. The events of the other sections are listed in the
[Counters](results.md#counters) section of the report.

## Variations: the other experiments

All start from the setup above; [`results.md`](results.md) describes each one.

| Section | What changes |
|---|---|
| §1-3, the governor | Scenarios `10`, `08`, `11` at 1080p, trimmed to 5 min (`a7.times = 8999`, `b5.times = 8849`). The writer container also runs its own reader lanes. Run once under `schedutil`, once under `performance` |
| §4, 2160p | Scenarios `14`-`17`, with the writer's own reader lane and both reader containers running at once |
| §8, N readers on one flow | Lane B cloned N times (1, 2, 4, 6) in the reader body, each clone with its own handle names |
| §9-10, several flows and memory stress | Lane A cloned F times (1, 2, 4), each with its own flow id; `stress-ng` on 4 other node-0 cores with `--cpuset-mems 0` (`stress-ng --vm 8 --vm-bytes 4G --vm-keep` in §9, `stress-ng --stream 8 --timeout 900s` in §10) |

## How the original runs were driven

For §5-10 each pass was automated by two scripts on the server. They are not published, but they did exactly the
steps above:

- **A driver**, as an unprivileged user, ran steps 4 to 7 for every run of the pass.
- **A recorder**, as root, ran `perf stat` on each container's CPU list (§5-6) or per socket (`-a --per-socket`,
  §7-10).

They handed off through files in the run directory:
1. The recorder creates `ready`. From §7 on, it first does a 1 s test count, to catch events the CPU rejects.
2. The driver brings the containers up.
3. For each run, the driver creates `go` 30 s in. The recorder counts for 30 s (20 s in §5) and creates
   `recorded`.
4. After the last run, the driver creates `finished` and the recorder exits.

For N readers or F flows (§8-10), the driver cloned lane B, or lane A, onto more lanes before loading the body.
Each clone gets its own handle names, because handles are global to a container. Each writer lane gets its own
flow id: the scenario's id with the last two digits replaced by 10+i. Check the cloned bodies against a spare bench
instance before the first run. For memory stress, the driver started `polinux/stress-ng` on its own cores with
`--cpuset-mems 0`, 15 s before the flows, and removed it after.
