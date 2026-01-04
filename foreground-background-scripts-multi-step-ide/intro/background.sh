#!/bin/bash
set -eux

#####################################
# CONTROLPLANE SETUP
#####################################

apt-get update
apt-get install -y podman skopeo git curl jq

# Start local registry
podman run -d \
  --name workshop-registry \
  --restart always \
  -p 5000:5000 \
  registry:2

echo "✅ Registry running on controlplane:5000"

#####################################
# CLONE WORKSHOP REPO (controlplane)
#####################################

git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

#####################################
# MIRROR IMAGES (ASYNC, BACKGROUND)
#####################################

echo "🚀 Starting image mirroring in background..."
echo "📄 Logs: /var/log/local-registry.log"

# Ensure script is executable
chmod +x local-registry.sh

# Run mirroring in background with logs
nohup bash local-registry.sh \
  > /var/log/local-registry.log 2>&1 &

#####################################
# NODE01 SETUP
#####################################

ssh root@node01 <<'EOF'
set -eux

# Install required tools
apt-get update
apt-get install -y podman git skopeo

# Clone workshop repo
git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

# Ensure registry config dir exists
mkdir -p /etc/containers/registries.conf.d

# Replace mirror IP with controlplane hostname
sed -i 's/192.168.100.1/controlplane/g' assets/99-offline.conf

# Copy offline registry config
cp assets/99-offline.conf /etc/containers/registries.conf.d/99-offline.conf

echo "✅ node01 configured to use controlplane:5000 as registry mirror"
EOF

#####################################
# SIGNAL READY
#####################################

touch /tmp/finished
echo "🎉 Workshop environment ready"
echo "ℹ️ Image mirroring continues in background"
echo "ℹ️ Check progress: tail -f /var/log/local-registry.log"
