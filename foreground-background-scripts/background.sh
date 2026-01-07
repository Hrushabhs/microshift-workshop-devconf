#!/bin/bash
set -eux



git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git /root/workshop
cd /root/workshop

#####################################
# CONFIGURE OFFLINE REGISTRY MIRROR
#####################################
mkdir /tmp/test11


podman pull quay.io/rhn_engineering_hsirsulw/microshift-killercoda.v1:latest


#####################################
# SIGNAL READY
#####################################

touch /tmp/finished

echo "🎉 Workshop environment ready"
echo "ℹ️ Image mirroring continues in background"
echo "ℹ️ Check progress: tail -f /var/log/local-registry.log"
