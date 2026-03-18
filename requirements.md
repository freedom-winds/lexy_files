# Lexy Files — Optimized Project Requirements (English)

## 1. Project Overview
**Project Name:** Lexy Files  
**Project Goal:** Build a convenient, modern, and efficient cross-device file transfer platform.

Lexy Files should allow users to transfer files seamlessly across multiple device types, including Web, Android, iOS, and PC, while keeping the user experience clean, fast, visually polished, and highly reusable across platforms.

---

## 2. Supported Transfer Modes
The system must support the following four transfer modes:

### A. Bluetooth Transfer
- Supported on all applicable platforms: **Android / iOS / PC**.
- File transfer should occur directly between devices whenever the platform permits.

### B. Local Network Transfer
- Devices must be on the **same LAN** and **online at the same time**.
- File transfer must be **peer-to-peer**, without routing the file stream through the server.

### C. Same-Account Device Transfer
- Transfer between devices logged into the **same user account**.
- Both devices must be **online simultaneously**.
- The server must **not persist uploaded files** in this mode.
- The server acts only as a **real-time relay for the file stream**.
- Only **downstream traffic** should be counted against the user’s traffic quota.

### D. Pickup Code / Direct Link Download
- A sender uploads a file temporarily to the server.
- The receiver downloads it using either a **pickup code** or a **direct link**.
- Files in this mode are **temporarily stored on the server**.
- Only **downstream traffic** should be counted against the user’s traffic quota.
- Storage usage must count against the user’s storage limits.
- For **direct-link downloads**, the download speed limit must follow the **anonymous** user group rules.

---

## 3. Transfer Architecture Rules
### 3.1 Direct-transfer modes
For **Bluetooth Transfer** and **Local Network Transfer**:
- File data must **not pass through the backend server**.
- The backend may still be used for **signaling, discovery, session negotiation, authentication, NAT assistance, or metadata exchange**, but not for file payload delivery.

### 3.2 Relay mode
For **Same-Account Device Transfer**:
- The backend server may relay the file stream in real time.
- The backend must **not store the transferred file**.

### 3.3 Temporary-storage mode
For **Pickup Code / Direct Link Download**:
- The backend may temporarily store files.
- Files must follow the full lifecycle rules defined below, including expiration, redemption grace period, and physical deletion.

---

## 4. User Groups and Limits
The system must enforce the following limits by user group:

| User Group | Download Speed Limit | Max Single File Size | Max Total Stored File Size | Download Traffic Quota | Max File Retention Time |
|---|---:|---:|---:|---:|---:|
| anonymous | 3 MB/s | 500 MB | 2 GB | 1 GB/day | 15 min |
| normal | 8 MB/s | 2 GB | 10 GB | 5 GB/day | 6 h |
| vip | 15 MB/s | 5 GB | 40 GB | 500 GB/month | 5 days |
| admin | unlimited | unlimited | unlimited | unlimited | unlimited |

Notes:
- “Max total stored file size” refers to the total size of files currently stored on the server for that user.
- Retention limits apply only to modes that involve temporary server-side storage.
- Traffic quotas apply only where server-side downstream traffic is consumed.

---

## 5. Anonymous User Identification
For the **anonymous** user group:
- If either the **IP address** matches or the **device identity** matches, the requests should be treated as belonging to the **same anonymous user**.
- In other words, matching **any one** of these identifiers is sufficient for anonymous-user consolidation.

---

## 6. Login Rules by Platform
- **Web** supports anonymous (not logged-in) access.
- All other clients, including **Android / iOS / PC software**, must require login.

---

## 7. Backend Technology Stack
The backend must use:
- **Flask** as the primary backend framework
- **MySQL** as the primary database

Optional supporting infrastructure may be introduced when necessary, including but not limited to:
- **Redis** for caching, session coordination, rate limiting, transient state, and queue-like workloads
- Other reasonable supporting services if they clearly improve reliability, performance, or scalability

---

## 8. Frontend and Client Requirements
All client applications and frontends must:
- Maintain a **clean, modern, and visually polished** design
- Be **clear, intuitive, and user-friendly**
- Avoid an obvious “AI-generated” visual style
- Maximize **code reuse** across platforms whenever technically practical

The target clients include:
- **Web**
- **Android APK**
- **iOS app**
- **PC desktop application**

The architecture should prioritize high reuse of:
- Business logic
- Networking / transport logic
- Shared UI paradigms and components where feasible
- Cross-platform modules and SDK-style abstractions

---

## 9. Admin Console
The system must include an **admin-only management console**, visible and accessible only to users in the **admin** user group.

The admin console must support at least the following capabilities:

### 9.1 User and device management
- Change a user’s **user group**
- Modify **per-user quota values**
- Modify **default quota values for each user group**
- **Ban** users
- Force a user account and/or its devices to **go offline immediately**

### 9.2 File management
- View files uploaded by users, including files that are already expired but still within the redemption grace period
- **Download** files uploaded by users
- **Force-expire** a user’s files
- **Force-delete** files even if they are:
  - still unexpired, or
  - already inside the redemption grace period

### 9.3 Operational visibility
- The admin console should surface sufficient metadata for auditing and management, such as:
  - file owner
  - file status
  - expiration time
  - redemption-period end time
  - current storage usage and quota usage
  - relevant device/account identifiers

---

## 10. File Lifecycle and Deletion Policy
All files that are temporarily stored on the server must follow the lifecycle below:

### 10.1 Active period
- A file is initially available during its normal retention period according to the applicable policy.

### 10.2 Redemption grace period
- After a file expires, it must enter a **7-day redemption grace period**.
- During this stage:
  - the file is considered **expired for normal user access**,
  - the file is **not yet physically deleted**,
  - the file must remain visible in the **admin console**.

### 10.3 Physical deletion
- Once the 7-day redemption grace period ends, the file must be **physically deleted** from storage.
- Physical deletion here means the file content should no longer remain in the normal storage path used by the service.

### 10.4 Administrative override
- Admins may:
  - delete files before expiration,
  - delete files during the redemption grace period,
  - or force files to expire immediately.

---

## 11. Product Direction and Implementation Expectations
Given that the project is currently at **day zero** and only has baseline requirement design, the implementation workflow should generally proceed as follows:
1. Fully read and analyze the design/specification
2. Produce overall project architecture and module planning
3. Define API contracts, transfer workflows, and file lifecycle behavior
4. Implement backend capabilities
5. Implement frontend/client applications for all target platforms
6. Complete end-to-end integration testing and validation
7. Deliver a maintainable, production-oriented engineering structure suitable for continued iteration

The final solution should be a **real engineering project intended for practical deployment and ongoing development**, not merely a demo prototype.
