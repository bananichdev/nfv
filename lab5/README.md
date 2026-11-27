# Лабораторная работа № 5. MikroTik CHR как vCPE

В WSL2 развернута сеть предприятия из SONiC с FRR, двух MikroTik CHR и трех Linux-контейнеров. Для варианта panin, N=2, ЦОД получает маршруты от vCPE по eBGP. Филиал подключается к ЦОД через WireGuard. Провайдер в стенде имитируется Linux-узлом isp.

```text
srv1 ── dc1 (SONiC/FRR) ── hq-panin (CHR) ── isp ── br-panin (CHR) ── pcb
         AS 65002           AS 65102    ╰─────── WireGuard ────────╯
```

| Участок | Адреса |
| --- | --- |
| ЦОД | Ethernet0 dc1 `10.2.100.1/24`, srv1 `10.2.100.10/24` |
| dc1 ↔ hq | Ethernet4 dc1 `10.2.1.1/30`, ether2 hq `10.2.1.2/30` |
| hq ↔ isp | ether3 hq `100.64.1.2/30`, eth1 isp `100.64.1.1/30` |
| isp ↔ br | eth2 isp `100.64.2.1/30`, ether2 br `100.64.2.2/30` |
| Филиал | ether3 br `10.2.200.1/24`, pcb `10.2.200.10/24` |
| WireGuard | wg-br `10.2.254.1/30`, wg-hq `10.2.254.2/30`, UDP `13002` |
| Управление и HTTP | Docker `10.105.2.0/24`, hq REST `10.105.2.12`, HTTP на isp `198.51.100.1` |

## Запуск

Нужны WSL2 с доступным `/dev/kvm`, Containerlab, Docker, Python, jq и curl. Образы перечислены в [топологии](lab5.clab.yml). В [images](images) находятся скрипты подготовки CHR и SONiC. Образ `lab-tools:1.0` можно собрать из Dockerfile в `lab4/images/lab-tools`.

```bash
cd ~/nfv-lab4/lab5
sudo containerlab deploy -t lab5.clab.yml
docker ps --filter name=clab-panin-l5
sh configs/dc1.sh
python3 scripts/configure-routeros.py
```

Перед настройкой CHR дождитесь статуса healthy у hq и br. Скрипт создаёт ключи WireGuard на маршрутизаторах и обменивается публичными ключами. Экспорты [hq](configs/hq.rsc), [br](configs/br.rsc) и [FRR](configs/dc1-frr.conf) фиксируют состояние стенда после настройки. Для повторного развертывания используйте скрипты, чтобы обе стороны WireGuard получили актуальные ключи.

## Межсетевой экран hq

Правила проверяются сверху вниз. Masquerade выполняется на ether3 hq для выходящих к провайдеру пакетов ЦОД.

| Цепочка | Правило | Назначение |
| --- | --- | --- |
| input | input-established | Пропуск established и related |
| input | input-invalid | Сброс invalid |
| input | input-icmp | Диагностика ICMP самого hq |
| input | input-mgmt | Управление через ether1 |
| input | input-bgp | TCP 179 от ЦОД через ether2 |
| input | input-wireguard | UDP 13002 для туннеля |
| input | input-wan-deny | Сброс остального с ether3 |
| input | input-default-deny | Сброс прочего трафика к hq |
| forward | forward-established | Ответы и связанный транзитный трафик |
| forward | forward-invalid | Сброс некорректного транзита |
| forward | dc-to-internet | ЦОД → ISP |
| forward | branch-to-dc | Филиал → ЦОД через wg-br |
| forward | dc-to-branch | ЦОД → филиал через wg-br |
| forward | forward-default-deny | Сброс оставшегося транзитного трафика |

## Результаты

| Проверка | Результат | Снимок окна WSL |
| --- | --- | --- |
| Контейнеры и RouterOS | Шесть узлов, имена hq-panin и br-panin, лицензия free | [Топология](evidence/01-topology.png) |
| eBGP | Established, AS 65002 ↔ 65102, на dc1 выбраны 0.0.0.0/0 и 10.2.200.0/24 | [BGP](evidence/02-bgp.png) |
| NAT и firewall | HTTP 200, в журнале ISP адрес 100.64.1.2. Два ICMP-запроса от ISP не получили ответов, счетчик deny вырос на два | [WAN](evidence/03-wan.png) |
| WireGuard | 3/3 ответов от srv1, видны внешние заголовки UDP 13002, установлен handshake | [Туннель](evidence/04-wireguard.png) |
| REST | GET конфигурации, PUT, PATCH и DELETE одной временной записи, HTTP 204 | [REST](evidence/05-rest.png) |
| Итог | Свежий handshake, оба BGP-маршрута, ping 2/2 и HTTP 200 | [Итог](evidence/06-final.png) |

Сценарий устного показа и команды находятся в [DEFENSE.md](DEFENSE.md). REST работает по HTTP внутри изолированной сети управления стенда.
