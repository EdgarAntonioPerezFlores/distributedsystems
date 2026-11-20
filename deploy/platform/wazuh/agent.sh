#!/bin/bash
set -eu
sed -i 's|MANAGER_IP|wazuh-workers.wazuh.svc|g; s|</ossec_config>|<localfile><log_format>json</log_format><location>/host/audit/audit.log</location></localfile><syscheck><directories check_all="yes">/host/config</directories></syscheck></ossec_config>|' /var/ossec/etc/ossec.conf
if ! test -s /var/ossec/etc/client.keys; then
  /var/ossec/bin/agent-auth -m wazuh.wazuh.svc -A "$NODE_NAME" -P "$(cat /enroll/authd.pass)"
fi
/var/ossec/bin/wazuh-control start
trap '/var/ossec/bin/wazuh-control stop; exit 0' TERM INT
while /var/ossec/bin/wazuh-control status | grep -q 'wazuh-agentd is running'; do sleep 15 & wait $!; done
exit 1
