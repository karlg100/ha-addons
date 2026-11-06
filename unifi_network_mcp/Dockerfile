# Multi-arch Python base; unifi-network-mcp requires Python 3.13+.
FROM python:3.13-slim

ARG UNIFI_NETWORK_MCP_VERSION=0.45.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir "unifi-network-mcp==${UNIFI_NETWORK_MCP_VERSION}"

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
