#!/bin/bash
set -eux

#####################################
# CONTROLPLANE SETUP
#####################################

apt-get update
apt-get install -y podman skopeo git

# Start local registry
podman run -d \
  --name workshop-registry \
  --restart always \
  -p 5000:5000 \
  registry:2

echo "✅ Registry running on controlplane:5000"

#####################################
# MIRROR IMAGES (controlplane)
#####################################

git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

REGISTRY="localhost:5000"

while read -r IMAGE; do
    [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue
    DEST_PATH="${IMAGE#*/}"
    echo "Mirroring $IMAGE -> $REGISTRY/$DEST_PATH"
    skopeo copy --all --preserve-digests --dest-tls-verify=false \
        docker://"$IMAGE" docker://"$REGISTRY/$DEST_PATH"
done < image-list.txt

#####################################

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
