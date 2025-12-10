# 🧾 NOTES.md – Governance and Implementation Rationale

This document provides context and rationale for the Terraform infrastructure and CI/CD pipeline defined in this repository. It supports onboarding, audit readiness, and stakeholder alignment.

---

## 📂 File Breakdown

### `main.tf` – Core Infrastructure

Defines the full S3 architecture across three AWS regions:

- **Buckets**:
  - Terraform state (`s3_tf`)
  - Logging (`s3_tf_logs`)
  - Replication targets (`replica`, `replica_logs`, `s3_tf_logs_replica`, `replica_logs_target`)
- **Features**:
  - Versioning for state traceability
  - KMS encryption using a shared, customer-managed key
  - Lifecycle rules to control cost and enforce retention
  - Logging for access traceability
  - Notification stubs for future event triggers
- **Public Access Block**:
  - Enforced using `aws_s3_bucket_public_access_block` with `for_each`
- **Naming**:
  - Bucket names are dynamically generated using `local.name_prefix` and `local.account_id`
  - `name_prefix` is derived from the caller identity ARN, normalized for DNS compliance

### `iam.tf` – IAM Role for Replication

Defines the IAM role and policy required for S3 replication:

- **Role**: `replication_role`
  - Trusted by `s3.amazonaws.com`
- **Policy**:
  - Grants source bucket read and version access
  - Grants destination bucket write and tag replication
- **Security**:
  - Scope is tightly limited to the specific buckets provisioned in `main.tf`

### `.github/workflows/terraform-ci.yml` – GitHub Actions CI

Automates validation and security checks on pull requests:

- **Steps**:
  - `terraform fmt` (run + check): ensures consistent formatting
  - `terraform init` and `validate`: validates syntax and provider setup
  - `tflint`: enforces Terraform best practices
  - `checkov`: scans for security and compliance violations
  - `terraform plan`: previews infrastructure changes
- **AWS Credentials**:
  - Injected via GitHub Secrets
- **Why `fmt` is run twice**:
  - First run auto-corrects formatting
  - Second run (`-check`) enforces formatting in CI

---

## 🔐 Design Rationale

| Feature                        | Rationale                                                                 |
|-------------------------------|---------------------------------------------------------------------------|
| **KMS Encryption**            | Ensures data-at-rest protection with key rotation and scoped access       |
| **Public Access Block**       | Prevents accidental exposure of sensitive infrastructure state            |
| **Versioning**                | Enables rollback and audit of Terraform state changes                     |
| **Lifecycle Rules**           | Controls storage cost and enforces data retention policies                |
| **Cross-Region Replication**  | Provides disaster recovery and regional resilience                        |
| **Tagging**                   | Supports cost attribution, ownership tracking, and audit clarity          |
| **force_destroy = true**      | Enables clean teardown in dev/CI environments without manual intervention |
| **depends_on usage**          | Guarantees encryption and versioning are applied before replication       |
| **Notification Blocks**       | Placeholder for future event-driven workflows (e.g., SNS, Lambda triggers)|

---

## 🧭 Operational Notes

- All buckets are encrypted, versioned, and lifecycle-managed.
- Replication is configured for:
  - Terraform state → replica
  - Logs → replica logs
  - Replica logs → third-region archive
- CI/CD ensures every commit is validated, linted, and security-scanned before merge.

---
