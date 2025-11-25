# Roadmap

This roadmap tracks planned coverage and priorities for the FIPS Container Images project.

The roadmap is aspirational and may change based on community feedback and upstream FIPS module availability.

## Guiding principles

- Prioritize **minimal images** with explicit FIPS story over large convenience images.
- Start with **high-demand stacks** (Python, Java, .NET, Go, vLLM) commonly used in regulated workloads.
- Focus on **high-impact language stacks** used in regulated environments.
- Align with **upstream vendor FIPS offerings** where possible (Ubuntu Pro FIPS, RHEL/UBI, Chainguard FIPS images, etc.).

## Phase 1 – Foundations (MVP)

**Goal:** Provide a small but complete set of base images with end-to-end documentation and verification.

Targets:

- OS:
  - Ubuntu 20.04 / 22.04 with FIPS-enabled OpenSSL packages.
  - Wolfi Linux FIPS base images where available.
- Languages/runtimes:
  - Python (one current LTS version).
  - Go (one current LTS release).
  - Rust (runtime-only image for precompiled binaries).

Deliverables:

- Reference Dockerfiles under root (e.g., `Dockerfile.python-ubuntu`, `Dockerfile.go-wolfi`).
- Image-specific docs under `docs/images/` including FIPS verification steps.
- Automated builds + vulnerability scanning in CI.

## Phase 2 – Application stacks & ML

**Goal:** Extend coverage to JVM, .NET, and ML runtimes relevant to regulated workloads.

Targets:

- Java (OpenJDK with FIPS-capable crypto providers).
- .NET (on supported Linux distributions with FIPS-enabled crypto).
- Node.js and C/C++ base images.
- vLLM and other LLM runtimes on FIPS-capable bases.

Deliverables:

- Per-runtime documentation on integrating with FIPS modules (e.g., how to ensure a JVM uses FIPS providers).
- Example “hello world” apps that assert FIPS mode is active at runtime.

## Phase 3 – Hardened profiles and policies

**Goal:** Aim for more complete compliance stories for customers pursuing FedRAMP, DoD IL, and similar frameworks.

Targets:

- Hardened variants (e.g., STIG/CIS-aligned base layers where available).
- Policy as code (e.g., OPA/Conftest rules to enforce FIPS image usage in Kubernetes).
- Additional attestations (SLSA levels, SBOMs, VEX statements where practical).

Community feedback is encouraged through GitHub Issues and Discussions.

## Risks and dependencies

- Dependence on upstream FIPS module vendors for ongoing support  
- Alignment with OS vendor update cadence and security advisories  
- Community adoption affecting momentum and usage

