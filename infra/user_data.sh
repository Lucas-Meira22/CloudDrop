#!/bin/bash
# Runs once, as root, on the instance's first boot. Log: /var/log/cloud-init-output.log
set -euo pipefail

# k3s: single-node Kubernetes with Traefik ingress, ServiceLB and metrics-server built in.
# Use it with `sudo kubectl ...` (kubeconfig at /etc/rancher/k3s/k3s.yaml is root-only).
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -

# AWS CLI, used by the ECR refresh script below
snap install aws-cli --classic

# ECR tokens expire after 12h. This script gets a fresh one with the instance
# role (no keys) and saves it as the imagePullSecret "ecr-pull".
# Values like region and namespace are filled in by Terraform (templatefile);
# bash variables use $VAR without braces so Terraform leaves them alone.
cat > /usr/local/bin/ecr-refresh.sh <<'EOF'
#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
TOKEN=$(/snap/bin/aws ecr get-login-password --region ${region})

kubectl create namespace ${namespace} --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry ecr-pull \
  --namespace ${namespace} \
  --docker-server=${ecr_registry} \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
EOF
chmod 755 /usr/local/bin/ecr-refresh.sh

cat > /etc/systemd/system/ecr-refresh.service <<'EOF'
[Unit]
Description=Refresh the ECR imagePullSecret
After=k3s.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ecr-refresh.sh
Restart=on-failure
RestartSec=30
EOF

cat > /etc/systemd/system/ecr-refresh.timer <<'EOF'
[Unit]
Description=Refresh the ECR imagePullSecret every 6 hours

[Timer]
OnBootSec=1min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ecr-refresh.timer
