FROM lab-tools:1.0
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nftables iperf3 && \
    rm -rf /var/lib/apt/lists/*
