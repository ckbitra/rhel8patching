Parse dnf updateinfo list security
Extract RHSA
Run dnf updateinfo info <RHSA>
Extract CVEs
Decide if reboot required (kernel update → yes)

How to check if reboot is required
How to list only CVE numbers
How to automate security-only patching safely in RHEL8
-----------
On **Red Hat Enterprise Linux 8**, patches are delivered as **RPM package updates** via `dnf`, and they are categorized mainly by **advisory type** and sometimes by **update impact**.

Here are the main types you’ll encounter:

---

# 1️⃣ Security Patches (Most Critical)

These fix vulnerabilities (CVEs).

### Advisory Type:

* **RHSA** (Red Hat Security Advisory)

Example:

```
RHSA-2026:3083 Important/Sec. kernel
```

### Severity Levels:

* Critical
* Important
* Moderate
* Low

### Install only security patches:

```bash
dnf update --security
```

These are typically required for:

* Compliance (PCI, SOX, HIPAA)
* Vulnerability scans
* Production hardening

---

# 2️⃣ Bug Fix Patches

These fix functional issues but are not security-related.

### Advisory Type:

* **RHBA** (Red Hat Bug Advisory)

Example:

```
RHBA-2026:1234
```

Used when:

* Application crashes
* Service instability
* Known bugs impacting production

---

# 3️⃣ Enhancement / Feature Updates

These add improvements or minor features.

### Advisory Type:

* **RHEA** (Red Hat Enhancement Advisory)

Usually lower priority unless feature is required.

---

# 4️⃣ Kernel Updates

Very important special category.

Affects:

* `kernel`
* `kernel-core`
* `kernel-modules`

### Requires:

* Reboot after installation

Check current kernel:

```bash
uname -r
```

Check installed kernels:

```bash
rpm -qa | grep kernel
```

---

# 5️⃣ Package Dependency Updates

Sometimes patches pull:

* Library updates (`glibc`, `openssl`)
* Runtime updates
* System tool updates

These may require:

* Service restart
* Application restart

---

# 6️⃣ Live Kernel Patches (Optional)

RHEL 8 supports **live patching** using:

* **kpatch**

This allows:

* Applying certain kernel security fixes
* Without reboot

Common in:

* High-availability production environments

---

# 7️⃣ Firmware / Microcode Updates

Sometimes delivered via:

* `microcode_ctl`
* Hardware-related packages

May require:

* Reboot

---

# 8️⃣ Extended Lifecycle / EUS Patches

If using:

* Extended Update Support (EUS)
* Specific minor version lock (like 8.6 only)

Patches will be limited to that stream.

Check release:

```bash
cat /etc/redhat-release
```

---

# 9️⃣ Module Stream Updates (AppStreams)

RHEL 8 uses modular repositories.

Example:

* `nodejs:16`
* `postgresql:13`

Check enabled modules:

```bash
dnf module list --enabled
```

Module stream updates may require:

* Module reset
* Stream switching

---

# 🔟 Critical Infrastructure Components

Often monitored separately:

* `openssl`
* `glibc`
* `sudo`
* `systemd`
* `bash`
* `kernel`

Security teams often prioritize these.

---

# 🔎 How to See Patch Types

List all advisory types:

```bash
dnf updateinfo list
```

List only security:

```bash
dnf updateinfo list security
```

List bugfix only:

```bash
dnf updateinfo list bugfix
```

---

# 🏢 In Enterprise Environments

Common patch strategy:

| Environment       | Patch Type                 |
| ----------------- | -------------------------- |
| Production        | Security + critical bugfix |
| Dev/Test          | All updates                |
| Regulated systems | Security only (scheduled)  |
| HA systems        | Live patching (kpatch)     |

---

Since you’re working with RHEL8 patching automation, if you'd like I can also provide:

* ✅ A recommended enterprise patching strategy
* ✅ A reboot detection workflow
* ✅ An SSM automation-based patch plan
* ✅ A compliance-ready patch checklist

Which direction are you implementing — manual, Ansible, or AWS SSM?
