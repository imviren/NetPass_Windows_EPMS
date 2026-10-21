# NetPass Windows EPMS — Client Agent Deployment Guide

This guide details how to roll out the **EndpointHub Agent** (`EndpointHubAgent.msi`) across enterprise Windows workstations and servers.

---

## 1. Supported Operating Systems

- Windows 11 (21H2, 22H2, 23H2, 24H2) — Pro, Enterprise, Education (x64)
- Windows 10 (21H2, 22H2) — Pro, Enterprise, Education (x64)
- Windows Server 2025, 2022, 2019 — Standard and Datacenter (x64)

---

## 2. Deployment Methods

### Option A: PowerShell Helper Script (Recommended)
Use the included automated deployment script:

```powershell
# From the scripts directory:
.\deploy-agent-silent.ps1 -ServerUrl "https://epms.corp.local"
```

### Option B: Direct msiexec Command-Line
Deploy silently using Windows Installer commands:

```cmd
msiexec.exe /i "EndpointHubAgent.msi" /qn /norestart /l*v "%TEMP%\EndpointHubAgent_Install.log" SERVER_URL="https://epms.corp.local"
```

### Option C: Microsoft Intune (LOB / Win32 App)
1. In Microsoft Intune admin center, go to **Apps** > **Windows** > **Add**.
2. Select **Line-of-business app** or package with the Win32 Content Prep Tool.
3. Select `EndpointHubAgent.msi`.
4. In command-line arguments, set:
   ```
   SERVER_URL="https://epms.corp.local"
   ```
5. Assign to the target device groups with install behavior set to **System**.

### Option D: Active Directory Group Policy (GPO)
1. Copy `EndpointHubAgent.msi` to a network share with read permissions for `Domain Computers`.
2. Create an **MST Transform** or use a startup script:
   ```cmd
   msiexec.exe /i "\\dc01\share\EndpointHubAgent.msi" /qn SERVER_URL="https://epms.corp.local"
   ```
3. Link the GPO to target Organizational Units (OUs).

---

## 3. Installer Parameters Reference

| Parameter | Type | Required | Description | Example |
|---|---|:---:|---|---|
| `SERVER_URL` | String | **Yes** | HTTPS address of the EndpointHub Server | `SERVER_URL="https://10.0.10.15"` |
| `ENROLLMENT_TOKEN`| String | No | Pre-shared token for automated group mapping | `ENROLLMENT_TOKEN="tok_finance_dept"` |
| `INSTALLDIR` | String | No | Custom installation folder path | `INSTALLDIR="C:\SecOps\Agent"` |

---

## 4. Verification & Diagnostics

1. Check that the Windows service is running:
   ```powershell
   Get-Service -Name EndpointHubAgent
   ```
2. Check agent runtime logs:
   ```
   C:\ProgramData\EndpointHub\Agent\Logs\agent-*.log
   ```
3. In the Web Management Portal, verify that the new endpoint appears in the **Devices** grid with status `Online`.
