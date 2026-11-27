#!/bin/sh
set -eu

DC1=${DC1:-clab-panin-l5-dc1}

docker exec "$DC1" supervisorctl start zebra mgmtd staticd bgpd >/dev/null 2>&1 || true
docker exec "$DC1" config interface startup Ethernet0
docker exec "$DC1" config interface startup Ethernet4
docker exec "$DC1" config interface ip add Ethernet0 10.2.100.1/24 || true
docker exec "$DC1" config interface ip add Ethernet4 10.2.1.1/30 || true
docker exec "$DC1" ip route del default dev eth0 >/dev/null 2>&1 || true

docker exec "$DC1" vtysh -c "configure terminal" \
  -c "router bgp 65002" \
  -c "bgp router-id 10.2.1.1" \
  -c "no bgp ebgp-requires-policy" \
  -c "neighbor 10.2.1.2 remote-as 65102" \
  -c "address-family ipv4 unicast" \
  -c "network 10.2.100.0/24" \
  -c "exit-address-family" \
  -c "end" \
  -c "write memory"

echo "dc1 addressing and FRR BGP configured"
