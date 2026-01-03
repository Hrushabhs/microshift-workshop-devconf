#!/bin/bash
# 1. Install required packages
apt-get update && apt-get install -y skopeo git

# 2. Start Local Registry
podman run -d -p 5000:5000 --restart always --name workshop-registry registry:2

# 3. Clone your workshop repo to /root/workshop
git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

# 4. Mirror images using your list to localhost:5000
REGISTRY="localhost:5000"
while read -r IMAGE; do
    [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue
    echo "Mirroring $IMAGE..."
    DEST_PATH="${IMAGE#*/}"
    skopeo copy --all --preserve-digests --format v2s2 --dest-tls-verify=false \
        docker://"$IMAGE" docker://"$REGISTRY/$DEST_PATH"
done < image-list.txt

# 5. Pre-pull base images to host cache for speed
podman pull quay.io/centos-bootc/centos-bootc:stream9
podman pull quay.io/centos-bootc/centos-bootc:stream10

# Signal completion
touch /tmp/finished
