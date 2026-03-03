Below is a **practical RHEL 8 patching reference** for
**Red Hat Enterprise Linux 8**
covering:

1️⃣ How to list vulnerabilities / updates
2️⃣ How to apply them

---

# 🔐 1️⃣ Security Patches (RHSA)

### ✅ List Available Security Advisories

```bash
dnf updateinfo list security
```

### List detailed info (includes CVEs)

```bash
dnf updateinfo info security
```

### List only CVE numbers

```bash
dnf updateinfo list cves
```

### Check if specific CVE affects system

```bash
dnf updateinfo info --cve CVE-2026-XXXX
```

---

### 🚀 Apply Only Security Updates

```bash
sudo dnf update --security
```

Apply specific advisory:

```bash
sudo dnf update --advisory=RHSA-2026:3083
```

---

# 🐞 2️⃣ Bug Fix Patches (RHBA)

### ✅ List Bugfix Advisories

```bash
dnf updateinfo list bugfix
```

Detailed:

```bash
dnf updateinfo info bugfix
```

---

### 🚀 Apply Bugfix Updates

```bash
sudo dnf update --bugfix
```

Specific advisory:

```bash
sudo dnf update --advisory=RHBA-2026:1234
```

---

# ✨ 3️⃣ Enhancement Updates (RHEA)

### ✅ List Enhancements

```bash
dnf updateinfo list enhancement
```

---

### 🚀 Apply Enhancement Updates

```bash
sudo dnf update --enhancement
```

---

# 🧠 4️⃣ Kernel Updates

### ✅ List Available Kernel Updates

```bash
dnf list updates kernel*
```

Or:

```bash
dnf updateinfo list security | grep kernel
```

Check installed kernels:

```bash
rpm -qa | grep kernel
```

---

### 🚀 Apply Kernel Updates

```bash
sudo dnf update kernel*
```

Or as part of security update:

```bash
sudo dnf update --security
```

⚠ Requires reboot:

```bash
sudo reboot
```

Check if reboot required:

```bash
needs-restarting -r
```

(Install if missing:)

```bash
sudo dnf install dnf-utils
```

---

# 📦 5️⃣ General Package Updates (All Types)

### ✅ List All Available Updates

```bash
dnf check-update
```

---

### 🚀 Apply All Updates

```bash
sudo dnf update -y
```

---

# 🧬 6️⃣ Live Kernel Patching (kpatch)

Using **kpatch**

### Install kpatch

```bash
sudo dnf install kpatch
```

### List available live patches

```bash
sudo kpatch list
```

### Apply live patches

```bash
sudo dnf update kpatch-patch*
```

No reboot required.

---

# 🔄 7️⃣ Firmware / Microcode Updates

### List microcode updates

```bash
dnf list updates microcode_ctl
```

### Apply

```bash
sudo dnf update microcode_ctl
```

Reboot usually required.

---

# 📚 8️⃣ Module Stream Updates (AppStreams)

### List enabled modules

```bash
dnf module list --enabled
```

### Check module updates

```bash
dnf module list <module-name>
```

### Update module packages

```bash
sudo dnf update
```

Switch module stream (if needed):

```bash
sudo dnf module reset nodejs
sudo dnf module enable nodejs:16
```

---

# 🏢 Enterprise Automation Version

Most production environments use:

### Security-only patch cycle:

```bash
sudo dnf update --security -y
```

### Full patch cycle (monthly):

```bash
sudo dnf update -y
sudo reboot
```

---

# 🎯 Quick Summary Table

| Patch Type   | List Command                      | Apply Command              |
| ------------ | --------------------------------- | -------------------------- |
| Security     | `dnf updateinfo list security`    | `dnf update --security`    |
| Bugfix       | `dnf updateinfo list bugfix`      | `dnf update --bugfix`      |
| Enhancement  | `dnf updateinfo list enhancement` | `dnf update --enhancement` |
| Kernel       | `dnf list updates kernel*`        | `dnf update kernel*`       |
| All Updates  | `dnf check-update`                | `dnf update`               |
| CVE-specific | `dnf updateinfo info --cve`       | `dnf update --cve`         |

---

If you'd like, I can also provide:

* ✅ A **production-safe patch workflow**
* ✅ An **AWS SSM Patch Manager equivalent**
* ✅ An **Ansible playbook for RHEL8 patching**
* ✅ A script that outputs “Patch status: Compliant / Not Compliant” for automation

Since you’re working on RHEL8 patch validation earlier, do you want this optimized for manual servers or EC2 automation?
