# FIPS Container Images

> **Building the FIPS-enabled containerized applications. This repo is always going to be open, and we appreciate the community contributions. We have major plans to add FIPS-enabled container images (dockerfiles) and then build auto-maintenance github actions to keep releasing the images with all the Software Supply Chain Security best practices, per [openSSF](https://openssf.org/) **

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)
[![Project Status](https://img.shields.io/badge/Status-Alpha-yellow.svg)](https://github.com/open-containers/fips-container-images)
[![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](./CONTRIBUTING.md)

---

## 🚨 Project Status: Alpha / Early Access

**What's Ready Today:**
- ✅ **Python FIPS Images**: Versions 3.9-3.14 on Ubuntu 20.04/22.04, Wolfi, Alpine
- ✅ **vLLM FIPS Images**: Versions 0.11.0, 0.11.1, 0.12.0 for ML/LLM workloads
- ✅ **Comprehensive Validation**: 15-category FIPS 140-2 compliance test suite
- ✅ **Reference Templates**: Reusable Dockerfile patterns for building FIPS images
- ✅ **Build Automation**: GitHub Actions workflow for discovery, build, and validation

**What's In Progress (Need Community Help!):**
- 🚧 **Published Registry Images**: Automated publishing to GitHub Container Registry
- 🚧 **Image Signing**: Cosign/ORAS integration for attestations and provenance
- 🚧 **Other Runtimes**: Go, Rust, Node.js, Java, .NET (templates exist, implementation needed)
- 🚧 **Documentation Site**: Comprehensive docs website with guides and API references
- 🚧 **SBOM Automation**: Complete supply chain security artifacts

**How to Help:** See [Contributing](#-contributing) section below!

---

## 🎯 Why This Project Exists

Running applications in FIPS 140-2/140-3 regulated environments is **hard**. Teams face:

- **No standardized approach** across language runtimes and frameworks
- **Vendor-specific implementations** that require reverse-engineering
- **Complex build requirements** for FIPS-enabled cryptographic modules
- **Unclear compliance validation** processes
- **Fragmented documentation** across different sources

### The Problem

Most organizations need to:
1. Figure out how to compile OpenSSL with FIPS provider enabled
2. Patch and rebuild language runtimes (Python, Node.js, etc.) against FIPS OpenSSL
3. Configure FIPS mode correctly with proper environment variables
4. Validate cryptographic operations use approved algorithms
5. Document everything for audits
6. Keep images patched and updated

**This is painful, error-prone, and duplicated across every team.**

### Our Solution

FIPS Container Images provides:

- ✅ **Reference implementations** showing the correct way to build FIPS-compliant images
- ✅ **Pre-built Dockerfiles** with pinned dependencies for reproducibility
- ✅ **Automated validation** ensuring images meet FIPS requirements
- ✅ **Clear documentation** of what's FIPS-validated and how to verify it
- ✅ **Community collaboration** to avoid duplicated effort

> **Important:** Using a FIPS-enabled image does not automatically make your system FIPS compliant. You still need proper host configuration, operational controls, and security policies. This project provides the **foundation** for FIPS-compliant containerized applications.

---

## 🚀 Quick Start

### Option 1: Build Locally (Recommended for Now)

Since registry images aren't published yet, you can build FIPS images locally:

```bash
# Clone the repository
git clone https://github.com/open-containers/fips-container-images.git
cd fips-container-images

# Build a Python 3.11 FIPS image on Ubuntu 22.04
cd openssl/3.0.9/ubuntu/22.04/python/3.11
docker build -f fips-dockerfile -t my-fips-python:3.11 .

# Validate FIPS compliance
cd ../../../../../..
./tests/python/chk-fips-python-imgs.sh my-fips-python:3.11
```

### Option 2: Build vLLM for ML/LLM Workloads

```bash
# Build vLLM 0.12.0 with FIPS support
cd openssl/3.0.9/ubuntu/20.04/vllm/0.12.0
docker build -f fips-dockerfile -t my-fips-vllm:0.12.0 .

# Validate FIPS compliance
cd ../../../../../..
./tests/vllm/chk-fips-vllm-img.sh my-fips-vllm:0.12.0
```

### Option 3: Use as Reference Template

Start with our templates to build your own:

```bash
# View the reference template
cat templates-dockerfiles/fips-dockerfile-template

# Copy and customize for your needs
cp templates-dockerfiles/fips-dockerfile-template my-app/Dockerfile
# Edit to match your requirements
```

### Verify FIPS Mode Inside Container

```bash
# Run the container and check FIPS provider
docker run --rm my-fips-python:3.11 /usr/local/ssl/bin/openssl list -providers

# Expected output should show FIPS provider:
# Providers:
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.0.9
#     status: active
```

---

## 📦 What's Available Today

### Python FIPS Images

Built and tested for multiple Python versions across different base OS:

| Python Version | Ubuntu 20.04 | Ubuntu 22.04 | Wolfi | Alpine |
|----------------|--------------|--------------|-------|--------|
| 3.9            | ✅           | ✅           | ✅    | ✅     |
| 3.10           | ✅           | ✅           | ✅    | ✅     |
| 3.11           | ✅           | ✅           | ✅    | ✅     |
| 3.12           | ✅           | ✅           | ✅    | ✅     |
| 3.13           | ✅           | ✅           | ✅    | ✅     |
| 3.14           | ✅           | ✅           | ✅    | ✅     |

**Location:** `openssl/<version>/<os>/<os-version>/python/<python-version>/`

### vLLM FIPS Images

ML/LLM runtime support for FIPS environments:

| vLLM Version | Ubuntu 20.04 | Wolfi |
|--------------|--------------|-------|
| 0.11.0       | ✅           | ✅    |
| 0.11.1       | ✅           | ✅    |
| 0.12.0       | ✅           | ✅    |

**Location:** `openssl/<version>/<os>/<os-version>/vllm/<vllm-version>/`

### OpenSSL FIPS Versions

All images use FIPS-validated OpenSSL:

- **OpenSSL 3.0.9** with FIPS provider
- **OpenSSL 3.1.2** with FIPS provider

### Validation Test Suites

Comprehensive FIPS compliance validation covering:

1. ✅ Module Identification & Configuration
2. ✅ Power-On Self-Tests (POST)
3. ✅ Cryptographic Algorithm Validation (AES, SHA, RSA, ECDSA)
4. ✅ Key Generation & Management
5. ✅ Approved vs Non-Approved Operations
6. ✅ Error States & Boundary Conditions
7. ✅ Security Policy Compliance
8. ✅ Operational Environment
9. ✅ Zeroization & Data Protection
10. ✅ Compliance Verification
11. ✅ Performance & Resource Management
12. ✅ Container Image Security Posture
13. ✅ Audit Trail & Documentation
14. ✅ Vulnerability Scanning (Trivy)
15. ✅ SBOM Generation (CycloneDX)

**Location:** `tests/<runtime>/`

---

## 🗺️ Roadmap

### ✅ Phase 0: Foundation (Current - COMPLETE)

**Goal:** Build reference implementations for Python and vLLM

**Status:** ✅ **DONE**

- ✅ Python FIPS Dockerfiles (3.9-3.14)
- ✅ vLLM FIPS Dockerfiles (0.11.x, 0.12.x)
- ✅ Reference templates and build configurations
- ✅ Comprehensive FIPS validation test suite
- ✅ GitHub Actions workflow (basic)
- ✅ Repository documentation

### 🚧 Phase 1: Production Infrastructure (IN PROGRESS - NEEDS HELP!)

**Goal:** Production-ready CI/CD, publishing, and supply chain security

**Status:** 🚧 **IN PROGRESS - COMMUNITY HELP NEEDED**

Priority tasks:
- [ ] **GitHub Container Registry Publishing**
  - Automated image publishing workflow
  - Multi-arch builds (amd64, arm64) with QEMU
  - Proper tagging strategy (semantic versioning, latest, etc.)

- [ ] **Image Signing & Attestation**
  - Cosign integration for image signing
  - SLSA provenance generation
  - SBOM generation and publishing (CycloneDX, SPDX)
  - Vulnerability attestation (VEX)

- [ ] **Production-Grade CI/CD**
  - Matrix builds for all combinations
  - Automated testing on PR
  - Scheduled security scanning
  - Dependency update automation (Renovate/Dependabot)

- [ ] **Documentation Website**
  - Static site (MkDocs, Docusaurus, or similar)
  - Usage guides and tutorials
  - API/reference documentation
  - FIPS compliance guides

**How You Can Help:** See [Contributing - Priority Areas](#priority-areas-for-contribution)

### 🔮 Phase 2: Runtime Expansion (PLANNED)

**Goal:** Extend to other language runtimes and frameworks

**Status:** 📋 **PLANNED**

Targets:
- [ ] Go (with FIPS-enabled crypto)
- [ ] Rust (runtime-only for pre-compiled binaries)
- [ ] Node.js (with FIPS-enabled OpenSSL)
- [ ] Java (OpenJDK with FIPS crypto providers)
- [ ] .NET (on FIPS-enabled Linux)
- [ ] C/C++ base images

### 🔮 Phase 3: Hardening & Compliance (FUTURE)

**Goal:** Advanced compliance features for regulated environments

**Status:** 📋 **FUTURE**

Targets:
- [ ] STIG-hardened base images
- [ ] CIS-hardened variants
- [ ] Policy-as-code (OPA/Conftest) for Kubernetes
- [ ] FedRAMP compliance documentation
- [ ] DoD IL compliance guidance
- [ ] Additional attestation formats

**Full roadmap:** See [ROADMAP.md](./ROADMAP.md)

---

## 🤝 Contributing

**We need your help!** This project is in early stages and community contributions are essential.

### Priority Areas for Contribution

#### 🔥 High Priority (Phase 1)

1. **CI/CD & Publishing** 🚀
   - Set up GitHub Container Registry publishing
   - Implement multi-arch builds (QEMU)
   - Create semantic versioning strategy
   - **Skills needed:** GitHub Actions, Docker, CI/CD

2. **Image Signing & Supply Chain Security** 🔐
   - Integrate Cosign for image signing
   - Generate SLSA provenance
   - Automate SBOM generation
   - Implement vulnerability attestation
   - **Skills needed:** Cosign, ORAS, Supply chain security

3. **Documentation Website** 📚
   - Build static documentation site
   - Write usage guides and tutorials
   - Create API reference documentation
   - **Skills needed:** MkDocs/Docusaurus, Technical writing

4. **Testing & Validation** ✅
   - Expand test coverage
   - Add integration tests
   - Performance benchmarking
   - **Skills needed:** Bash scripting, Testing, Docker

#### 🌟 Medium Priority (Phase 2)

5. **New Runtime Support** 🔧
   - Go FIPS images
   - Node.js FIPS images
   - Java FIPS images
   - Rust runtime images
   - **Skills needed:** Go/Node.js/Java/Rust, Dockerfile, FIPS knowledge

6. **Additional OS Support** 🐧
   - Debian FIPS images
   - RHEL/UBI FIPS images
   - Additional Wolfi variants
   - **Skills needed:** Linux, Package management, Docker

### How to Contribute

1. **Check existing issues** with labels:
   - [`good first issue`](https://github.com/open-containers/fips-container-images/labels/good%20first%20issue)
   - [`help wanted`](https://github.com/open-containers/fips-container-images/labels/help%20wanted)
   - [`priority`](https://github.com/open-containers/fips-container-images/labels/priority)

2. **Propose new work** via GitHub Discussions or Issues

3. **Fork and contribute** following our [CONTRIBUTING.md](./CONTRIBUTING.md) guide

4. **Join discussions** and help shape the project direction

### Quick Contribution Examples

**Example 1: Add a new Python version**
```bash
# Copy existing Dockerfile
cp openssl/3.0.9/ubuntu/22.04/python/3.11/fips-dockerfile \
   openssl/3.0.9/ubuntu/22.04/python/3.15/fips-dockerfile

# Update Python version in the Dockerfile
# Test the build
# Submit PR with validation results
```

**Example 2: Improve documentation**
- Add usage examples to `docs/`
- Improve README sections
- Write troubleshooting guides
- Create video tutorials

**Example 3: Fix CI/CD**
- Improve GitHub Actions workflows
- Add matrix build strategies
- Implement caching for faster builds

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

---

## 📚 Documentation

- **[Repository Structure](./repo-explaination.md)** - Understanding the codebase organization
- **[FIPS Overview](./docs/fips-overview.md)** - FIPS 140-2/140-3 background
- **[Roadmap](./ROADMAP.md)** - Detailed project roadmap
- **[Contributing Guide](./CONTRIBUTING.md)** - How to contribute
- **[Security Policy](./SECURITY.md)** - Security practices and reporting

### Key Concepts

**Directory Structure:**
```
openssl/<openssl-version>/<os>/<os-version>/<runtime>/<runtime-version>/
└── fips-dockerfile          # Production-ready Dockerfile
└── fips_<version>.patch     # Runtime-specific patches
```

**Example:**
- `openssl/3.0.9/ubuntu/22.04/python/3.11/fips-dockerfile` - Python 3.11 on Ubuntu 22.04 with OpenSSL 3.0.9 FIPS

**Build Process:**
1. Download and patch runtime source code
2. Build OpenSSL with FIPS provider enabled
3. Configure FIPS module and generate configuration
4. Build runtime (Python/vLLM) against FIPS OpenSSL
5. Create minimal production image
6. Validate FIPS compliance

---

## 🔒 FIPS Scope and Limitations

### What This Project Provides

- ✅ Container images with FIPS-validated cryptographic modules
- ✅ Correct build and configuration patterns
- ✅ Validation tools to verify FIPS mode
- ✅ Documentation of FIPS requirements
- ✅ References to NIST CMVP certificates

### What You're Still Responsible For

- ⚠️ **Host OS FIPS compliance** - Underlying system must meet requirements
- ⚠️ **Kernel and hardware validation** - Host-level FIPS requirements
- ⚠️ **Kubernetes/orchestration configuration** - Platform-level controls
- ⚠️ **Application-level compliance** - Your code must use approved algorithms
- ⚠️ **Operational controls** - Security policies, access controls, audit logs
- ⚠️ **Certification and accreditation** - FedRAMP, DoD, etc. formal processes

### Important Notes

> **FIPS-enabled ≠ FIPS-compliant**
>
> These images provide FIPS-enabled cryptographic modules, but full FIPS compliance requires proper integration, configuration, and operational controls across your entire stack.

**References:**
- [NIST CMVP](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
- [FIPS 140-2 Standard](https://csrc.nist.gov/publications/detail/fips/140/2/final)
- [FIPS 140-3 Standard](https://csrc.nist.gov/publications/detail/fips/140/3/final)

---

## 🧪 Testing and Validation

### Run Validation Tests

```bash
# Test a Python FIPS image
./tests/python/chk-fips-python-imgs.sh <image-name>

# Test a vLLM FIPS image
./tests/vllm/chk-fips-vllm-img.sh <image-name>
```

### Validation Categories

Each test suite validates:
- FIPS module presence and configuration
- Cryptographic algorithm correctness
- Security policy enforcement
- Vulnerability scanning (Trivy)
- SBOM generation
- Container hardening

### CI/CD Validation

The GitHub Actions workflow (`.github/workflows/fips-security-scan.yml`) automatically:
1. Discovers all Dockerfiles in the repository
2. Builds each image in isolated environments
3. Runs comprehensive FIPS validation tests
4. Generates compliance reports
5. Uploads artifacts for audit trails

**Trigger manually:**
```bash
# Via GitHub UI: Actions → FIPS Compliance Validation → Run workflow
# Or via gh CLI:
gh workflow run fips-security-scan.yml
```

---

## 🏢 Use Cases

This project is designed for organizations that:

- Need to run containerized workloads in **FedRAMP, DoD, or other regulated environments**
- Require **FIPS 140-2 or 140-3 validated cryptography** for compliance
- Want **reproducible, auditable builds** of FIPS-enabled base images
- Need to **reduce effort** in building and maintaining FIPS images
- Want **community-validated** FIPS implementations instead of vendor lock-in

### Example Scenarios

**Scenario 1: Government Cloud Deployment**
- Deploy Python microservices to FedRAMP Moderate environment
- Use Python FIPS images as base for application containers
- Validate FIPS mode in CI/CD pipeline
- Document cryptographic modules for ATO package

**Scenario 2: Healthcare Data Processing**
- Run ML/LLM workloads (vLLM) processing HIPAA-regulated data
- Use vLLM FIPS images for inference servers
- Ensure all cryptographic operations use FIPS-approved algorithms
- Meet compliance requirements for data encryption

**Scenario 3: Financial Services**
- Deploy containerized applications in regulated financial environments
- Use FIPS images for payment processing systems
- Validate cryptographic strength for PCI DSS compliance
- Maintain audit trail of cryptographic module usage

---

## 🙏 Acknowledgments

This project builds on the work of:

- **OpenSSL Project** - FIPS-validated cryptographic modules
- **Python Software Foundation** - Python runtime
- **vLLM Community** - ML/LLM inference engine
- **Chainguard** - Minimal, secure base images (Wolfi)
- **Canonical** - Ubuntu FIPS modules
- **NIST CMVP** - FIPS validation standards

Special thanks to all contributors and early adopters helping shape this project!

---

## 📞 Support and Community

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions, ideas, and general discussion
- **Security Issues** - See [SECURITY.md](./SECURITY.md) for responsible disclosure

---

## 👥 Maintainers

- [@mannec24](https://github.com/mannec24)
- [@devopstoday11](https://github.com/devopstoday11)

---

## 📄 License

This project is licensed under the [Apache 2.0 License](./LICENSE).

---

## ⭐ Star This Repo

If you find this project useful, please star it to help others discover it!

**Together, we can make FIPS compliance accessible for everyone.** 🚀

