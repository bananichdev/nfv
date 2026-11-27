#!/bin/bash
set -euo pipefail
cd "$HOME/nfv-lab4/lab5"
case "$1" in
  topology)
    whoami
    docker ps --filter name=clab-panin-l5 --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    for node in hq br; do
      python3 scripts/ros-exec.py "clab-panin-l5-$node" '/system identity print; /system license print'
    done
    ;;
  bgp)
    python3 scripts/ros-exec.py clab-panin-l5-hq '/routing/bgp/session print'
    docker exec clab-panin-l5-dc1 vtysh -c 'show bgp ipv4 unicast summary'
    docker exec clab-panin-l5-dc1 ip -4 route show proto bgp
    ;;
  wan)
    sh scripts/wan-check.sh
    python3 scripts/ros-exec.py clab-panin-l5-hq '/ip firewall filter print stats where chain=forward'
    ;;
  wireguard)
    bash scripts/wg-check.sh
    python3 scripts/ros-exec.py clab-panin-l5-hq ':put ("handshake=" . [/interface wireguard peers get 0 last-handshake] . " rx=" . [/interface wireguard peers get 0 rx] . " tx=" . [/interface wireguard peers get 0 tx])'
    ;;
  rest)
    sh scripts/rest-demo.sh
    ;;
  final)
    sh scripts/final-check.sh | awk '
    /^ЛР5|^Студент:|^[[:space:]]*name: hq-|^ 0 E|remote.address=|endpoint-address=|last-handshake=|^B>\*|packets transmitted|^Internet HTTP:/ {print}
'
    ;;
esac