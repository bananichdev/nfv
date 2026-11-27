#!/bin/sh
set -eu

: "${ROS_PASS:?Set ROS_PASS in the shell}"
cd "$(dirname "$0")/.."
filter_count() {
    python3 scripts/ros-exec.py clab-panin-l5-hq \
        ':put [/ip firewall filter get [find comment=forward-default-deny] packets]' |
        tr -d '\r' | awk '/^[0-9]+$/ {print; exit}'
}

printf '%s\n' 'NAT: srv1 -> ISP HTTP'
docker exec clab-panin-l5-srv1 curl -fsS --max-time 8 -o /dev/null \
    -w 'HTTP %{http_code}\n' http://198.51.100.1/
docker logs --tail 1 clab-panin-l5-isp 2>&1

before=$(filter_count)
docker exec clab-panin-l5-isp ip route replace 10.2.100.0/24 via 100.64.1.2
trap 'docker exec clab-panin-l5-isp ip route del 10.2.100.0/24 via 100.64.1.2' EXIT
printf '\n%s\n' 'Firewall: ISP -> srv1'
status=0
docker exec clab-panin-l5-isp ping -c 2 -W 1 10.2.100.10 || status=$?
test "$status" -eq 1
after=$(filter_count)
printf 'forward-default-deny: %s -> %s packets\n' "$before" "$after"
test "$((after - before))" -eq 2
