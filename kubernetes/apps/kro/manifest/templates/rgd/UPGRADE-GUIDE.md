# YKApplication Version Upgrade Guide

This guide explains how to upgrade your YKApplication instances from one version to another without destroying existing resources.

## Table of Contents
- [Understanding Version Conflicts](#understanding-version-conflicts)
- [Upgrade Strategy Overview](#upgrade-strategy-overview)
- [Method 1: In-Place Upgrade (Recommended)](#method-1-in-place-upgrade-recommended)
- [Method 2: Blue-Green Migration](#method-2-blue-green-migration)
- [Method 3: Using Different API Groups](#method-3-using-different-api-groups)
- [Rollback Procedures](#rollback-procedures)
- [Version-Specific Upgrade Paths](#version-specific-upgrade-paths)

---

## Understanding Version Conflicts

### The CRD Ownership Problem

When you create a ResourceGraphDefinition (RGD), KRO automatically generates a Custom Resource Definition (CRD) based on your schema. The CRD is "owned" by that specific RGD.

**Example:**
- RGD: `yk-application-alpha-v2`
- Generates CRD: `ykapplications.yuriy-lab.cloud` (API version: v1alpha2)

If you try to apply `yk-application-alpha-v3` with the same group and kind, you'll get an error:
```
failed to update CRD ykapplications.yuriy-lab.cloud:
CRD is owned by another ResourceGraphDefinition yk-application-alpha-v2
```

### Why This Happens
- KRO tracks CRD ownership using OwnerReferences
- Only one RGD can own a specific CRD at a time
- This prevents conflicting definitions

---

## Upgrade Strategy Overview

### Key Principles
1. **Never delete running instances before testing the new version**
2. **Always backup your instance manifests**
3. **Test new versions in a separate namespace first**
4. **Understand what changes between versions**

### Change Impact Levels

| Change Type | Impact | Strategy |
|-------------|--------|----------|
| Schema field addition (optional) | Low | In-place upgrade |
| Schema field addition (required) | Medium | Update instances, then upgrade |
| Schema field removal | High | Remove field from instances first |
| Field type change | High | Blue-green migration |
| Breaking CEL changes | Critical | Blue-green migration |

---

## Method 1: In-Place Upgrade (Recommended)

This method updates the RGD in place, allowing existing instances to continue running.

### When to Use
- Adding optional fields
- Fixing bugs in CEL expressions
- Improving existing functionality without breaking changes

### Steps

#### 1. Backup Current State
```bash
# Backup the current RGD
kubectl get rgd yk-application-alpha-v2 -o yaml > rgd-v2-backup.yaml

# Backup all instances
kubectl get ykapplication.yuriy-lab.cloud -A -o yaml > instances-backup.yaml
```

#### 2. Review Changes
Compare the old and new RGD files:
```bash
diff yk_applcation_alpha_v2.yaml yk_applcation_alpha_v3.yaml
```

#### 3. Delete the Old RGD (CRD stays)
```bash
# Delete the old RGD but keep instances running
kubectl delete rgd yk-application-alpha-v2

# Verify instances are still running
kubectl get ykapplication.yuriy-lab.cloud -A
```

**Important:** When you delete an RGD:
- The CRD remains in the cluster
- All existing instances (YKApplication resources) continue to exist
- The resources created by those instances (Deployments, Services, etc.) keep running
- The controller stops managing updates to instances

#### 4. Apply the New RGD
```bash
kubectl apply -f yk_applcation_alpha_v3.yaml
```

#### 5. Update Instances Gradually
Update your instance manifests one at a time to use new features:

```yaml
# Old instance (v2)
apiVersion: yuriy-lab.cloud/v1alpha2
kind: YKApplication
metadata:
  name: my-app
spec:
  name: my-app
  namespace: production
  image: nginx:latest
  # ... rest of spec

---

# Updated instance (v3)
apiVersion: yuriy-lab.cloud/v1alpha3  # Changed version
kind: YKApplication
metadata:
  name: my-app
spec:
  name: my-app
  namespace: production
  image: nginx:latest
  env:                      # New feature in v3
    LOG_LEVEL: "info"
  # ... rest of spec
```

Apply the updated instance:
```bash
kubectl apply -f my-app-updated.yaml
```

#### 6. Verify
```bash
# Check RGD status
kubectl get rgd yk-application-alpha-v3 -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# Check your application is still running
kubectl get deployment my-app -n production
kubectl get pods -n production -l yk-app=my-app

# Check instance status
kubectl get ykapplication.yuriy-lab.cloud my-app -n production -o yaml
```

---

## Method 2: Blue-Green Migration

This method creates a parallel environment for testing before switching over.

### When to Use
- Breaking changes in schema
- Major version upgrades
- Production-critical applications
- When you need easy rollback

### Steps

#### 1. Prepare Test Namespace
```bash
kubectl create namespace test-upgrade
```

#### 2. Apply New RGD with Different Name
Edit the RGD to use a temporary name:
```yaml
metadata:
  name: yk-application-alpha-v3-test  # Temporary name
spec:
  schema:
    apiVersion: v1alpha3-test          # Temporary API version
    kind: YKApplication
    group: yuriy-lab.cloud
```

Apply it:
```bash
kubectl apply -f yk_applcation_alpha_v3_test.yaml
```

#### 3. Deploy Test Instances
Create test instances in the test namespace:
```yaml
apiVersion: yuriy-lab.cloud/v1alpha3-test
kind: YKApplication
metadata:
  name: my-app-test
  namespace: test-upgrade
spec:
  # Same spec as production
  name: my-app-test
  namespace: test-upgrade
  # ...
```

#### 4. Validate Test Environment
```bash
# Check all resources created correctly
kubectl get all -n test-upgrade

# Test functionality
kubectl port-forward -n test-upgrade svc/my-app-test 8080:80

# Check logs
kubectl logs -n test-upgrade -l yk-app=my-app-test
```

#### 5. Switch to Production

Once validated, perform the in-place upgrade (Method 1) in production:

```bash
# Delete old RGD
kubectl delete rgd yk-application-alpha-v2

# Apply new RGD (with production name)
kubectl apply -f yk_applcation_alpha_v3.yaml

# Update production instances
kubectl apply -f my-app-production.yaml
```

#### 6. Cleanup Test Environment
```bash
kubectl delete rgd yk-application-alpha-v3-test
kubectl delete namespace test-upgrade
```

---

## Method 3: Using Different API Groups

This method allows running multiple versions side-by-side indefinitely.

### When to Use
- Long-term coexistence of versions
- Gradual migration over weeks/months
- Different teams using different versions

### Steps

#### 1. Create RGD with Different Group
Edit the new RGD:
```yaml
metadata:
  name: yk-application-alpha-v3
spec:
  schema:
    apiVersion: v1alpha3
    kind: YKApplication
    group: yuriy-lab-v3.cloud  # Different group name
```

#### 2. Apply Both RGDs
```bash
kubectl apply -f yk_applcation_alpha_v2.yaml
kubectl apply -f yk_applcation_alpha_v3.yaml
```

#### 3. Use Different API Groups in Instances

Old instances (v2):
```yaml
apiVersion: yuriy-lab.cloud/v1alpha2
kind: YKApplication
```

New instances (v3):
```yaml
apiVersion: yuriy-lab-v3.cloud/v1alpha3
kind: YKApplication
```

#### 4. Migrate Applications Gradually
Move applications from v2 to v3 at your own pace.

#### 5. Deprecate Old Version
Once all apps are migrated:
```bash
# Delete old RGD
kubectl delete rgd yk-application-alpha-v2

# Cleanup old instances
kubectl get ykapplication.yuriy-lab.cloud -A
kubectl delete ykapplication.yuriy-lab.cloud <name> -n <namespace>
```

---

## Rollback Procedures

### If Upgrade Fails Before Deleting Old RGD
Simply don't proceed - your old version is still active.

### If Upgrade Fails After Deleting Old RGD

#### Quick Rollback
```bash
# Reapply old RGD from backup
kubectl apply -f rgd-v2-backup.yaml

# Verify it's working
kubectl get rgd yk-application-alpha-v2 -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

### If Instances Are Broken

#### Restore from Backup
```bash
# Delete broken instances
kubectl delete ykapplication.yuriy-lab.cloud my-app -n production

# Reapply from backup
kubectl apply -f instances-backup.yaml
```

### If Resources Are Deleted

KRO manages the lifecycle of resources. If resources are accidentally deleted:

```bash
# The controller should recreate them automatically
# Force reconciliation by updating the instance
kubectl annotate ykapplication.yuriy-lab.cloud my-app -n production \
  force-sync="$(date +%s)" --overwrite

# Or delete and recreate the instance
kubectl delete ykapplication.yuriy-lab.cloud my-app -n production
kubectl apply -f my-app.yaml
```

---

## Version-Specific Upgrade Paths

### Upgrading from v1 to v2

**Changes:**
- Improved volume configuration structure
- Added forEach logic for PVCs
- No required field changes

**Steps:**
1. Use Method 1 (In-Place Upgrade)
2. Update volume syntax if using volumes:

v1 style:
```yaml
storage:
  enabled: true
  name: "data"
  size: "1Gi"
```

v2 style:
```yaml
persistentVolumeClaims:
  data:
    size: "1Gi"
    storageClass: "standard"
    accessMode: "ReadWriteOnce"
```

### Upgrading from v2 to v3

**Changes:**
- Added `env` field (optional map)
- Removed `envFrom` support (limitation)
- No breaking changes

**Steps:**
1. Use Method 1 (In-Place Upgrade)
2. Optionally add environment variables to instances:

```yaml
spec:
  # ... existing fields
  env:
    LOG_LEVEL: "info"
    APP_NAME: "my-app"
```

3. If you were using external ConfigMaps/Secrets, they still work - just not managed by the RGD

---

## Best Practices

### Before Upgrading

1. **Read the CHANGELOG/TODO**
   - Understand what changed
   - Check for breaking changes

2. **Test in Non-Production**
   - Use the `playground` namespace
   - Validate all features work

3. **Backup Everything**
   ```bash
   kubectl get rgd -o yaml > all-rgds-backup.yaml
   kubectl get ykapplication.yuriy-lab.cloud -A -o yaml > all-instances-backup.yaml
   ```

4. **Document Your Plan**
   - Which method you'll use
   - Order of instance migrations
   - Rollback triggers

### During Upgrade

1. **One at a Time**
   - Upgrade one application at a time
   - Verify each before proceeding

2. **Monitor Actively**
   ```bash
   # Watch RGD status
   kubectl get rgd -w

   # Watch pods
   kubectl get pods -A -l yk-app=<app-name> -w

   # Check KRO controller logs
   kubectl logs -n kro-system -l app=kro-controller -f
   ```

3. **Keep Communication Open**
   - Notify team members
   - Have rollback plan ready

### After Upgrade

1. **Verify All Instances**
   ```bash
   kubectl get ykapplication.yuriy-lab.cloud -A
   ```

2. **Check Resource Status**
   ```bash
   kubectl get deployments,statefulsets,services,pvcs -A -l yk-app
   ```

3. **Update Documentation**
   - Update instance examples
   - Document any issues encountered

4. **Keep Backups for 30 Days**
   - In case issues surface later

---

## Troubleshooting

### Issue: "CRD is owned by another ResourceGraphDefinition"

**Solution:** Use Method 1 - delete the old RGD first.

### Issue: Instances not updating after RGD upgrade

**Cause:** KRO controller may not have detected changes.

**Solution:**
```bash
# Force reconciliation
kubectl annotate ykapplication.yuriy-lab.cloud <name> -n <namespace> \
  force-sync="$(date +%s)" --overwrite
```

### Issue: New fields not appearing in CRD

**Cause:** CRD wasn't updated properly.

**Solution:**
```bash
# Check CRD
kubectl get crd ykapplications.yuriy-lab.cloud -o yaml

# If needed, delete and let RGD recreate
kubectl delete crd ykapplications.yuriy-lab.cloud
kubectl apply -f yk_applcation_alpha_vX.yaml
```

### Issue: Resources deleted during upgrade

**Cause:** Possible owner reference issue.

**Solution:**
```bash
# Recreate instance to trigger resource creation
kubectl delete ykapplication.yuriy-lab.cloud <name> -n <namespace>
kubectl apply -f <instance-file>.yaml
```

---

## Emergency Procedures

### Complete Disaster Recovery

If everything is broken:

```bash
# 1. Delete all RGDs
kubectl delete rgd --all

# 2. Delete the CRD (this will delete all instances!)
kubectl delete crd ykapplications.yuriy-lab.cloud

# 3. Restore from backup
kubectl apply -f rgd-backup.yaml
kubectl apply -f instances-backup.yaml
```

**Warning:** This will cause downtime for all applications using YKApplication!

---

## Questions & Support

If you encounter issues during upgrade:

1. Check the KRO controller logs:
   ```bash
   kubectl logs -n kro-system -l app=kro-controller --tail=100
   ```

2. Check RGD status:
   ```bash
   kubectl get rgd <name> -o yaml
   ```

3. Verify the CRD schema:
   ```bash
   kubectl get crd ykapplications.yuriy-lab.cloud -o jsonpath='{.spec.versions[*].name}'
   ```

4. Review the TODO.md for known limitations

---

## Summary Checklist

- [ ] Read version changelog/differences
- [ ] Backup current RGD and instances
- [ ] Choose upgrade method
- [ ] Test in non-production namespace
- [ ] Perform upgrade
- [ ] Verify all applications running
- [ ] Update instance manifests
- [ ] Monitor for 24-48 hours
- [ ] Document any issues
- [ ] Clean up old backups after 30 days
