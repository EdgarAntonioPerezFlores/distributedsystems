FROM ubuntu:24.04
ARG WAZUH_VERSION=4.12.0-1
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg && curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg && echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' >/etc/apt/sources.list.d/wazuh.list && apt-get update && apt-get install --no-install-recommends -y wazuh-agent=$WAZUH_VERSION && rm -rf /var/lib/apt/lists/*
COPY deploy/platform/wazuh/agent.sh /usr/local/bin/start-agent
CMD ["bash","/usr/local/bin/start-agent"]
