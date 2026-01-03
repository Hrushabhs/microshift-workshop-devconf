#!/bin/bash

# 1. Install required packages
# Standard Ubuntu update and installation of required binaries
apt-get update && apt-get install -y skopeo git git-lfs

# 2. Initialize Git LFS
# Essential for handling large binary files (RPMs) in your repository
git lfs install

# 3. Start Local Registry
# Runs a containerized registry on the host to act as the airgapped mirror
podman run -d -p 5000:5000 --restart always --name workshop-registry registry:2

# 4. Clone your workshop repo
# Clones the hands-on instructions and assets for the session
git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

# 5. Mirror images using your list to localhost:5000
# Loops through image-list.txt to populate the local registry
REGISTRY="localhost:5000"
while read -r IMAGE; do
    [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue
    echo "Mirroring $IMAGE..."
    DEST_PATH="${IMAGE#*/}"
    skopeo copy --all --preserve-digests --format v2s2 --dest-tls-verify=false \
        docker://"$IMAGE" docker://"$REGISTRY/$DEST_PATH"
done < image-list.txt

# --- 99-offline and VM_IP Fix ---

# 6. Detect the VM IP (Host IP)
# Captures the specific IP of the attendee's VM to avoid hardcoded mismatches
VM_IP=$(hostname -I | awk '{print $1}')
echo "Detected VM IP: $VM_IP"

# 7. Update and Copy the 99-offline configuration
# Dynamically modifies the config file so Podman knows how to reach the local mirror
if [ -f "/root/workshop/assets/99-offline.conf" ]; then
    # Dual-replacement to ensure the placeholder is replaced correctly
    sed -i "s/VM_IP/$VM_IP/g" /root/workshop/assets/99-offline.conf
    sed -i "s/192.168.100.1/$VM_IP/g" /root/workshop/assets/99-offline.conf
    
    # Copy to the system location so 'podman build' uses the local mirror
    cp /root/workshop/assets/99-offline.conf /etc/containers/registries.conf.d/99-offline.conf
    echo "✅ Success: System is now mirroring to $VM_IP:5000"
fi

# --- End Fix ---

# 8. Pre-pull base images to host cache using sudo
# Using sudo ensures these images are available in the root-owned container storage
sudo podman pull quay.io/centos-bootc/centos-bootc:stream9
sudo podman pull quay.io/centos-bootc/centos-bootc:stream10

# Signal completion for foreground.sh
# Creates the indicator that the environment setup is finished
touch /tmp/finished
