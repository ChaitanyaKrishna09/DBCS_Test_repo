# DBCS_DB_Patching

Reusable Ansible automation for Oracle OCI Database Cloud Service patching
workflows.

## Available DB patch discovery

`patch_discovery_main.yaml` performs read-only discovery for DBA review. It:

- resolves DB Systems from OCI dynamic inventory;
- de-duplicates RAC nodes that refer to the same DB System;
- discovers every DB Home and its databases;
- retrieves applicable DB Home patches;
- retrieves PRECHECK and APPLY history; and
- writes machine-readable JSON and human-readable HTML reports.

The workflow does not submit PRECHECK or APPLY actions.

Required inventory host variables:

- `compartment_id`
- `db_system_id`
- `region`, unless `region1` is supplied

Required runtime variable:

- `group1`: the non-empty inventory group to discover

Optional runtime variables:

- `region1`: fallback OCI region
- `patch_discovery_report_dir`: controller-side report directory
- `patch_discovery_include_history`: include patch history, default `true`

Example:

```text
ansible-playbook -i <oci_inventory> patch_discovery_main.yaml \
  -e group1=<target_group> \
  -e region1=<oci_region>
```

## Capture and persist approved DB patch version

`patch_approval_main.yaml` records a DBA's patch decision and persists it
as the authoritative input for later precheck and apply workflows. It:

- validates the approval request against a `patch_discovery_main.yaml`
  JSON report, so only discovered DB Homes and patch candidates can be
  approved;
- rejects an approval when the patch OCID, version, or DB Home is not
  present in the discovery report;
- automatically supersedes any previously active approval for the same
  DB Home before persisting a new one;
- persists an immutable history record and a "latest" pointer file per
  DB Home; and
- writes a human-readable HTML approval summary.

The workflow does not call OCI and does not run precheck or apply
actions; it only captures and persists the approval decision.

Required runtime variables:

- `db_home_id`: DB Home OCID being approved or rejected
- `patch_id`: patch OCID being approved or rejected
- `patch_version`: patch version being approved or rejected
- `discovery_report`: path to a JSON report produced by
  `patch_discovery_main.yaml`
- `approver`: identity of the DBA/change approver
- `change_ticket`: change or request ticket reference

Optional runtime variables:

- `decision`: `APPROVED` (default) or `REJECTED`
- `environment`: environment label, for example `PROD` or `TEST`
- `maintenance_window_start` / `maintenance_window_end`
- `comments`: free-text approval notes
- `expiry_hours`: approval validity window in hours, default `72`
- `patch_approval_dir`: controller-side approval storage directory

Persisted output:

- `approvals/history/<approval_id>.json`: immutable audit record
- `approvals/history/<approval_id>_superseded.json`: prior approval,
  written automatically when a new approval replaces it
- `approvals/history/<approval_id>_summary.html`: human-readable
  summary
- `approvals/latest/<db_home_id>.json`: current active approval,
  present only while `approval_status` is `APPROVED`

Example:

```text
ansible-playbook patch_approval_main.yaml \
  -e db_home_id=<db_home_ocid> \
  -e patch_id=<patch_ocid> \
  -e patch_version=<patch_version> \
  -e discovery_report=<path_to_discovery_json> \
  -e approver="<approver_name>" \
  -e change_ticket=<change_ticket> \
  -e decision=APPROVED
```

## Apply the approved DB patch and validate

`patch_apply_main.yaml` applies the DB Home patch that was approved by
`patch_approval_main.yaml`, then validates the result. It runs five
plays in order:

1. **Precheck (localhost)** - reloads the active approval, re-verifies
   it has not expired or drifted from the current DB Home state and
   available patch list in OCI, then submits an OCI PRECHECK (or
   reuses a prior successful one) and polls until it reaches a
   terminal state.
2. **Pre-apply gate (DB hosts)** - reuses the existing
   `backup_validation` role to confirm a recent, valid backup exists,
   then captures a pre-apply invalid object baseline (SYS/SYSTEM
   owners) using the existing `Invalid_count` role and writes it back
   to the controller.
3. **Apply (localhost)** - reloads the approval and the persisted
   precheck result, submits an OCI APPLY (or reuses a prior successful
   one), and polls until it reaches a terminal state.
4. **Post-apply validation (DB hosts)** - verifies the OPatch inventory
   and `DBA_REGISTRY_SQLPATCH` reflect the applied patch version, then
   compares the invalid object count against the pre-apply baseline,
   automatically running `utlrp.sql` (via the existing `Invalid_count`
   role) and re-checking when the count increased. Each host's result
   is written back to the controller and the play fails on that host
   if any check does not pass.
5. **Report (localhost)** - consolidates the approval, precheck,
   apply, and every host's validation result into JSON and HTML
   reports and publishes summary stats.

All OCI submissions are idempotent: a stage that already has a
successful PRECHECK or APPLY history entry for the exact patch is
skipped and the existing result is reused, so the playbook is safe to
re-run after a partial failure.

Required runtime variables:

- `db_home_id`: DB Home OCID to patch (must have an active approval
  from `patch_approval_main.yaml`)
- `patch_version`: approved patch version, used for post-apply
  validation
- `instance`: config file name (without extension) under `config/`
  for the target database host(s), for example `DB0609`

Required inventory/host variables (via `config/<instance>.yaml` or
extra vars):

- `db_user`, `ENV_HOME`, `ENV_FILE`, `oracle_home`, `db_name`

Optional runtime variables:

- `patch_apply_target_group`: inventory group/host pattern for the
  database host plays, default `all`
- `patch_apply_dir`: controller-side working directory for
  precheck/apply/validation/report artifacts, default `apply/`
- `patch_approval_dir`: controller-side approval directory used to
  load the active approval, default `approvals/`

Persisted output (under `patch_apply_dir`):

- `<db_home_id>_precheck.json`, `<db_home_id>_apply.json`: OCI
  operation results
- `<host>_pre_apply_invalid_baseline.json`: pre-apply invalid object
  baseline per database host
- `<host>_post_apply_validation.json`: post-apply validation result
  per database host
- `report/<db_home_id>_patch_apply_report.json` and
  `report/<db_home_id>_patch_apply_report.html`: consolidated report

Example:

```text
ansible-playbook -i <oci_inventory>,<db_host_inventory> \
  patch_apply_main.yaml \
  -e db_home_id=<db_home_ocid> \
  -e patch_version=<patch_version> \
  -e instance=DB0609 \
  -e patch_apply_target_group=<db_host_group>
```
