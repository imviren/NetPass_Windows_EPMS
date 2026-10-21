# NetPass Windows EPMS — Enterprise Update Management & Delivery Plan

## 1. Executive Summary

Maintaining an endpoint fleet requires an update distribution system that is **rapid during zero-day mitigation**, **safe against fleet-wide bricking**, and **gentle on enterprise network bandwidth**.

This document outlines the architecture for delivering and managing updates across two critical layers:
1. **Client Agent Fleet Updates (`EndpointHubAgent.msi`):** Updating hundreds or thousands of Windows workstations and servers silently, reliably, and with automated rollback if an update fails.
2. **Server Hub & Database Updates (`EndpointHubServerSetup.exe`):** Upgrading the core management service, database schema, and web portal with zero data loss and automated rollback backups.

---

## 2. Evaluation of Update Delivery Methods

| Update Method | Pros | Cons | Verdict for NetPass EPMS |
|---|---|---|---|
| **Periodic Polling (Pure Pull)** | Simple to implement, works behind NAT, resilient against transient server downtime. | High latency (hours before endpoints update), cannot do emergency zero-day patching. | **Secondary Fallback** (Used for offline devices checking in). |
| **Pure Push (Raw WinRM / SSH / PSSession)** | Instant trigger. | Requires open inbound ports on endpoints, fails on laptops roaming outside corporate firewall, breaks zero-trust model. | **Rejected** (Violates endpoint isolation and security baselines). |
| **GPO / Intune Manual Re-deployment** | Uses existing IT infrastructure. | High administrative overhead, lacks granular ring automation, slow feedback loop. | **Supported as External Alternative** (For initial deployment, not continuous updates). |
| **Hybrid SignalR Push + Scheduled Pull (Recommended)** | **Instant dispatch over persistent WebSocket** (<1 sec), **fallback check-in for sleeping devices**, client-initiated HTTPS pull keeps endpoints 100% closed to inbound connections, verified with SHA-256 and task scheduler execution. | Requires robust server staging and ring orchestration logic. | **Selected Primary Architecture** |

---

## 3. End-to-End Agent Update Architecture

```
+---------------------------------------------------------------------------------------------------------+
|                                    NETPASS EPMS UPDATE ARCHITECTURE                                      |
+---------------------------------------------------------------------------------------------------------+

  [ Admin Portal / CI/CD ]
             │
             │ Uploads new MSI & registers hash in versions.json
             ▼
  +──────────────────────+
  │ EndpointHub Server   │ <────────── Staged in C:\ProgramData\EndpointHub\Server\Updates\
  │ (AgentUpdateService) │
  +──────────────────────+
             │
             ├──────────────────────────────────────────────────────┬─────────────────────────────────────┐
             │ 1. Instant Push (SignalR Event)                      │ 2. Background Pull                  │ 3. External CDN/GitHub
             │    "AgentUpdateAvailable"                            │    "GET /api/agent/update/check"    │    raw/main/installers/
             ▼                                                      ▼                                     ▼
  +──────────────────────────────────────────────────────────────────────────────────────────────────────────+
  |                                        Target Windows Endpoint                                           |
  |                                                                                                          |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |  | 1. Download Engine (BITS / HttpClient)                                                             |  |
  |  |    • Downloads to: %ProgramData%\EndpointHub\Agent\Cache\EndpointHubAgent-<version>.msi            |  |
  |  |    • Background priority with bandwidth throttling (Max 2 MB/s on VPN connections)                 |  |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |                                                 │                                                        |
  |                                                 ▼                                                        |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |  | 2. Cryptographic & Signature Verification                                                          |  |
  |  |    • Computes SHA-256 of downloaded file against server manifest                                    |  |
  |  |    • Validates Authenticode signature (Microsoft / NetPass Enterprise Code Signing)                |  |
  |  |    • Aborts & deletes immediately if hash or signature fails                                        |  |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |                                                 │                                                        |
  |                                                 ▼                                                        |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |  | 3. Execution Outside Running Daemon (Windows Task Scheduler)                                        |  |
  |  |    • Schedules SYSTEM task: "EndpointHubAgentUpdate" to run 30 seconds in future                   |  |
  |  |    • Invokes: msiexec.exe /i "<msiPath>" /quiet /norestart REINSTALLMODE=amus                      |  |
  |  |    • Current service gracefully flushes telemetry and terminates                                   |  |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |                                                 │                                                        |
  |                                                 ▼                                                        |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  |  | 4. Health Check & Watchdog Handshake                                                               |  |
  |  |    • New service binary starts and establishes mTLS connection to server                           |  |
  |  |    • Sends "PostUpdateHeartbeat" with new version and install logs                                 |  |
  |  |    • If no successful heartbeat within 5 minutes, Watchdog triggers automatic rollback              |  |
  |  +────────────────────────────────────────────────────────────────────────────────────────────────────+  |
  +──────────────────────────────────────────────────────────────────────────────────────────────────────────+
```

---

## 4. Phased Deployment Rings & Fleet Governance

To eliminate the risk of a faulty update causing widespread disruption, all endpoints are categorized into **Deployment Rings** (already modeled in the database schema as `Device.UpdateRing`):

```
                                  DEPLOYMENT RING PIPELINE
                                  
   +───────────────────────────+
   |  Ring 0: Canary (IT/Dev)  | ──(24h Soak)──> Evaluates core stability, zero crash loops
   |  1% - 5% of fleet         |
   +───────────────────────────+
                 │
                 ▼
   +───────────────────────────+
   |  Ring 1: Pilot (Early)    | ──(48h Soak)──> Evaluates broad hardware diversity & edge cases
   |  15% - 20% of fleet       |
   +───────────────────────────+
                 │
                 ▼
   +───────────────────────────+
   |  Ring 2: Broad Production | ──(Daily 25% batches)──> Deploys to remainder of organization
   |  Remaining 75% - 80%      |
   +───────────────────────────+
```

