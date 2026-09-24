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
