# NetPass Windows EPMS — Server Installation & Configuration Guide

This guide covers the deployment of the **EndpointHub Server** on Windows Server 2019, 2022, or 2025 (or Windows 10/11 Pro/Enterprise for dev/staging).

---

## 1. System Requirements

### Hardware Requirements
- **CPU:** 4 vCPUs or physical cores (2.0 GHz+).
- **RAM:** 8 GB minimum (16 GB recommended for environments with 500+ endpoints).
- **Disk:** 50 GB available SSD storage (for operating system, database, and snapshot backups).
- **Network:** 1 Gbps Ethernet interface.

### Software Prerequisites
- **OS:** Windows Server 2019 / 2022 / 2025 (Standard or Datacenter), or Windows 10/11 x64.
- **Port Requirements:**
  - `443` (TCP, Inbound): Web Management Portal, REST API, SignalR Agent Hub (TLS/HTTPS).
  - `8443` (TCP, Inbound, Optional): Alternative administrative port if 443 is shared.
  - `5985 / 5986` (TCP, Inbound, Optional): WinRM for remote PowerShell operations.

---

## 2. Interactive Installation via Setup Wizard

1. Download [EndpointHubServerSetup.exe](https://github.com/imviren/NetPass_Windows_EPMS/raw/main/installers/EndpointHubServerSetup.exe).
2. Right-click `EndpointHubServerSetup.exe` and select **Run as administrator**.
3. Follow the wizard steps:
   - **Installation Directory:** Default is `C:\Program Files\EndpointHub\Server`.
   - **Data Directory:** Default is `C:\ProgramData\EndpointHub\Server` (holds database, certificates, and backups).
   - **Service Port:** Enter `443` (default).
   - **Root Administrator Account:** Configure initial `admin@endpointhub.local` credentials.
4. Click **Install**. The setup will:
   - Extract server binaries and static web portal assets.
   - Generate a dedicated X.509 Root CA and Server TLS certificate.
   - Run Entity Framework Core database migrations.
   - Register and start the `EndpointHubServer` Windows Service with automatic recovery.

---

## 3. Silent Installation (Command-Line / Automation)

For automated or scripted deployments, run:

```powershell
Start-Process -FilePath ".\EndpointHubServerSetup.exe" `
    -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/DIR=`"C:\Program Files\EndpointHub\Server`"" `
    -Wait
```

---

## 4. Post-Installation Verification

1. Verify that the Windows service is running:
   ```powershell
   Get-Service -Name EndpointHubServer
   ```
2. Check the unauthenticated liveness health probe:
   ```powershell
   Invoke-RestMethod -Uri "https://localhost/api/health/live" -SkipCertificateCheck
   ```
3. Open a browser and navigate to `https://localhost` or `https://<server-ip>`.
4. Sign in with the administrator credentials:
   - **Email:** `admin@endpointhub.local`
   - **Role:** `Owner`

---

## 5. Security & TLS Configuration

- **Automatic TLS:** A self-signed 2-year TLS certificate is generated during initial setup.
- **Custom Enterprise Certificate:** To bind an enterprise CA certificate, replace the `.pfx` bundle located at:
  ```
  C:\ProgramData\EndpointHub\Server\Certs\server.pfx
  ```
  and update the thumbprint in `appsettings.json`, then restart the service:
  ```powershell
  Restart-Service -Name EndpointHubServer
  ```
