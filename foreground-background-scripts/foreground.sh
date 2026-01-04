#!/bin/bash
echo "🚀 Initializing Airgapped Environment..."
echo "📦 Installing tools and mirroring images to local registry..."

# Wait for background script to create the signal file
while [ ! -f /tmp/finished ]; do 
  sleep 2
  echo -n "."
done

echo -e "\n✅ Environment Ready!"
echo "Your workshop files are located in: ~/workshop"
cd /root/workshop
