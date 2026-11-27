#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export STUDENT=panin N=2
: "${ODL_PASSWORD:?Set ODL_PASSWORD before running}"
prefix=clab-panin-l6
server=10.2.6.100
printf 'ЛР6 | %s | %s@%s | %s, N=%s\n' "$(date -Iseconds)" "$(whoami)" "$(hostname)" "$STUDENT" "$N"
echo 'VNF after heal'
./vnfm.sh list | awk 'NR==1 || /fw[12]|shaper1/'
echo 'RESTCONF per-chain counters'
python3 nfvo.py show vnffg.yaml | awk '/sfc-panin-c[12]-fwd[012]-ip/ {print}'
echo 'Firewall fw2 and shaper'
docker exec "$prefix-fw2" nft list ruleset | grep -E 'block tcp/8002|allow http'
docker exec "$prefix-shaper1" tc qdisc show dev eth2
for client in client1 client2; do
  docker exec "$prefix-$client" curl -fsS -m 5 -o /dev/null \
    -w "$client HTTP: %{http_code}\n" "http://$server/"
done
docker exec "$prefix-client1" iperf3 -c "$server" -t 3 | grep -E 'sender|receiver'
