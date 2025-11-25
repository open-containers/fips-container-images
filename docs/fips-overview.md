# FIPS in Container Images

This document provides a practical overview of FIPS 140-2 and 140-3 considerations in the context of container images.

## What is FIPS 140-2 / 140-3?

FIPS 140-2 and 140-3 are U.S. government standards that define security requirements for cryptographic modules protecting sensitive information.
Vendors submit modules (such as OpenSSL FIPS providers or Java crypto providers) to NIST for validation, and NIST publishes certificates through the Cryptographic Module Validation Program (CMVP).

## Containers and FIPS

In containerized environments, FIPS considerations typically include:

- Ensuring that the container’s cryptographic libraries are **FIPS-validated versions** and are used exclusively for cryptographic operations.  
- Avoiding non-approved algorithms (for example MD5) in favor of approved ones like AES and SHA-2 families.
- Making sure that FIPS mode is **enabled and verified** inside each running container.

Because containers are portable and can run on many hosts, it is also necessary to consider host OS FIPS support, kernel configuration, and platform policies.

## What this project provides

This project does **not** provide new FIPS modules or certifications.
Instead, it:

- Combines upstream FIPS-validated modules into curated base images.
- Documents how to confirm that FIPS mode is active for each runtime.
- Supplies attestation materials (SBOMs, module lists, certificate references) to simplify audits.

Users should always review upstream documentation and NIST CMVP listings for the specific module versions in use.

## Common pitfalls

- Enabling OpenSSL FIPS mode globally without verifying dependent libraries.  
- Using non-validated cryptographic modules bundled in application dependencies.  
- Running containers on non-FIPS-compliant hosts or kernels.

---

## Glossary

- **Cryptographic Module:** Software/hardware implementing cryptographic functions.  
- **FIPS Mode:** Operation mode enabling only FIPS-validated algorithms.  
- **NIST CMVP:** National Institute of Standards and Technology Cryptographic Module Validation Program.  

---

## Additional resources

- [NIST CMVP Portal](https://csrc.nist.gov/projects/cryptographic-module-validation-program)  
- [OpenSSL FIPS Module Documentation](https://www.openssl.org/docs/fips.html)  
- [FedRAMP Security Standards](https://www.fedramp.gov)  


## Intellectual property and copyright

All documentation and code in this repository are provided under the Apache 2.0 license.
When referencing vendor products, certificates, or trademarks, this project respects their respective intellectual property rights and encourages users to do the same, including consulting original vendor documentation for authoritative details.

