# Terraform & Architecture ToDo List

## Critical Infrastructure Decisions
- [ ] **CNI Conflict Resolution**:
    - Current State: Cilium is defined in BOTH `terraform/platform/management/cilium.tf` AND `kubernetes/management/manifest/values.yaml` (Argo CD).
    - Issue: "Split Brain" management. Terraform bootstraps it, Argo CD tries to manage it.
    - Decision Needed:
        - Option A: Terraform owns "Base Layer" (CNI, CSR, Argo). Remove Cilium from Argo CD App of Apps.
        - Option B: Argo CD owns everything. Remove Cilium from Terraform. Use a "Bootstrap Script" to install CNI once, then let Argo adopt it.
    - *Impact*: Bootstrapping dependencies (Argo needs Network -> Network needs CNI).

## Codebase Improvements
- [ ] **Fix Backend Syntax**:
    - `terraform/clusters/main/backend.tf` uses variables (`var.s3_bucket`) which is invalid HCL.
    - Action: Switch to empty backend blocks (`backend "s3" {}`) and rely on `.tfbackend` files or CLI flags.
- [ ] **Infrastructure as Code Gap**:
    - The **Firewall Node** (OPNsense, MinIO, Vault) is manual.
    - Action: Create `terraform/infrastructure/firewall` to import/manage this node to remove the "Chicken-and-Egg" risk for State/Secrets.
- [ ] **Provider Consistency**:
    - Standardize provider versions (Talos, Proxmox) across all modules (`clusters/`, `infrastructure/`).
- [ ] **Structure Refactor**:
    - Clarify `terraform/platform/` roles. Separation between "Management Cluster Platform" and "Main Cluster Platform" is fuzzy.

## Security
- [ ] **Secret Management**:
    - Audit for any plaintext secrets in `.tfvars` (though most seem to be vars).
    - Ensure `.env` is never committed.