### Automatic Safety Circuit Breakers:
- **Error Rate Threshold:** If more than **2%** of endpoints in any ring fail to report a successful post-update heartbeat within 15 minutes, the rollout is **automatically paused**.
- **Admin Alerting:** The server immediately marks the release as `Halted` and generates a Critical audit event, notifying operators via the dashboard and webhook/email.

---

## 5. Resilience, Watchdog & Automatic Rollback Strategy

A major failure mode in endpoint management software is when an updated agent crashes upon launch, cutting off communication and leaving the endpoint unmanageable.

NetPass EPMS prevents this through a **Three-Tier Fail-Safe Mechanism**:

```
Tier 1: MSI Native Rollback
---------------------------
Windows Installer (msiexec) tracks transactional installation state. If the MSI execution fails
or throws an error code during service registration, msiexec automatically restores previous
files, registry keys, and service binaries.

Tier 2: Dual-Binary Watchdog Wrapper
-------------------------------------
1. Before applying the MSI, the agent stages a lightweight standalone watchdog script:
   C:\ProgramData\EndpointHub\Agent\Watchdog\healthcheck.ps1
2. If the new service fails to connect to the server within 300 seconds, the watchdog triggers:
   msiexec /i "C:\ProgramData\EndpointHub\Agent\Cache\PreviousVersion.msi" /quiet /norestart
3. Restores communication and reports failure diagnostics to the server.

Tier 3: Offline Tamper Protection & Configuration Preservation
--------------------------------------------------------------
The local database (C:\ProgramData\EndpointHub\Agent\agent.db), mTLS client certificate,
and device enrollment secrets are stored outside Program Files. Upgrading binaries leaves
all device identity, keys, and pending policy queues 100% intact.
```

---

## 6. Network & Bandwidth Management

In large corporate networks or remote branch offices, hundreds of machines downloading a 27 MB MSI simultaneously can saturate WAN links and VPN tunnels.

### Bandwidth Controls:
1. **Background Intelligent Transfer Service (BITS):** Downloads use BITS to utilize only idle network bandwidth, backing off when active user traffic increases.
2. **Scheduled Staggering (Jitter):** Each agent computes a randomized delay between 0 and 1800 seconds (30 minutes) before initiating the download.
3. **Peer-to-Peer Branch Caching (Roadmap):** Endpoints on the same local subnet (`/24`) designate a local cache master to download the MSI once and distribute it locally across the LAN via HTTP port 8444.

---

## 7. Server-Side Update & Database Migration Pipeline

Upgrading the central server must be equally foolproof:

```
+───────────────────────────────────────────────────────────────────────────+
|                        SERVER UPGRADE WORKFLOW                            |
+───────────────────────────────────────────────────────────────────────────+

  1. Pre-Upgrade Automated Snapshot
     • Server setup invokes POST /api/backup/now
     • Creates a timestamped ZIP archive containing full SQLite/PostgreSQL dump,
       appsettings.json, and X.509 TLS certificate bundles.

  2. Service Maintenance Window Transition
     • SignalR hub signals connected agents to hold reconnection for 60 seconds.
     • EndpointHubServer service stops cleanly.

  3. Binary Replacement & Entity Framework Core Migration
     • New binaries extracted to C:\Program Files\EndpointHub\Server
     • EF Core executes: dbContext.Database.MigrateAsync()
     • All migrations are designed to be non-destructive (additive columns only).

  4. Automatic Self-Verification
     • Server starts and queries GET /api/health/live
     • If response != 200, setup triggers automatic restore from step 1 snapshot.
```

---

## 8. Web Portal Administrative Controls

The Web Administrative Portal will be enhanced with a dedicated **Update Management Hub**:

### Key Features:
1. **Fleet Version Distribution Chart:** Visual breakdown (donut chart) showing percentage of fleet on v1.0.0, v1.0.1, etc.
2. **Ring Assignment Manager:** Drag-and-drop or tag-based assignment of devices to `Canary`, `Pilot`, or `Broad` rings.
3. **Package Staging Console:** Upload new `.msi` packages, view auto-computed SHA-256 hashes, and configure rollout speed.
4. **Emergency Stop Button:** One-click global pause that immediately instructs all agents to halt in-progress update downloads.
5. **Update Event Logs:** Detailed per-device status tracking: `Targeted` &rarr; `Downloading` &rarr; `Installing` &rarr; `Verified` (or `Rolled Back`).

---

## 9. Implementation Roadmap

| Phase | Milestone | Deliverables |
|---|---|---|
| **Phase 1** | **Server Update Staging** | • Upload `.msi` via portal API<br>• Automatic SHA-256 generation<br>• Enhanced `AgentUpdateService` with ring-aware targeting |
| **Phase 2** | **Agent Watchdog & Health Handshake** | • Implementation of `healthcheck.ps1` watchdog<br>• 5-minute post-update confirmation heartbeat<br>• Automatic rollback invocation |
| **Phase 3** | **Portal Rollout Console** | • Web Portal UI for managing Deployment Rings<br>• Rollout progress bar & emergency pause button<br>• Fleet compliance & version breakdown dashboard |
| **Phase 4** | **Peer Cache & Bandwidth Throttling** | • BITS download integration<br>• Subnet peer-to-peer download sharing for remote offices |
