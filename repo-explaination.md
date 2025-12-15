# FIPS Container Images - Repository Structure Explanation

## Table of Contents
1. [Repository Overview](#repository-overview)
2. [Directory Structure](#directory-structure)
3. [Core Directories Deep Dive](#core-directories-deep-dive)
4. [Relationship: templates-dockerfiles ↔ openssl](#relationship-templates-dockerfiles--openssl)
5. [Relationship: tests ↔ openssl](#relationship-tests--openssl)
6. [Build Workflow](#build-workflow)
7. [Directory Naming Convention](#directory-naming-convention)

---

## Repository Overview

The **FIPS Container Images** repository is a community-driven library of OCI-compatible container images built for FIPS 140-2 and FIPS 140-3 regulated environments. The repository provides:

- **FIPS-compliant base images** with validated cryptographic modules
- **Reference Dockerfiles** showing correct FIPS integration patterns
- **Validation test suites** ensuring FIPS compliance
- **Documentation and templates** for building custom FIPS images

### Project Philosophy

This is not a "just turn on FIPS mode" approach. Instead, it provides:
- Clear provenance and repeatable builds
- Audit-ready documentation
- Comprehensive testing for cryptographic compliance
- Multi-version, multi-OS support

---

## Directory Structure

```
fips-container-images/
├── .github/
│   └── workflows/
│       └── fips-security-scan.yml          # CI/CD workflow for automated validation
├── docs/
│   └── fips-overview.md                    # FIPS 140-2 documentation
├── templates-dockerfiles/
│   ├── fips-dockerfile-template            # Generic Dockerfile template
│   └── fips-build-config.txt               # Build configuration reference
├── openssl/
│   ├── 3.0.9/                              # OpenSSL version 3.0.9 (FIPS-validated)
│   │   ├── alpine/                         # Alpine Linux base
│   │   ├── ubuntu/                         # Ubuntu base
│   │   │   ├── 20.04/                      # Ubuntu 20.04 LTS
│   │   │   │   ├── python/
│   │   │   │   │   ├── 3.9/
│   │   │   │   │   │   ├── fips-dockerfile
│   │   │   │   │   │   └── fips_3.9.patch
│   │   │   │   │   ├── 3.10/
│   │   │   │   │   ├── 3.11/
│   │   │   │   │   └── ...
│   │   │   │   └── vllm/                   # ML/LLM runtime support
│   │   │   └── 22.04/                      # Ubuntu 22.04 LTS
│   │   │       └── python/
│   │   └── wolfi/                          # Wolfi Linux base
│   │       └── base/
│   │           ├── python/
│   │           └── vllm/
│   └── 3.1.2/                              # OpenSSL version 3.1.2
│       └── (similar structure)
├── tests/
│   ├── python/
│   │   └── chk-fips-python-imgs.sh         # Python FIPS validation suite
│   ├── vllm/
│   │   └── chk-fips-vllm-img.sh            # vLLM FIPS validation suite
│   └── nodejs/                              # (Planned)
├── insights/
│   ├── python/                              # Build insights & reports
│   ├── vllm/
│   └── nodejs/
├── CONTRIBUTING.md                          # Contribution guidelines
├── SECURITY.md                              # Security policy
├── ROADMAP.md                               # Project roadmap
└── README.md                                # Main documentation
```

---

## Core Directories Deep Dive

### 1. **templates-dockerfiles/**

**Purpose:** Reference templates and build configurations for creating FIPS-compliant container images.

**Contents:**
- **`fips-dockerfile-template`**: A fully parameterized, multi-stage Dockerfile showing best practices for:
  - Building OpenSSL with FIPS provider enabled
  - Patching Python source to work with FIPS OpenSSL
  - Compiling Python with FIPS-enabled OpenSSL
  - Configuring FIPS mode correctly
  - Creating minimal runtime images

- **`fips-build-config.txt`**: Configuration reference including:
  - Environment-specific configs (dev, prod, testing)
  - Version matrices for Python and OpenSSL
  - Package lists for build and runtime
  - Architecture-specific settings
  - Example build scripts

**Key Features of the Template:**
- Multi-stage build (patch → build → runtime)
- Parameterized ARG variables for flexibility
- Proper library path configuration
- FIPS module installation and configuration
- Security hardening (non-root user, minimal runtime packages)

### 2. **openssl/**

**Purpose:** Production-ready, version-specific Dockerfiles organized by OpenSSL version, OS, runtime, and version.

**Organizational Hierarchy:**
```
openssl/
└── <openssl-version>/        # e.g., 3.0.9, 3.1.2
    └── <os-family>/          # e.g., ubuntu, alpine, wolfi
        └── <os-version>/     # e.g., 20.04, 22.04, base
            └── <runtime>/    # e.g., python, vllm, nodejs
                └── <runtime-version>/  # e.g., 3.9, 3.11, 0.11.0
                    ├── fips-dockerfile
                    └── fips_<version>.patch
```

**What Each Directory Contains:**

1. **`fips-dockerfile`**: A complete, self-contained Dockerfile that:
   - Builds OpenSSL with FIPS provider for the specific version
   - Applies version-specific patches to the runtime (e.g., Python)
   - Compiles the runtime against FIPS-enabled OpenSSL
   - Configures FIPS mode activation
   - Creates a minimal, production-ready image
   - Pins exact package versions for reproducibility

2. **`fips_<version>.patch`**: Version-specific patches for the runtime:
   - **For Python**: Patches to ensure Python's SSL module works correctly with FIPS OpenSSL
   - Addresses compatibility issues between Python's build system and FIPS requirements
   - Ensures cryptographic operations use FIPS-approved algorithms

**Why Multiple Directories?**

Different combinations have different requirements:
- **OS differences**: Package managers (apt vs apk), package names, system libraries
- **Version compatibility**: OpenSSL 3.0.9 vs 3.1.2 have API differences
- **Runtime specifics**: Python 3.9 vs 3.11 need different patches
- **Reproducibility**: Pinned package versions for each OS/runtime combination

### 3. **tests/**

**Purpose:** Comprehensive validation suites to verify FIPS compliance of built images.

**Structure:**
```
tests/
├── python/
│   └── chk-fips-python-imgs.sh    # ~66KB comprehensive test suite
├── vllm/
│   └── chk-fips-vllm-img.sh       # ~15KB vLLM-specific tests
└── nodejs/                         # (Planned)
```

**Test Suite Features** (using `chk-fips-python-imgs.sh` as example):

The validation script performs **15 categories** of FIPS compliance tests:

1. **Module Identification & Configuration**: Verify OpenSSL FIPS provider is installed and configured
2. **Power-On Self-Tests (POST)**: Ensure FIPS module passes initialization tests
3. **Cryptographic Algorithm Validation**: Test approved algorithms (AES, SHA, RSA, ECDSA)
4. **Key Generation & Management**: Validate key generation using FIPS-approved methods
5. **Approved vs Non-Approved Operations**: Ensure non-approved algorithms are rejected
6. **Error States & Boundary Conditions**: Test error handling and edge cases
7. **Security Policy Compliance**: Verify FIPS security policies are enforced
8. **Operational Environment**: Check library paths, configurations, environment variables
9. **Zeroization & Data Protection**: Ensure sensitive data is properly cleared
10. **Compliance Verification**: Verify FIPS mode is active and enforced
11. **Performance & Resource Management**: Basic performance checks
12. **Container Image Security Posture**: Image hardening verification
13. **Audit Trail & Documentation**: Check for required documentation and logs
14. **Vulnerability Scanning**: Uses Trivy for CVE scanning
15. **SBOM Generation**: Creates Software Bill of Materials

**Test Methodology:**
- Runs tests inside the container using `docker run`
- Uses standard FIPS verification commands
- Generates detailed pass/fail reports with colored output
- Creates compliance reports for audits
- Exit code indicates overall FIPS compliance status

---

## Relationship: templates-dockerfiles ↔ openssl

### **From Template to Production**

The relationship is **template → instantiation**:

```
templates-dockerfiles/fips-dockerfile-template
              ↓
         (customize for specific versions/OS)
              ↓
openssl/<version>/<os>/<runtime>/<version>/fips-dockerfile
```

### **How They Relate:**

1. **Template is Generic**:
   - Uses ARG variables for all version numbers
   - Works with any base image
   - Provides the architectural pattern
   - Example:
     ```dockerfile
     ARG BASE_IMAGE="cgr.dev/chainguard/wolfi-base:latest"
     ARG PYTHON_VERSION="3.9.19"
     ARG OPENSSL_FIPS_VERSION="3.1.2"
     ```

2. **openssl/ Files are Specific**:
   - Hard-coded versions for reproducibility
   - OS-specific package names and versions
   - Exact package version pins
   - Example from `openssl/3.0.9/ubuntu/22.04/python/3.11/fips-dockerfile`:
     ```dockerfile
     FROM ubuntu:22.04 AS patch
     ARG PYTHON_VERSION="3.11.9"
     ARG OPENSSL_FIPS_VERSION="3.0.9"
     RUN apt-get install -y --no-install-recommends \
         build-essential=12.9ubuntu3 \
         wget=1.21.2-2ubuntu1.1 \
         ca-certificates=20240203~22.04.1
     ```

### **Development Workflow:**

1. **Start with template**: New contributors use `templates-dockerfiles/` as a reference
2. **Create specific version**: Copy and customize for target OS/runtime/version
3. **Pin dependencies**: Replace variables with exact versions
4. **Test thoroughly**: Use test suites to validate
5. **Commit to openssl/**: Add to the appropriate directory hierarchy

### **Key Differences:**

| Aspect | templates-dockerfiles/ | openssl/ |
|--------|------------------------|----------|
| **Purpose** | Reference & learning | Production builds |
| **Versions** | Parameterized (ARG) | Hard-coded & pinned |
| **Testing** | Conceptual | Validated in CI |
| **Packages** | Generic names | Exact version pins |
| **Maintenance** | Updated for patterns | Updated for security patches |

### **Example Transformation:**

**Template** (`templates-dockerfiles/fips-dockerfile-template`):
```dockerfile
ARG BUILD_PACKAGES="build-base ca-certificates wget patch perl..."
RUN apk add --no-cache ${BUILD_PACKAGES}
```

**Production** (`openssl/3.0.9/ubuntu/22.04/python/3.11/fips-dockerfile`):
```dockerfile
RUN apt-get install -y --no-install-recommends \
    build-essential=12.9ubuntu3 \
    ca-certificates=20240203~22.04.1 \
    wget=1.21.2-2ubuntu1.1 \
    patchutils=0.4.2-1build2
```

---

## Relationship: tests ↔ openssl

### **Validation and Compliance Loop**

The relationship is **build → validate**:

```
openssl/<version>/<os>/<runtime>/<version>/fips-dockerfile
              ↓ (docker build)
         fips-python-3.11-img
              ↓ (test)
tests/python/chk-fips-python-imgs.sh
              ↓
       FIPS Compliance Report
```

### **How They Relate:**

1. **openssl/ Produces Images**:
   - Each `fips-dockerfile` builds a FIPS-compliant image
   - Images claim to be FIPS-compliant
   - Need validation to prove compliance

2. **tests/ Validates Images**:
   - Test scripts verify FIPS compliance claims
   - Run comprehensive test suites against built images
   - Generate compliance reports for audits
   - Ensure images meet NIST FIPS 140-2 requirements

### **Test Execution Flow:**

```bash
# 1. Build image from openssl/ directory
cd openssl/3.0.9/ubuntu/22.04/python/3.11/
docker build -f fips-dockerfile -t fips-python-3.11-img .

# 2. Run validation test
cd ../../../../tests/python/
./chk-fips-python-imgs.sh fips-python-3.11-img

# 3. Review compliance report
# Script outputs detailed pass/fail results
# Generates artifacts for audit trail
```

### **What Tests Verify:**

For each image built from `openssl/`, the test suites verify:

1. **Build Correctness**:
   - ✓ OpenSSL FIPS provider is installed at correct path
   - ✓ Python is linked against FIPS OpenSSL
   - ✓ Environment variables are set correctly
   - ✓ Configuration files exist and are valid

2. **FIPS Functionality**:
   - ✓ FIPS module passes power-on self-tests
   - ✓ Approved algorithms work (AES-256, SHA-256, etc.)
   - ✓ Non-approved algorithms are blocked
   - ✓ FIPS mode cannot be disabled

3. **Security Posture**:
   - ✓ No critical vulnerabilities (via Trivy)
   - ✓ Minimal attack surface
   - ✓ Proper user permissions
   - ✓ No unnecessary packages

4. **Audit Requirements**:
   - ✓ SBOM can be generated
   - ✓ Module versions are documented
   - ✓ NIST certificate references exist

### **Integration with CI/CD:**

The `.github/workflows/fips-security-scan.yml` workflow orchestrates this relationship:

```yaml
jobs:
  discover-dockerfiles:
    # Finds all fips-dockerfile files in openssl/

  build-and-scan:
    # Builds each Dockerfile found
    # Runs quick vulnerability scan

  fips-validation:
    # Runs comprehensive tests from tests/
    # Uses appropriate test script for runtime type
    # Generates compliance reports

  final-summary:
    # Aggregates all validation results
    # Creates audit-ready summary
```

### **Test Script Selection:**

The test suite is **runtime-specific**:

| Runtime | Test Script | Image Path Pattern |
|---------|-------------|-------------------|
| Python | `tests/python/chk-fips-python-imgs.sh` | `openssl/*/python/*/fips-dockerfile` |
| vLLM | `tests/vllm/chk-fips-vllm-img.sh` | `openssl/*/vllm/*/fips-dockerfile` |
| Node.js | `tests/nodejs/chk-fips-nodejs-imgs.sh` | `openssl/*/nodejs/*/fips-dockerfile` |

### **Continuous Validation:**

1. **On every commit**: CI runs tests against changed Dockerfiles
2. **Daily schedule**: All images tested for new CVEs
3. **Pull requests**: Validation must pass before merge
4. **Manual trigger**: Can test specific Dockerfile patterns

### **Feedback Loop:**

```
openssl/ Dockerfile → Build Image → Test → FAIL
                         ↓                    ↓
                      PASS                Fix Dockerfile
                         ↓                    ↓
                   Merge to main ← Retest ← Update
```

---

## Build Workflow

### **Complete Lifecycle:**

```
1. DESIGN PHASE
   ↓
   templates-dockerfiles/
   - Study reference patterns
   - Understand FIPS requirements
   - Learn multi-stage build approach

2. IMPLEMENTATION PHASE
   ↓
   openssl/<version>/<os>/<runtime>/<version>/
   - Create specific Dockerfile
   - Add version-specific patches
   - Pin all dependencies
   - Test locally

3. VALIDATION PHASE
   ↓
   tests/<runtime>/
   - Run comprehensive validation
   - Generate compliance reports
   - Fix any failures
   - Document results

4. CI/CD AUTOMATION
   ↓
   .github/workflows/fips-security-scan.yml
   - Automated builds
   - Continuous validation
   - Security scanning
   - SBOM generation

5. DOCUMENTATION
   ↓
   insights/<runtime>/
   - Store build reports
   - Track compliance history
   - Document issues and fixes
```

---

## Directory Naming Convention

### **openssl/ Hierarchy Explained:**

```
openssl/
└── <openssl-version>     # OpenSSL FIPS module version
    └── <os-family>       # Operating system family
        └── <os-version>  # Specific OS release
            └── <runtime> # Programming language/runtime
                └── <runtime-version>  # Runtime version number
```

### **Examples with Reasoning:**

1. **`openssl/3.0.9/ubuntu/22.04/python/3.11/`**
   - OpenSSL 3.0.9 (FIPS-validated module)
   - Ubuntu 22.04 LTS (stable base)
   - Python 3.11 (specific runtime version)

2. **`openssl/3.0.9/wolfi/base/vllm/0.11.1/`**
   - OpenSSL 3.0.9
   - Wolfi Linux (minimal, supply-chain secured)
   - vLLM 0.11.1 (ML/LLM runtime)

3. **`openssl/3.1.2/alpine/3.2.1/python/3.13/`**
   - OpenSSL 3.1.2 (newer FIPS module)
   - Alpine 3.2.1 (minimal image)
   - Python 3.13 (latest Python)

### **Why This Structure?**

1. **Version Isolation**: Different OpenSSL versions may require different build approaches
2. **OS Dependencies**: Package names and versions vary across OS families
3. **Reproducibility**: Full path uniquely identifies every dependency combination
4. **Compliance Tracking**: Easy to track which images are validated for which environments
5. **Parallel Development**: Teams can work on different combinations independently

---

## Summary

### **Key Relationships:**

1. **templates-dockerfiles → openssl**:
   - Template provides the **pattern**
   - openssl/ contains **specific implementations**
   - Relationship: **Abstraction → Concrete**

2. **openssl → tests**:
   - openssl/ **builds** FIPS images
   - tests/ **validates** FIPS compliance
   - Relationship: **Producer → Consumer/Validator**

3. **All directories → CI/CD**:
   - GitHub Actions orchestrates the entire workflow
   - Automated discovery, building, testing, reporting
   - Relationship: **Components → Integrated System**

### **Development Process:**

```
New FIPS Image Request
    ↓
Study templates-dockerfiles/
    ↓
Create openssl/<version>/<os>/<runtime>/<version>/
    ↓
Run tests/<runtime>/ validation
    ↓
Commit → CI validates → Merge → Production
```

### **For Contributors:**

- **Start here**: `templates-dockerfiles/` for learning FIPS patterns
- **Implement here**: `openssl/` for production Dockerfiles
- **Validate here**: `tests/` to ensure compliance
- **Document here**: `docs/` and inline comments

### **For Users:**

- **Find images**: Browse `openssl/` for your stack
- **Build images**: Use the `fips-dockerfile` in your target directory
- **Verify compliance**: Run appropriate test script from `tests/`
- **Contribute back**: Share improvements and new combinations

---

## Additional Resources

- **FIPS Overview**: `docs/fips-overview.md`
- **Contribution Guide**: `CONTRIBUTING.md`
- **Security Policy**: `SECURITY.md`
- **Project Roadmap**: `ROADMAP.md`
- **Main README**: `README.md`

---

*This explanation document is maintained as part of the FIPS Container Images project. For questions or clarifications, please open an issue or discussion on GitHub.*
