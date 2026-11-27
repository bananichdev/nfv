#!/bin/sh
set -eu

HQ_IP=${HQ_IP:-10.105.2.12}
ROS_USER=${ROS_USER:-admin}
: "${ROS_PASS:?Set ROS_PASS to the lab RouterOS password}"
BASE="http://${HQ_IP}/rest"
AUTH="${ROS_USER}:${ROS_PASS}"

printf '%s\n' '--- GET identity ---'
curl -fsS -u "$AUTH" "$BASE/system/identity" | jq -c .
printf '%s\n' '--- GET addresses ---'
curl -fsS -u "$AUTH" "$BASE/ip/address" | jq -r '.[] | "\(.address)\t\(.interface)"'
printf '%s\n' '--- GET BGP sessions ---'
curl -fsS -u "$AUTH" "$BASE/routing/bgp/session" | jq -c '.[] | {name, established, peer: ."remote.address", as: ."remote.as"}'

printf '%s\n' '--- PUT temporary address-list record ---'
entry=$(curl -fsS -u "$AUTH" -X PUT "$BASE/ip/firewall/address-list" \
  -H 'content-type: application/json' \
  -d '{"list":"lab5-rest-demo","address":"192.0.2.2","comment":"panin"}')
printf '%s\n' "$entry" | jq -c '{id: .".id", list, address, comment}'
id=$(printf '%s\n' "$entry" | jq -er '.".id"')
cleanup() { curl -fsS -u "$AUTH" -X DELETE "$BASE/ip/firewall/address-list/$id" -o /dev/null; }
trap cleanup EXIT

printf '%s\n' '--- PATCH the same record ---'
curl -fsS -u "$AUTH" -X PATCH "$BASE/ip/firewall/address-list/$id" \
  -H 'content-type: application/json' \
  -d '{"comment":"patched by REST"}' | jq -c '{id: .".id", comment}'
printf '%s\n' '--- DELETE the same record ---'
curl -fsS -u "$AUTH" -X DELETE "$BASE/ip/firewall/address-list/$id" -o /dev/null -w 'HTTP %{http_code}\n'
trap - EXIT
