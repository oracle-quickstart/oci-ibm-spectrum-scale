#!/bin/bash
set -x
hostname
while [ ! -f /tmp/cloud_init.complete ]
do
  sleep 60s
  echo "Waiting for compute node: `hostname --fqdn` cloud-init to complete ..."
done

