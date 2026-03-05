#!/bin/bash
set -euo pipefail

DUCKDNS_TOKEN="${duckdns_token}"
DUCKDNS_SUBDOMAIN="${duckdns_subdomain}"
MC_PRIVATE_IP="${mc_private_ip}"
AWS_REGION="${aws_region}"
MC_VERSION="${mc_version}"
MSH_VERSION="2.6.2"

# ── System update ──────────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl jq unzip

# Install AWS CLI v2
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# ── DuckDNS: update IP every 5 minutes ────────────────────────────────────
mkdir -p /opt/duckdns
cat > /opt/duckdns/update.sh << DUCKEOF
#!/bin/bash
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" -o /opt/duckdns/duck.log
DUCKEOF
chmod +x /opt/duckdns/update.sh
/opt/duckdns/update.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/update.sh") | crontab -

# ── mc-hibernation: proxy + auto-wake ─────────────────────────────────────
MSH_DIR=/opt/mc-hibernation
mkdir -p "$MSH_DIR"

# Download binary (ARM64 for t4g)
curl -sL "https://github.com/gekware/minecraft-server-hibernation/releases/download/v${MSH_VERSION}/msh-linux-arm64" \
  -o "$MSH_DIR/msh"
chmod +x "$MSH_DIR/msh"

# Start script: find MC instance by tag and boot it
cat > "$MSH_DIR/start-mc.sh" << STARTEOF
#!/bin/bash
INSTANCE_ID=\$(/usr/local/bin/aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters "Name=tag:Name,Values=minecraft-server" \
            "Name=instance-state-name,Values=stopped,stopping" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null)

if [ "\$INSTANCE_ID" != "None" ] && [ -n "\$INSTANCE_ID" ]; then
  echo "\$(date): Starting MC instance \$INSTANCE_ID"
  /usr/local/bin/aws ec2 start-instances --region ${AWS_REGION} --instance-ids "\$INSTANCE_ID"
  /usr/local/bin/aws ec2 wait instance-running --region ${AWS_REGION} --instance-ids "\$INSTANCE_ID"
  # Give MC server ~60s to fully start after OS boot
  sleep 60
  echo "\$(date): MC instance ready"
fi
STARTEOF
chmod +x "$MSH_DIR/start-mc.sh"

# mc-hibernation config
cat > "$MSH_DIR/msh-config.json" << CFGEOF
{
  "Basic": {
    "StartMinecraftServer": "bash /opt/mc-hibernation/start-mc.sh",
    "StopMinecraftServer": "",
    "MinecraftServerAddress": "${MC_PRIVATE_IP}:25565",
    "MinecraftServerVersion": "${MC_VERSION}",
    "MinecraftServerType": "Paper",
    "ListenHost": "0.0.0.0",
    "ListenPort": "25565"
  },
  "Advanced": {
    "StopMinecraftServerAllowKill": 30,
    "StopMinecraftServerTimeout": 30,
    "TimeBeforeStoppingEmptyServer": 120
  }
}
CFGEOF

# systemd service for mc-hibernation
cat > /etc/systemd/system/mc-hibernation.service << SVCEOF
[Unit]
Description=Minecraft Hibernation Proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/mc-hibernation
ExecStart=/opt/mc-hibernation/msh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable mc-hibernation
systemctl start mc-hibernation

echo "Watcher setup complete. DuckDNS: ${DUCKDNS_SUBDOMAIN}.duckdns.org"
