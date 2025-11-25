# FIPS Container Images
FIPS Container Images is a community-driven library of OCI-compatible container images that are built, tested, and documented for use in FIPS 140-2 and FIPS 140-3 regulated environments. The goal is to give platform, security, and application teams a consistent way to consume FIPS-capable base images without having to reverse-engineer each vendor’s cryptographic story.

## Why this project exists
Running in a FIPS-regulated environment is more than just “turning on FIPS mode” inside a container. Teams need clear provenance, repeatable builds, and audit-ready documentation of which cryptographic modules are present, how they are configured, and how images are kept patched over time.

This project focuses on:

- Curated base images with FIPS-validated crypto modules (for example OpenSSL FIPS provider and Java FIPS providers where available)
- Opinionated Dockerfiles and build scripts that enable FIPS mode correctly per language/runtime.
- Attestations and SBOMs that make audits and security reviews easier.

> **Important:** Using a FIPS-capable image does not, by itself, make your system FIPS compliant. Correct integration, host configuration, and operational controls are still required.

## Supported stacks

Planned language/runtime support:

- Python  
- Node.js  
- Go  
- Rust  
- Java  
- .NET  
- C / C++  
- vLLM and other ML/LLM runtimes

Planned base operating systems:

- Ubuntu (FIPS / Ubuntu Pro)  
- Wolfi Linux  
- Debian  
- Red Hat family (RHEL/UBI, later)

## Project goals

This repository aims to:

- Provide **minimal, auditable base images** for building FIPS-aware application containers.
- Demonstrate **reference Dockerfiles** for each language/runtime that correctly link against FIPS-validated crypto modules.  
- Supply **attestation artifacts** (SBOMs, FIPS module lists, certificate references) alongside published images.
- Integrate with **CI security scanning** to keep images as close to “near-zero known CVEs” as practical.

## Quick start

> The exact registry name, tags, and paths will depend on where you decide to publish (GitHub Container Registry, Docker Hub, etc.). Update examples once you have real tags.

### 1. Pull a base image

```bash
docker pull ghcr.io/open-containers/python-fips:3.12-ubuntu20.04
```

### 2. Build your app on top

```bash
FROM ghcr.io/open-containers/python-fips:3.12-ubuntu20.04

#Copy application code

WORKDIR /app
COPY . .

#Install dependencies as needed

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "main.py"]
```

### 3. Verify FIPS mode inside the container

Each base image ships with a small verification helper or documented command sequence to confirm that FIPS mode is active (for example using `openssl list -providers` or equivalent).

## FIPS scope and limitations

This project focuses on:

- Containers and their **cryptographic modules**, not on host kernel or hardware-level validation.
- Referencing **NIST CMVP certificates** where available, not issuing new certifications.

Consumers of these images are responsible for:

- Ensuring the underlying host OS, kernel, and hardware meet their compliance requirements.  
- Running containers only on approved platforms and configuring Kubernetes / orchestration layers accordingly.

## Roadmap

A high-level roadmap is maintained in [ROADMAP.md](./ROADMAP.md).
Community feedback and real-world requirements from FedRAMP, DoD, and other regulated environments are especially welcome.

## Contributing

Contributions are very welcome, especially in the following areas:

- New language/runtime stacks (for example additional Python or JVM variants).
- Additional base OS variants (for example STIG-hardened, CIS-hardened, or vendor-specific FIPS images).
- CI improvements, scanners, and policy as code.

See [CONTRIBUTING.md](./CONTRIBUTING.md) and [SECURITY.md](./SECURITY.md) before opening a pull request.

## Maintainers

- @mannec24  
- @devopstoday11

## License

This project is licensed under the [Apache 2.0 License](./LICENSE).  
