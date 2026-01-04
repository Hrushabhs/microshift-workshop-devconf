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

chmod +x local-registry.sh

nohup bash local-registry.sh \
  > /var/log/local-registry.log 2>&1 &

#####################################
# NODE01 SETUP
#####################################

ssh root@node01 <<'EOF'
set -eux

echo "🧹 Phase 1: Stop and disable Kubernetes services"

systemctl stop kubelet containerd || true
systemctl disable kubelet || true

#####################################
# FORCE UNMOUNT BUSY KUBELET VOLUMES
#####################################

echo "🧹 Phase 2: Lazy-unmount kubelet volumes"

for mount in $(mount | grep /var/lib/kubelet | awk '{print $3}'); do
    umount -l "$mount" || true
done

#####################################
# PURGE KUBERNETES PACKAGES & DATA
#####################################

echo "🧹 Phase 3: Remove Kubernetes packages and data"

apt-get purge -y kubeadm kubelet kubectl kubernetes-cni cri-tools || true
apt-get autoremove -y || true

rm -rf /etc/kubernetes \
       /var/lib/kubelet \
       /var/lib/etcd \
       /root/.kube

#####################################
# WIPE CONTAINER RUNTIME STORAGE
#####################################

echo "🧹 Phase 4: Wipe containerd storage"

rm -rf /var/lib/containerd/*

#####################################
# INSTALL REQUIRED TOOLS (NODE01)
#####################################

echo "🔧 Installing Podman, Git, Skopeo"

apt-get update
apt-get install -y podman git skopeo

#####################################
# CLONE WORKSHOP REPO (node01)
#####################################

git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

#####################################
# CONFIGURE OFFLINE REGISTRY MIRROR
#####################################

mkdir -p /etc/containers/registries.conf.d

sed -i 's/192.168.100.1/controlplane/g' assets/99-offline.conf
cp assets/99-offline.conf /etc/containers/registries.conf.d/99-offline.conf

#####################################
# PRE-PULL BASE IMAGE (FROM LOCAL REGISTRY)
#####################################

echo "📦 Pre-pulling bootc base image via local registry"

podman pull quay.io/centos-bootc/centos-bootc:stream9

echo "✅ node01 ready (disk cleaned + registry configured)"
df -h

EOF

#####################################
# SIGNAL READY
#####################################

touch /tmp/finished

echo "🎉 Workshop environment ready"
echo "ℹ️ Image mirroring continues in background"
echo "ℹ️ Check progress: tail -f /var/log/local-registry.log"
