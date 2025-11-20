# 📘 Terraform S3 Replication Infrastructure – README

This repository provisions a secure, multi-region S3 bucket architecture using Terraform, with automated CI validation via GitHub Actions. It supports Terraform state management, logging, cross-region replication, encryption, lifecycle policies, and public access blocking.

---

## 🧱 Infrastructure Overview

| Component              | Description                                                                 |
|------------------------|-----------------------------------------------------------------------------|
| **Terraform Backend**  | Stores state in `sctp-ce11-tfstate` under `shilpa/s3-tfstate/terraform.tfstate` |
| **Providers**          | `us-east-1` (primary), `us-east-2` (replica), `us-west-1` (replica logs target) |
| **KMS Key**            | Customer-managed key with rotation, used for all S3 encryption              |
| **IAM Role**           | `replication_role` with scoped permissions for S3 replication               |
| **Public Access Block**| Enforced via `aws_s3_bucket_public_access_block` using `for_each`           |
| **Tagging**            | All buckets include `Owner`, `Environment`, and `Purpose` for traceability  |

---

## 📦 Bucket Roles and Regional Flow

| Full Bucket Name                                      | AWS Region   | Function                                      | Replicates To                                      | Strategic Value                                                                 |
|-------------------------------------------------------|--------------|-----------------------------------------------|----------------------------------------------------|----------------------------------------------------------------------------------|
| `sctpce11-s3-tf-bkt-<account_id>`                     | `us-east-1`  | Primary Terraform state bucket                | `sctpce11-s3-tf-replica-<account_id>`              | Versioned, encrypted state with cross-region recovery                           |
| `sctpce11-s3-tf-logs-<account_id>`                    | `us-east-1`  | Access logs for Terraform state bucket        | `sctpce11-s3-tf-logs-replica-<account_id>`         | Preserves audit logs even if primary region fails                                |
| `sctpce11-s3-tf-replica-<account_id>`                 | `us-east-2`  | Cross-region replica of Terraform state       | —                                                  | Enables disaster recovery and operational continuity                            |
| `sctpce11-s3-tf-logs-replica-<account_id>`            | `us-east-2`  | Replica of access logs from primary log bucket| —                                                  | Ensures logs are retained across regions                                        |
| `sctpce11-s3-replica-logs-<account_id>`               | `us-east-2`  | Logs access to the replica state bucket       | `sctpce11-s3-replica-logs-target-<account_id>`     | Tracks access to replica; logs are further replicated for compliance            |
| `sctpce11-s3-replica-logs-target-<account_id>`        | `us-west-1`  | Final replica of replica logs                 | —                                                  | Third-region audit trail for long-term retention and regulatory resilience      |

> Replace `<account_id>` with your actual AWS account ID. The prefix `sctpce11` is derived from `local.name_prefix`.

---

## 🔁 Replication Configuration Summary

| Source Bucket Name                                   | Target Bucket Name                                 | Replication Rule ID         | Purpose of Replication                                      |
|------------------------------------------------------|----------------------------------------------------|------------------------------|--------------------------------------------------------------|
| `sctpce11-s3-tf-bkt-<account_id>`                    | `sctpce11-s3-tf-replica-<account_id>`              | `replicate`                  | Replicates Terraform state for disaster recovery             |
| `sctpce11-s3-tf-logs-<account_id>`                   | `sctpce11-s3-tf-logs-replica-<account_id>`         | `replicate-logs`             | Replicates access logs for audit resilience                  |
| `sctpce11-s3-replica-logs-<account_id>`              | `sctpce11-s3-replica-logs-target-<account_id>`     | `replicate-replica-logs`     | Replicates replica logs to third region for compliance       |

---

## 🔐 Security and Compliance

- **Encryption**: All buckets use a shared KMS key with rotation enabled
- **Public Access Block**: Enforced using `aws_s3_bucket_public_access_block` with `for_each` over all buckets
- **Lifecycle Rules**:
  - State versions expire after 30 days
  - Logs expire after 90–180 days
  - Multipart uploads aborted after 7 days
- **Tagging**: Every bucket includes `Owner`, `Environment`, and `Purpose` for audit and cost attribution
- **force_destroy = true**: Enables clean teardown in CI/CD and dev environments
- **depends_on usage**: Ensures encryption and versioning are applied before replication begins
- **aws_s3_bucket_notification**: Defined as a placeholder for future event triggers or audit hooks

---

## ⚙️ GitHub Actions CI Pipeline

Located in `terraform-ci.txt`, this workflow runs on pull requests to `main` and includes:

| Step                     | Purpose                                         |
|--------------------------|-------------------------------------------------|
| `terraform fmt`          | Auto-format and check style (run + check)       |
| `terraform init`         | Initialize backend and providers                |
| `terraform validate`     | Validate syntax and configuration               |
| `tflint`                 | Lint Terraform code for best practices          |
| `checkov`                | Run security and compliance checks              |
| `terraform plan`         | Preview infrastructure changes                  |

> Note: `terraform fmt` is run twice—once to auto-correct, once to enforce formatting in CI.

---

## 📦 Scenario: Terraform State and Log Replication for Resilience and Audit

### Objective:
Securely store Terraform state and logs, ensure cross-region recovery, and maintain audit compliance.

### Example Flow:

1. **Terraform Apply in `us-east-1`**
   - State saved to `sctpce11-s3-tf-bkt-<account_id>`
   - Logs written to `sctpce11-s3-tf-logs-<account_id>`

2. **Replication to `us-east-2`**
   - State replicated to `sctpce11-s3-tf-replica-<account_id>`
   - Logs replicated to `sctpce11-s3-tf-logs-replica-<account_id>`

3. **Replica Access Logging**
   - Access to replica logged in `sctpce11-s3-replica-logs-<account_id>`
   - Logs replicated to `sctpce11-s3-replica-logs-target-<account_id>` in `us-west-1`

---

## ✅ Onboarding Checklist

- [ ] Set AWS credentials in GitHub Secrets
- [ ] Confirm backend bucket `sctp-ce11-tfstate` exists
- [ ] Run `terraform init` locally before first apply
- [ ] Review `NOTES.md` for governance and audit rationale
- [ ] Export README and NOTES.md to PDF for executive review
