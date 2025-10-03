# OpenTofu on OCI — Simple Web

This repository provisions an **OCI Ampere A1 (ARM)** virtual machine (`VM.Standard.A1.Flex`) running **Canonical Ubuntu 24.04 Minimal (aarch64)**
and bootstraps, via **cloud-init**, a production‑ready stack:
- **Nginx** serving a “Hello, OpenTofu!” page
- **Docker + Compose**
- **Observability**: **Prometheus**, **Alertmanager**, **Node Exporter**, **Loki**, **Promtail**, **Grafana**
- **Secure defaults**: only **22/tcp** and **80/tcp** are exposed, everything else uses SSH tunnels by default

> **Note**: If deploy in a region like `ap-batam-1`, image names and A1 capacity may vary. This repo automatically searches for Ubuntu 24.04 ARM images and lets you override with `image_ocid` if needed.

---

## Quick Start

1. **Create `infra/secrets.auto.tfvars`** (not committed):
   ```hcl
   tenancy_ocid       = "ocid1.tenancy.oc1..xxxxx" # change with your tenancy_ocid
   user_ocid          = "ocid1.user.oc1..xxxxx" # change with your user_ocid
   # Change with your fingerprint 
   # For get the fingerprint: Profile -> User Settings -> Token and Keys -> API Keys
   fingerprint        = "ab:cd:ef:..." 

   # Windows path -> use forward slashes or escape backslashes
   # e.g. private_key_path = "C:/Users/<you>/.oci/oci_api_key.pem"
   private_key_path   = "/<your_path>/oci_api_key.pem"

   region             = "ap-batam-1" # change with your region 
   compartment_ocid   = "ocid1.compartment.oc1..xxxxx" # change with your compartment_ocid

   # SSH PUBLIC key for VM login (content of id_ed25519.pub — single line)
   # For generate the public_key
   ```
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your_email@example.com"
   cat ~/.ssh/id_ed25519.pub
   ```
   ssh_authorized_key = "ssh-ed25519 AAAA... you@example.com" 

   # Optional: set Grafana admin
   grafana_admin_user     = "admin"
   grafana_admin_password = "ChangeMe123!"

   # Optional: force a specific OS image
   # image_ocid = "ocid1.image.oc1.ap-..."
   ```

2. **Flex shape config (A1.Flex)** — set OCPUs & memory (defaults recommended):
   ```hcl
   # in infra/variables.tf
   variable "a1_ocpus"      { 
      type = number
      default = 1 
    }
   variable "a1_memory_gbs" { 
      type = number
      default = 6 
    }

   # in infra/compute.tf (inside resource "oci_core_instance" "vm")
   shape_config {
     ocpus         = var.a1_ocpus
     memory_in_gbs = var.a1_memory_gbs
    }
   ```
   > If you switch to a non‑flex shape (e.g., `VM.Standard.E2.1.Micro`), remove the `shape_config` block.

3. **Initialize & apply**
   ```bash
   cd infra
   tofu init
   tofu plan
   tofu apply
   ```

4. **Outputs**
   - `public_ip` & `nginx_url` — visit the site
   - `grafana_tunnel_hint` — how to tunnel to Grafana
   - `prometheus_tunnel_hint`, `alertmanager_tunnel_hint` — tunnels for those UIs

5. **Access UIs (via SSH tunnels)**
   ```bash
   # Grafana
   ssh -L 3000:localhost:3000 ubuntu@PUBLIC_IP   # http://localhost:3000 (admin / your password)
   # Prometheus
   ssh -L 9090:localhost:9090 ubuntu@PUBLIC_IP   # http://localhost:9090
   # Alertmanager
   ssh -L 9093:localhost:9093 ubuntu@PUBLIC_IP   # http://localhost:9093
   ```

---

## Architecture

- **Compute**: `VM.Standard.A1.Flex` (Ampere A1, ARM; Always Free‑eligible, capacity varies by region)
- **OS**: Canonical **Ubuntu 24.04 Minimal** (aarch64)
- **Network**: VCN + public subnet + IGW + route table; **NSG** exposes only **22** and **80**
- **Cloud‑init** does first‑boot install and config:
  - Nginx (gzip, keepalive, basic tuning)
  - Docker Engine + Compose plugin
  - Observability in `/opt/observability` (Compose stack)
  - Kernel/network tuning: **BBR**, **FQ** qdisc, **TCP Fast Open**
- **Diagram**: `docs/diagram.mmd` (Mermaid)

---

## Image Selection & Override

The repo tries to find an Ubuntu 24.04 ARM image automatically:
- First tries **Canonical Ubuntu 24.04 Minimal** (ARM)
- Falls back to **Canonical Ubuntu 24.04** (ARM) if Minimal is unavailable
- You can **override** with `image_ocid` in `secrets.auto.tfvars`:
  ```hcl
  image_ocid = "ocid1.image.oc1.<region>...."
  ```
To discover images:
- Console → **Compute → Images** (filter “Canonical Ubuntu 24.04”, **aarch64/Arm**)
- or OCI CLI:
  ```bash
  oci compute image list --compartment-id <compartment_ocid> \
    --operating-system "Canonical Ubuntu" \
    --operating-system-version "24.04" \
    --shape "VM.Standard.A1.Flex" --all
  ```

---

## Observability

