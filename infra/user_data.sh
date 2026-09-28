#!/bin/bash
# Runs once, as root, on the instance's first boot. Log: /var/log/cloud-init-output.log
set -euo pipefail

# k3s: single-node Kubernetes with Traefik ingress, ServiceLB and metrics-server built in.
# Use it with `sudo kubectl ...` (kubeconfig at /etc/rancher/k3s/k3s.yaml is root-only).
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -
