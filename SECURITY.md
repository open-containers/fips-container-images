# Security Policy

Security and compliance are central to the FIPS Container Images project.

## Reporting a vulnerability

If you discover a security issue in this repository or in a published image:

- Do **not** open a public GitHub issue with sensitive details.  
- Instead, send an email to `<security-contact@example.org>` (replace with actual contact) with:
  - A description of the issue and potential impact.  
  - Steps to reproduce, if available.  
  - Any relevant logs or output.

The maintainers will acknowledge your report and coordinate remediation as quickly as possible, while respecting coordinated disclosure practices.

## Supported images and policies

The project aims to:

- Maintain FIPS-oriented images on supported base distributions as long as upstream vendors provide FIPS-validated modules and security updates.
- Regularly scan images for vulnerabilities using container security tools and triage findings with attention to compliance relevance.

Specific support windows per image family will be documented under `docs/images/` and, when applicable, in release notes.

## Image provenance

- Images are digitally signed or use content trust where possible to ensure authenticity.
- Consumers should verify images as part of their deployment pipelines.

## FIPS compliance notes

This project provides **FIPS-capable** container images that integrate FIPS-validated cryptographic modules from upstream vendors.
However:

- Only the upstream modules themselves are evaluated under FIPS 140-2 / 140-3, not this project as a whole.
- Full compliance depends on your complete system architecture, operational controls, and adherence to relevant standards.

## Responsible disclosure

We appreciate responsible disclosure and community help in keeping the project secure.

Consumers remain responsible for validating that their use of these images fits their regulatory and organizational requirements.

