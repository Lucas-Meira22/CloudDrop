# Weekend Project: **CloudDrop** — a file-sharing API on AWS + Kubernetes

## Context
A portfolio project for a Cloud/DevOps Engineer job hunt, built in one weekend by someone who holds the KCNA.
It covers the skills recruiters look for: **AWS (EC2, S3, ECR, IAM, VPC)**, **Terraform (IaC)**, **Docker**, **Kubernetes manifests**, **CI/CD**, **GitOps** and **observability**. Each part is kept small enough to finish.
The working directory `projForWeek/` is empty, so everything starts from scratch.

**Decisions made:** AWS (the most-requested cloud in job postings), k3s on one EC2 VM (cheap and hands-on, ~US$2–5 for the weekend), Python + FastAPI for the app.

## What the app does
A small REST API:
- `POST /files`: uploads a file, which is stored in a private **S3** bucket
- `GET /files`: lists the files
- `GET /files/{name}`: returns a **pre-signed S3 URL** (a temporary download link)
- `GET /healthz`, `GET /readyz`: liveness and readiness probes for Kubernetes
- `GET /metrics`: Prometheus metrics

The app reaches S3 through the **EC2 IAM role**, so there are **no access keys** anywhere. Recruiters look for this.

## Architecture
```
GitHub repo ──push──> GitHub Actions (test → build → Trivy scan → push to ECR via OIDC → bump image tag)
                                                                  │
                                         Argo CD (in the cluster) pulls the repo (GitOps)
                                                                  ▼
AWS VPC ─ public subnet ─ EC2 t3.small (k3s)
   ├─ Traefik Ingress ─> Service ─> Deployment (clouddrop, 2 replicas, HPA)
   ├─ kube-prometheus-stack (Prometheus + Grafana)
   └─ IAM instance role ──> S3 bucket (private, encrypted, versioned) + ECR pull
Terraform state ──> S3 backend (with lockfile)
Access: SSM Session Manager (no SSH port open)
```

## Repo layout
```
projForWeek/
├── app/                  main.py, requirements.txt, tests/test_main.py
├── Dockerfile            multi-stage, non-root user, slim base
├── infra/                Terraform: providers.tf, backend.tf, vpc.tf, ec2.tf, iam.tf,
│                         s3.tf, ecr.tf, budget.tf, variables.tf, outputs.tf, user_data.sh
├── k8s/
│   ├── base/             namespace, deployment, service, ingress, configmap, hpa, kustomization.yaml
│   └── overlays/prod/    kustomization.yaml (image tag, replica count)
├── argocd/               application.yaml
├── .github/workflows/    ci.yaml
├── docs/                 architecture diagram (draw.io/excalidraw PNG), screenshots
└── README.md
```

## Timeline

### Friday night (1–2h): prep
- Create the AWS account, enable **MFA on root**, create an IAM admin user, and install `aws cli`, `terraform`, `docker`, `kubectl`, `helm`
- **Set up an AWS Budget alert (US$10)** before creating anything else
- Create the GitHub repo, `.gitignore` (`*.tfstate`, `.terraform/`, `*.pem`, `.env`)
- Create the Terraform state bucket once by hand (the S3 backend needs it to exist before Terraform runs)

### Saturday: the core (must finish)
**Block 1: the app (~2h)**
- FastAPI app using `boto3`. Bucket name and region come from environment variables
- 3–4 pytest tests (mock S3 with `moto`)
- Dockerfile: multi-stage build, runs as `USER 10001`, `HEALTHCHECK`; test with `docker run` locally

**Block 2: Terraform (~3h)**
- `vpc.tf`: VPC, 1 public subnet, IGW, route table
- `ec2.tf`: t3.small (Amazon Linux 2023), Security Group allowing only 80/443 (no port 22), `user_data.sh` installs k3s
- `iam.tf`: instance role with **least privilege**: `s3:GetObject/PutObject/ListBucket` on this bucket only, ECR read-only, `AmazonSSMManagedInstanceCore`
- `s3.tf`: private bucket, Block Public Access, SSE encryption, versioning, lifecycle rule (delete after 30 days)
- `ecr.tf`: repository with scan-on-push and a lifecycle policy (keep the last 10 images)
- `budget.tf`: the budget alert as code
- `outputs.tf`: public IP, bucket name, ECR URL
- Run `terraform fmt`, `validate`, `plan`, `apply`

