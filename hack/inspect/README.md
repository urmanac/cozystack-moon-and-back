# CozyStack / Talos Signature and PE Inspection Utilities

This directory contains utility scripts developed during the investigation of kernel module signing key mismatches. They are preserved here to facilitate diagnosing future Secure Boot or module load validation issues on CozyStack nodes.

## 🛠️ Included Tools

### 1. `parse-sig.py`
Parses the appended cryptographic signature structure of a compiled Linux kernel module (`.ko` file). It extracts the signature algorithm, ID type, signer name, key ID (hash), and signature length.

**Usage:**
```bash
python3 hack/inspect/parse-sig.py /path/to/module.ko
```

**Example Output:**
```text
Algorithm: 0
Hash: 0
ID Type: 2
Signer name length: 0
Key ID length: 0
Signature length: 706
Signer name: 
Key ID (hex): 
```

### 2. `extract-linux-sec.py`
Parses the PE headers of a Unified Kernel Image (`vmlinuz.efi` / UKI), extracts the `.linux` (Zstd-compressed kernel payload) section, and decompresses it to yield the raw uncompressed kernel `vmlinux`.

**Usage:**
```bash
python3 hack/inspect/extract-linux-sec.py /path/to/vmlinuz.efi /path/to/output_vmlinux
```

**Example Output:**
```text
Found .linux section at raw pointer 743936 with size 20140544
First 4 bytes of .linux section: 4d5a0000
Successfully decompressed to /path/to/output_vmlinux
```

---

## 🔍 How to diagnose Key Mismatches
When a module fails to load with `key was rejected by service`:

1.  **Extract the Running Kernel Key ID:** On the running node:
    ```bash
    talosctl -n <node-ip> read /proc/keys
    ```
    Look for the `asymmetri` entry corresponding to `Build time throw-away kernel key` and record its Key ID/hash.

2.  **Inspect the Module's Signature:** Run `parse-sig.py` on the compiled module from the extension package to check its key.

3.  **Inspect the Installer Kernel Certificate:** Extract the UKI from the installer image, extract the `.linux` section using `extract-linux-sec.py`, and inspect the embedded X.509 certificate. If the certificates do not match, the `imager` fell back to a default official image.
