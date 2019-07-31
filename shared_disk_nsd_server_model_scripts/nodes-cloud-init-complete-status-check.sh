#!/bin/bash
set -x
hostname
while [ ! -f /tmp/complete ]
do
  sleep 60s
  echo "Waiting for compute node: `hostname --fqdn` initialization to complete ..."
done