**Block 3: Kubernetes (~3h)**
- Connect with `aws ssm start-session`, check `kubectl get nodes`
- ECR login on k3s: a small script plus a systemd timer on the node that refreshes the `imagePullSecret` every 6h (ECR tokens expire after 12h, which is a common real-world gotcha)
- Manifests in `k8s/base`:
  - `Deployment`: 2 replicas, `resources.requests/limits`, `livenessProbe`/`readinessProbe`, `securityContext` (runAsNonRoot, readOnlyRootFilesystem), config via env from a `ConfigMap`
  - `Service` (ClusterIP), `Ingress` (Traefik, which ships with k3s)
  - `HPA` scaling on CPU (k3s already includes metrics-server)
- Deploy with `kubectl apply -k k8s/overlays/prod`, then test an upload with `curl` against the EC2 public IP

✅ **End of Saturday:** the API works on AWS, is deployed by manifests, and writes to S3.

### Sunday: level up (medium difficulty)
**Block 4: CI/CD with GitHub Actions (~2–3h)**
- Jobs: `ruff` lint + `pytest` → `docker build` → **Trivy** scan (fail on CRITICAL) → push to ECR
- AWS authentication via **GitHub OIDC** (an IAM role in Terraform, no secret keys in GitHub)
- The final step updates the image tag in `k8s/overlays/prod/kustomization.yaml` with the commit SHA and commits it back

**Block 5: GitOps with Argo CD (~1.5h)**
- Install Argo CD with Helm and create `argocd/application.yaml` pointing to `k8s/overlays/prod` with auto-sync + self-heal
- Demo: push to main → CI → new tag → Argo CD deploys on its own. CI never needs access to the cluster.

**Block 6: Observability (~1.5h)**
- `helm install kube-prometheus-stack` (lower the resource settings so it fits on the t3.small)
- A `ServiceMonitor` for the app's `/metrics`
- A Grafana dashboard: requests/s, latency, pod CPU/memory. Take screenshots for the README

**Block 7: documentation and teardown (~1.5h)**
- README: what the project does, architecture diagram, stack, how to run it (`terraform apply` → …), screenshots (Argo CD green, Grafana, `kubectl get all`), **approximate cost**, "what I learned", "next steps"
- Record a short GIF/video of the demo
- **`terraform destroy`** at the end (keep the code and screenshots; the portfolio is the repo, not a running server)

## Optional extras (if you have time left)
- Terraform modules + `tflint`/`checkov` in CI
- HTTPS with cert-manager + Let's Encrypt (needs a domain, via Route 53 or a free one like DuckDNS)
- Replace the refresh script with an **ECR credential provider** for the kubelet
- A `NetworkPolicy` and a `PodDisruptionBudget`
- Migrate to **EKS** with the same manifests (shows that portability works)

## Estimated cost
- t3.small ≈ US$0.02/h → ~US$1 for 48h; S3/ECR are nearly free at this size; the Budget alert protects you
- A new AWS account comes with Free Tier credits, which can bring the cost close to zero
- **Always run `terraform destroy` when you finish**

## Verification (checklist)
1. `pytest` passes locally; `docker run` + `curl localhost:8000/healthz` returns 200
2. `terraform plan` shows no errors; after `apply`, `aws ssm start-session` connects to the instance
3. `kubectl get pods -n clouddrop` shows 2/2 Running; `curl -F file=@test.txt http://<IP>/files` → the object appears in `aws s3 ls s3://<bucket>`
4. `GET /files/test.txt` returns a pre-signed URL that downloads the file
5. Load test (`hey`/`k6`) → `kubectl get hpa` shows the HPA scaling
6. Push to main → the Actions pipeline is green → Argo CD shows `Synced/Healthy` with the new tag
7. Grafana shows the app's metrics
8. `terraform destroy` removes everything; the AWS Billing page shows ~US$0 in ongoing cost

## What goes on the resume
"Deployed a containerized API on AWS (EC2, S3, ECR, IAM, VPC) provisioned with Terraform, running on Kubernetes (k3s) with Kustomize manifests, a CI/CD pipeline in GitHub Actions (OIDC, Trivy), GitOps with Argo CD, and monitoring with Prometheus/Grafana."
