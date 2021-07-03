#!/usr/bin/env bash

# settings
url=${URL:-https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2}
name=${NAME:-AlmaLinux 8 latest x86_64}
region=${REGION:-nyc3}
tags=${TAGS:-AlmaLinux}
distribution=${DISTRIBUTION:-CentOS}

#checks
if ! command -v doctl &> /dev/null; then
	echo "You haven't installed doctl. Please do so."
	exit 1
fi

# do it!
output=$(
	doctl compute image create "$name" \
		--image-url="$url" \
		--region="$region" \
		--tag-names="$tags" \
		--image-distribution="$distribution"
)

# export image ID
export DIGITALOCEAN_IMAGE=$( echo -e "$output" | tail -n 1 | cut -d ' ' -f 1 )
echo "image id: $DIGITALOCEAN_IMAGE"

# sleep for 5 minutes
echo "Sleeping 5 minutes to alow the image be downloaded by DigitalOcean..."
sleep 5m