**Compose services** (ports mapped locally on the VM):
- **Grafana** (`3000`) — pre-provisioned datasources (Prometheus, Loki, Alertmanager) + dashboards
- **Prometheus** (`9090`) — scrapes itself & **node-exporter** (`9100`) via Compose network
- **Alertmanager** (`9093`) — route alerts (Slack/email examples below)
- **Loki** (`3100`) — rules (ruler) enabled; sends to Alertmanager
- **Promtail** — tails `/var/log/*.log`, `/var/log/nginx/*.log`, and Docker container logs
- **Node Exporter** (`9100`) — host metrics (mounted `--path.rootfs=/host`)

**Dashboards (Grafana):**
- **Node Exporter Quickview** (CPU, Mem, CPU time)
- **Alerts Overview** (firing alerts via Prometheus `ALERTS` metric)
- **Nginx Logs & Errors** (Loki logs + 5xx rate chart)

**Prometheus alert rules** (`observability/prometheus/rules/alerts.yml`):
- `InstanceDown` (any target down > 2m)
- `HighCPUUsage` (> 85% for 10m)
- `HighMemoryUsage` (> 90% for 10m)
- `LowDiskSpaceRoot` (< 15% for 15m)
- `HighLoad` (load1 per core > 1.5 for 10m)

**Loki ruler** (`observability/loki/rules/nginx-5xx.yml`):
- `NginxHigh5xxRate` — average 5xx/sec > 0.5 over 5m

> **Security default**: NSG does **not** expose 3000/9090/9093; use SSH tunnels. You may open NSG rules or place an **OCI Load Balancer** (HTTPS + IP allowlist) in front if you must expose them.

---

## Cloud‑init Template: `${…}` vs `$${…}`

`infra/cloudinit.yaml` is rendered by `templatefile()`. Any `${…}` will be interpolated by OpenTofu.
To pass a literal `${…}` (for Docker Compose runtime), write **`$${…}`** in the template.

- In the embedded compose, we use:
  ```yaml
  - GF_SECURITY_ADMIN_USER=$${GRAFANA_ADMIN_USER:-admin}
  - GF_SECURITY_ADMIN_PASSWORD=$${GRAFANA_ADMIN_PASSWORD:-admin123}
  ```
- In the `.env` we **want** Tofu to inject values, so we use:
  ```yaml
  GRAFANA_ADMIN_USER=${grafana_admin_user}
  GRAFANA_ADMIN_PASSWORD=${grafana_admin_password}
  ```

---

## GitHub Actions (CI/CD)

Workflow: `.github/workflows/ci-cd.yml`  
- **PR/push** → plan (artifact)
- **main** → apply (protected environment)

**Required Secrets:**
Add these GitHub Secrets in your repo settings:
- `OCI_TENANCY_OCID`, `OCI_USER_OCID`, `OCI_FINGERPRINT`, `OCI_REGION`, `OCI_COMPARTMENT_OCID`
- `OCI_PRIVATE_KEY_PEM` — **paste the entire PEM** of your *API private key*
- `SSH_PUBLIC_KEY` — contents of your `id_ed25519.pub` (single line)
- Optional: `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`

The workflow writes a temp `oci_api_key.pem` and `infra/secrets.auto.tfvars` at runtime. Nothing sensitive is committed.

---

## Windows Tips

- **Paths in HCL**: use forward slashes or escape backslashes:
  ```hcl
  private_key_path = "C:/Users/<you>/.oci/oci_api_key.pem"
  # or
  private_key_path = "C:\\Users\\<you>\\.oci\\oci_api_key.pem"
  ```
- **Generate SSH key** (PowerShell):
  ```powershell
  ssh-keygen -t ed25519 -C "you@example.com"
  Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
  ```

---

## Backup & Restore

- **Backup** configs and data:
  ```bash
  bash scripts/backup.sh
  ```
- **Restore** on a fresh VM:
  ```bash
  bash scripts/restore.sh /opt/backups/backup-<timestamp>.tgz
  ```
- Store archives in **OCI Object Storage**; remote state supported via `infra/backend.tf.example` (S3‑compat endpoint).

---

## Security & Networking

- Public exposure: **only 22/80** by default (NSG). Tunnels for everything else.
- Add TLS/HTTPS via **OCI Load Balancer** or terminate SSL in Nginx (not included by default).
- Kernel tuning: **BBR**, **FQ**, **TCP Fast Open**

---

## Troubleshooting

- **Invalid escape sequence `\\U`** in `secrets.auto.tfvars` -> use `C:/Users/...` or double backslashes.  
- **No Ubuntu image found** -> set `image_ocid` explicitly or check region/shape, try CLI to list images.  
- **A1 Flex “ShapeConfig: null”** -> you must add a `shape_config` with `ocpus` and `memory_in_gbs` (see Quick Start step 2).  
- **Cloud‑init template errors (`Extra characters after interpolation expression`)** -> ensure Docker Compose env refs use `$${...}`, not `${...}`.  
- **Capacity/quota** -> lower OCPUs/memory, try a different AD/region, or request a limit increase.  
- **Ports not reachable** -> NSG exposes only 22/80, use tunnels or add rules/LB intentionally. If the port 80 still cannot access from public, add iptables on instance 
```bash 
sudo iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save
```
- **Where are logs?**  
  - Cloud‑init: `/var/log/cloud-init-output.log`  
  - Docker Compose stack: `cd /opt/observability && docker compose ps|logs`

---
