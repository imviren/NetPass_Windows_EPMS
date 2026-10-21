# NetPass Windows Endpoint Management System (EPMS)
### Enterprise Windows Endpoint Control, Policy Enforcement, and Security Automation

[![Release](https://img.shields.io/badge/Release-v1.0.0-blue.svg)](https://github.com/imviren/NetPass_Windows_EPMS/releases/tag/v1.0.0)
[![Verification](https://img.shields.io/badge/Live_VM_Test-100%25_PASS_(20%2F20)-brightgreen.svg)](docs/VERIFICATION_REPORT.md)
[![Platform](https://img.shields.io/badge/Platform-Windows_Server_%7C_Windows_10%2F11-0078D6.svg)](docs/AGENT_DEPLOYMENT_GUIDE.md)
[![Architecture](https://img.shields.io/badge/Architecture-x64-orange.svg)]()
[![Security](https://img.shields.io/badge/Zero_Trust-mTLS_%2B_CA_Pinning-critical.svg)](docs/RESTRICTION_CATALOGUE.md)

NetPass Windows EPMS is a production-grade, domain-independent Windows workstation and server management platform. It combines real-time SignalR WebSocket bi-directional command dispatch, continuous 15-minute persistent drift enforcement, BitLocker key escrow, and automated disaster recovery into a unified, self-hosted deployment.

---

## Download Production Installers

| Component | Installer File | Format | Size | Version | Direct Download | SHA-256 Checksum |
|---|---|:---:|:---:|:---:|:---:|---|
| **Server Hub** | `EndpointHubServerSetup.exe` | InnoSetup | 66.46 MB | `1.0.0` | [**Download Server**](https://github.com/imviren/NetPass_Windows_EPMS/raw/main/installers/EndpointHubServerSetup.exe) | `009fad7769319c2a7f66ba50748213ce85bcae56e1c7798fc851643553b53983` |
| **Client Agent** | `EndpointHubAgent.msi` | WiX MSI | 26.36 MB | `1.0.0` | [**Download Agent**](https://github.com/imviren/NetPass_Windows_EPMS/raw/main/installers/EndpointHubAgent.msi) | `00750bd3113310c30b03cee99f222c49f0756da3553de79ff961bde70263c649` |

All binaries are pre-compiled, self-contained for `win-x64`, and do not require external runtime installations.

---

## Quick Verification & Installation

### 1. Verify Installer Integrity (PowerShell)
Before running the installers, verify the cryptographic integrity of the downloads:

```powershell
# Clone or download this repo and run the verification tool:
.\scripts\verify-checksums.ps1
```

Or verify individual files manually:
```cmd
certutil -hashfile installers\EndpointHubServerSetup.exe SHA256
certutil -hashfile installers\EndpointHubAgent.msi SHA256
```

### 2. Deploy Server Hub
Run the interactive setup wizard as Administrator:
```powershell
.\installers\EndpointHubServerSetup.exe
```
Or install silently in headless/automated environments:
```powershell
Start-Process ".\installers\EndpointHubServerSetup.exe" -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
```
Once installed, open `https://localhost` (or `https://<server-ip>`) to access the Web Portal.

### 3. Deploy Client Agents
Deploy the agent silently across target workstations:
```powershell
# Using the bundled helper script:
.\scripts\deploy-agent-silent.ps1 -ServerUrl "https://<server-ip>"
```
Or via native `msiexec`:
```cmd
msiexec.exe /i "installers\EndpointHubAgent.msi" /qn /norestart SERVER_URL="https://<server-ip>"
```

---

## Version Management & Manifest

NetPass EPMS provides a machine-readable version manifest at [`versions.json`](versions.json). This allows automated software distribution pipelines, Intune packaging scripts, or the Web Portal itself to query version statuses:

- **Current Stable Version:** `1.0.0` (`26.10.29473.0`)
- **Release Manifest:** [`versions.json`](versions.json)
- **Git Release Tag:** `v1.0.0`
- **Release Checksums:** [`installers/SHA256SUMS.txt`](installers/SHA256SUMS.txt)

---

## Platform Architecture

```
+-----------------------------------------------------------------------------------+
|                           NetPass Windows EPMS Platform                           |
+-----------------------------------------------------------------------------------+
                                          |
                +-------------------------+-------------------------+
                |                                                   |
                v                                                   v
+-------------------------------+                   +-------------------------------+
|     EndpointHub Server Hub    |                   |      Single-Page Web Portal   |
|   (Windows Service / Kestrel) |                   |    (React 19 / TypeScript)    |
|                               |                   |                               |
| • ASP.NET Core 9 Web API      | <================ | • Real-Time Device Telemetry  |
| • SignalR WebSocket Hub       |                   | • Policy Bundle Assignment    |
| • Embedded SQLite / DB Engine |                   | • BitLocker Audited Reveal    |
| • Automated Backup Engine     |                   | • Disaster Recovery Console   |
+-------------------------------+                   +-------------------------------+
                |
                | mTLS (Port 443 / 8443) - Pinned X.509 Thumbprints
                |
                v
+-----------------------------------------------------------------------------------+
|                           EndpointHub Client Agent (MSI)                          |
|                       (Windows Service: EndpointHubAgent)                         |
|                                                                                   |
|  • Real-Time SignalR Receiver: Dispatches PowerShell/Batch scripts                |
|  • Hardware & Software Inventory: Disks, Apps, Network Adapters                   |
|  • 15-Minute Persistent Loop: Automatic drift remediation on policies             |
|  • Master Restrictions: Defender, BitLocker, USB Storage, Firewall, AppLocker    |
+-----------------------------------------------------------------------------------+
```

---

## Core Capabilities Verified on Live VMs

1. **Zero-Trust Mutual TLS (mTLS):** Bi-directional cryptographic authentication between server and clients with automatic root CA pinning.
2. **Real-Time SignalR Operations:** Dispatches PowerShell and Command scripts to online endpoints with sub-second WebSocket roundtrips and full audit trail logging.
3. **Master Restriction Catalogue:** 7-domain enterprise policy engine covering Defender real-time protection, AppLocker execution blocks, USB mass-storage restrictions, and network hardening.
4. **Persistent Drift Remediation:** Agent continuously validates local registry keys, WMI states, and firewall profiles every 15 minutes, re-applying policy if altered.
5. **BitLocker Key Escrow:** Transparent recovery password escrow during initial enrollment with audited viewing controls.
6. **Automated Disaster Recovery:** Automated database snapshotting with ZIP compression, SQLite integrity verification, and one-click restore.
7. **Enterprise Governance:** Immutable audit logging with formula injection defended CSV exports and ASP.NET Core IP rate-limiting.

---

## Documentation Library

- [**Server Installation Guide**](docs/SERVER_INSTALLATION_GUIDE.md) — Comprehensive setup, firewall, and certificate instructions.
- [**Agent Deployment Guide**](docs/AGENT_DEPLOYMENT_GUIDE.md) — Silent GPO, Intune, MECM, and PowerShell rollouts.
- [**Master Restriction Catalogue**](docs/RESTRICTION_CATALOGUE.md) — Master catalogue of endpoint restrictions and enforcement rules.
- [**Full Verification Report**](docs/VERIFICATION_REPORT.md) — Full-system test results and live VM audit evidence (20/20 test battery).
- [**Administrator Guide (PDF)**](docs/EndpointHub_Administrator_Guide.pdf) — Complete operator manual.

---

## License

Proprietary enterprise software. Copyright &copy; 2026 NetPass Technologies. All rights reserved.
