# Network module

VPC + `/26` (or larger) subnet for Cloud Run **Direct VPC egress**, plus Private
Service Access (PSA) so Cloud SQL can use a private IP.

## Design choices

| Choice | Why |
|---|---|
| Subnet ≥ `/26` | Cloud Run Direct VPC egress requires at least 64 addresses. Shrinking breaks egress. |
| No Cloud NAT | Cloud Run uses `PRIVATE_RANGES_ONLY`: private traffic (Cloud SQL) stays on the VPC; public HTTPS (LLM APIs, GitHub) exits Cloud Run directly. Saves ~$35/mo. Do not "fix" by adding NAT. |
| No VPC firewall rules | Classic VPC firewall create needs `roles/compute.securityAdmin`. Not required for Direct VPC → private Cloud SQL. Omit to keep the deployer SA smaller. |
| `prevent_destroy` on PSA | Destroying the range/peering orphans Cloud SQL private IPs. |

## Inputs

See `variables.tf` (`project_id`, `region`, optional names/CIDRs).

## Outputs

- `network_id` / `network_self_link` / `network_name`
- `subnet_id` / `subnet_self_link` / `subnet_name`
- `psa_range_name`, `psa_connection_id` (pass `psa_connection_id` into `depends_on` for Cloud SQL)
