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
