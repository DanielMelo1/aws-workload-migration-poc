# AWS Workload Migration — Proof of Concept

Simulation of a lift-and-shift migration: a legacy application running
directly on a server is containerized and moved to AWS ECS Fargate.

The migration is observable — the application reports which environment
it is running in, producing verifiable before/after evidence.

> **Scope.** This is a proof of concept. The environment was provisioned,
> exercised end to end and destroyed. Architectural choices reflect that
> scope — components that do not change what is being demonstrated were
> deliberately left out and are documented under Accepted trade-offs.

## Migration path

EC2 source (legacy runtime) -> EC2 target (containerize) -> Amazon ECR (image 1.0.0) -> ECS Fargate (managed runtime)

Environment reported changes from `on-premises` to `aws-cloud`.

## What was migrated

A Python Flask service exposing two endpoints: a root route reporting
runtime metadata and a health endpoint used by ECS for container health
checks.

| | Before | After |
|---|---|---|
| Runtime | Process on the OS | Container on Fargate |
| Dependencies | Installed on the server | Packaged in the image |
| Recovery | Manual | ECS replaces failed tasks |
| Logs | Local file | CloudWatch Logs |
| Reproducibility | Manual setup | Versioned image |

## Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform 1.10, S3 remote state with native locking |
| Compute | EC2 (Amazon Linux 2023), ECS Fargate |
| Registry | Amazon ECR with immutable tags and scan on push |
| CI | GitHub Actions — Terraform validate, TFLint, Checkov, Trivy |
| Access | SSM Session Manager — no SSH keys, no inbound port 22 |

## Security decisions

- Instance access through Session Manager. No key pairs exist and port 22
  is closed on the security group.
- ECR authentication through the instance IAM role. No credentials are
  written to disk during the migration.
- IMDSv2 enforced on both instances, mitigating SSRF-based credential theft.
- Encrypted EBS root volumes and KMS-encrypted ECR repository.
- Container runs as a non-root user.
- Security group egress restricted to HTTPS and HTTP.
- Trivy configured with ignore-unfixed, keeping the gate active for any
  CVE with a vendor patch while avoiding static exception lists that
  silently expire.

## Accepted trade-offs

Two Checkov findings are deliberately accepted and documented in
infra/.checkov.yml:

**Public subnet with auto-assigned public IP.** Fargate requires outbound
connectivity to pull images from ECR. Private subnets would require either
a NAT Gateway or four VPC Interface Endpoints — additional components that
do not change what this proof of concept demonstrates, while adding surface
to provision and tear down. A production deployment would place tasks in
private subnets behind a NAT Gateway.

**VPC Flow Logs disabled.** Flow Logs support traffic analysis over time.
In an environment provisioned and destroyed within days there is no
analytical window to justify the ingestion. Production would enable them
with a defined retention policy.

## Evidence

| Step | Evidence |
|---|---|
| Infrastructure provisioned | [Resource inventory](docs/evidence/00-infrastructure-inventory.png) |
| Baseline on legacy host | [Application on EC2](docs/evidence/01-baseline-on-premises.png) |
| Containerization | [Image built](docs/evidence/02-container-image-built.png) |
| Publication | [Push to ECR](docs/evidence/03-image-pushed-to-ecr.png) · [ECR console](docs/evidence/04-ecr-repository-console.png) |
| Migrated runtime | [Application on Fargate](docs/evidence/05-workload-running-aws-cloud.png) · [ECS service](docs/evidence/06-ecs-service-running.png) |
| Quality gate | [Pipeline checks on pull request](docs/evidence/07-pull-request-checks-passed.png) |

The before and after responses show the same application reporting
different environments and hostnames, confirming the workload changed
infrastructure.

## Reproducing

See [RUNBOOK.md](docs/RUNBOOK.md).

## Repository layout

| Path | Contents |
|---|---|
| app/ | Application source and Dockerfile |
| infra/ | Terraform configuration |
| docs/ | Runbook and migration evidence |
| .github/ | CI pipeline |
