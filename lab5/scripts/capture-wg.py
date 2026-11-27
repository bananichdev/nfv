"""Print outer UDP headers on the isolated ISP-to-branch link."""
import socket
import struct
import time

with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0800)) as sock:
    sock.bind(("eth2", 0))
    deadline = time.monotonic() + 8
    seen = 0
    while seen < 6 and time.monotonic() < deadline:
        sock.settimeout(max(0.01, deadline - time.monotonic()))
        try:
            frame = sock.recv(65535)
        except TimeoutError:
            break
        if len(frame) < 42 or frame[23] != socket.IPPROTO_UDP:
            continue
        offset = 14 + (frame[14] & 15) * 4
        if len(frame) < offset + 8:
            continue
        source_port, destination_port = struct.unpack_from("!HH", frame, offset)
        if (source_port, destination_port) != (13002, 13002):
            continue
        source_ip = socket.inet_ntoa(frame[26:30])
        destination_ip = socket.inet_ntoa(frame[30:34])
        print(f"UDP {source_ip}:{source_port} > {destination_ip}:{destination_port}")
        seen += 1
    if seen < 2:
        raise SystemExit("Too few WireGuard packets on eth2")
