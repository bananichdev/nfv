# ЛР6. Цепочка сервисных функций под управлением SDN

Вариант `panin`, `N=2`. Клиенты обращаются к серверу через прозрачный firewall и шейпер. OpenDaylight устанавливает потоки в OVS, которые направляют кадры через функции в обе стороны. Адреса хостов при изменении цепочки сохраняются.

```text
                          OpenDaylight 10.106.2.100
                               │ OpenFlow 1.3
client1 (1) ─┐                 │
client2 (2) ─┼────────────── OVS br0
server  (9) ─┘             ├─ (3,4) fw1 до terminate
                           ├─ (5,6) fw2
                           └─ (7,8) shaper1
```

| Параметр | Значение |
| --- | --- |
| Management | `10.106.2.0/24`, ODL `10.106.2.100`, OVS `10.106.2.10` |
| Data | client1 `10.2.6.11`, client2 `10.2.6.12`, server `10.2.6.100`, маска /24 |
| Firewall | TCP `8002`, HTTP `80` разрешен |
| Shaper | TBF `12 Мбит/с` на `eth2` по направлению к серверу |
| Цепочки | `panin-c1` и `panin-c2`, в финале `fw2 → shaper1` |

| Роль ETSI NFV | Компонент стенда |
| --- | --- |
| NFVI | WSL2, Docker, Linux-мосты, OVS userspace |
| VIM | Docker и Containerlab |
| SDN / WIM | OpenDaylight и OpenFlow Plugin |
| VNFM | `vnfm.sh` создает, настраивает и удаляет VNF |
| NFVO | `nfvo.py` читает YAML и программирует потоки через RESTCONF |
| VNFD / VNFFGD | `descriptors/*.yaml` и `vnffg.yaml` |

## Переходы c1

На каждом переходе два правила, для IPv4 и ARP. В прямом направлении матчится IP клиента как источник, в обратном как получатель. Приоритет 300.

| Направление | Исходный граф | После heal |
| --- | --- | --- |
| Клиент → FW | 1 → 3 | 1 → 5 |
| FW → shaper | 4 → 7 | 6 → 7 |
| Shaper → сервер | 8 → 9 | 8 → 9 |
| Сервер → shaper | 9 → 8 | 9 → 8 |
| Shaper → FW | 7 → 4 | 7 → 6 |
| FW → клиент | 3 → 1 | 5 → 1 |

## Развертывание финального состояния

Нужны Docker, Containerlab, Python с `requests` и `yaml`, `envsubst` и образы ЛР4. Если образы ЛР4 еще не собраны, используйте `../lab4/images/build-images.sh`. Следующий блок предназначен для чистого развертывания.

```bash
cd ~/nfv-lab4/lab6
export STUDENT=panin N=2
docker build -t lab6-tools:1.0 images
sudo --preserve-env=STUDENT,N containerlab deploy -t lab6.clab.yml
docker exec -d clab-panin-l6-server iperf3 -s
docker exec -d clab-panin-l6-server python3 -m http.server 8002 --bind 10.2.6.100
```

Дождитесь готовности Karaf и подключите OVS. Перед отправкой потоков проверьте `is_connected: true`.

```bash
docker exec -t clab-panin-l6-odl /opt/odl/bin/client \
  "feature:install odl-openflowplugin-flow-services-rest odl-openflowplugin-app-table-miss-enforcer"
docker exec -i -e ODL_IP=10.106.2.100 clab-panin-l6-sw sh < scripts/sw-setup.sh
docker exec clab-panin-l6-sw ovs-vsctl show
./vnfm.sh configure shaper1 shaper
sudo --preserve-env=STUDENT,N ./vnfm.sh instantiate fw2 fw 5 6
read -rsp 'Пароль ODL: ' ODL_PASSWORD
echo
export ODL_PASSWORD
python3 nfvo.py apply vnffg.yaml
./vnfm.sh terminate fw1 3 4
bash scripts/final-check.sh
```

При первом развертывании обе цепочки проходили через `fw1`. Историю графа можно посмотреть командой `git log -p -- vnffg.yaml`. Для повторения ранних этапов применяйте соответствующую версию графа после конфигурации `fw1`. Текущий граф соответствует состоянию после heal.

На ядре WSL нет `CONFIG_NF_TABLES_BRIDGE`. VNFM сначала проверяет стандартный вариант и при необходимости выбирает `netdev ingress` на обоих портах VNF. Оба варианта используют Linux-мост для прозрачной пересылки. Для стабильной передачи TCP через TBF в WSL буфер увеличен до 64 КиБ при сохранении скорости 12 Мбит/с.

## Проверки

| Этап | Результат | Снимок из WSL |
| --- | --- | --- |
| NFVI | OVS подключен, до потоков ping 0/2 | [Исходное состояние](evidence/01-before.png) |
| VNF | nftables блокирует TCP 8002, TBF настроен на 12 Мбит/с | [Настройки](evidence/02-vnf.png) |
| SFC | 24 потока, ping 2/2, HTTP 80 → 200, HTTP 8002 → 000, 3 пакета в drop | [Применение графа](evidence/03-chain.png) |
| Производительность | Получатель iperf3 за 5 с: вперед 11,1 Мбит/с, назад 471 Мбит/с | [Сравнение направлений](evidence/04-performance.png) |
| Scale-out | c2 перенесена на fw2, при HTTP от client2 fw1 6 → 6, fw2 0 → 6 | [Scale-out](evidence/05-scale.png) |
| Heal | При отказе c1 0/2, c2 2/2, c1 восстановлена за 6,36 с, fw1 удален | [Heal](evidence/06-heal.png) |
| Reverse -P 4 | 850 Мбит/с у получателя за 10 с, снимок загрузки CPU | [Нагрузка](evidence/07-acceleration.png) |
| Финал | Обе цепочки через fw2, HTTP 200 у обоих, 11,8 Мбит/с вперед | [Живой итог](evidence/08-final.png) |

Отсчет heal шел с момента запроса `docker stop` до первого успешного ping, включая проверки доступности и применение графа. Результаты производительности относятся к этому виртуальному стенду. Сценарий выступления и команды показа находятся в [DEFENSE.md](DEFENSE.md).
