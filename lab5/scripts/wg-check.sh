#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

printf '%s\n' 'Outer WireGuard headers on ISP eth2:'
docker exec -i clab-panin-l5-isp python3 -u - < scripts/capture-wg.py &
capture=$!
sleep 1
docker exec clab-panin-l5-pcb ping -c 3 -W 2 10.2.100.10
wait "$capture"
