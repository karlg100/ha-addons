# Multi-arch Python base; unifi-network-mcp requires Python 3.13+.
FROM python:3.13-slim

ARG UNIFI_NETWORK_MCP_VERSION=0.45.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir "unifi-network-mcp==${UNIFI_NETWORK_MCP_VERSION}"

COPY run.sh preflight.py /
RUN chmod a+x /run.sh

# Lets Supervisor see when the server stops accepting connections and restart it.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python3 -c "import socket; socket.create_connection(('127.0.0.1', 3000), 3).close()"

CMD ["/run.sh"]
