FIPS Compliance Overview

FIPS (Federal Information Processing Standards) compliance ensures that cryptographic modules and algorithms used in software meet rigorous U.S. government security standards for protecting sensitive data, such as those required by FedRAMP and other regulated environments.

​Key Requirements for FIPS-Compliant Docker Images

    Images must use cryptographic modules that are fully validated under FIPS 140-2 or FIPS 140-3 (such as OpenSSL FIPS Provider or Bouncy Castle for Java).
​
Avoid deprecated or insecure algorithms such as MD5, and use only approved ones (e.g., AES, SHA-2 family).

​Application code and dependencies should be built and configured to utilize FIPS-validated modules exclusively.

Documentation and signed attestations must be available to demonstrate the compliance status, including links to NIST CMVP certificates and information on the actual cryptographic components present in the image.

    ​
Building FIPS-Compliant Docker Images

    Choose a base image that is already FIPS-enabled or validated, or manually integrate FIPS-validated cryptographic modules.

    Ensure critical software (application runtimes, libraries) are compiled against or configured for FIPS mode.

    Run validation or self-test utilities (such as fipsinstall for OpenSSL) per-container to confirm FIPS mode is active.

​
Regularly scan images for CVEs and non-FIPS-approved cryptographic libraries, updating modules as necessary to maintain compliance.

​Attach any available official attestations or compliance documentation to images, and prepare them for audit readiness.

Verification and Audit Evidence

    Provide attestation files that list every FIPS-validated module, including NIST CMVP certificate numbers and expiration dates.

    Use container security scanning tools to confirm absence of non-compliant modules.

    Maintain signed audit records and supply evidence of the secure build and deployment processes.

Limitations and Responsibilities

Using a FIPS-compliant image does not guarantee full compliance; it also depends on correct integration and deployment practices in broader orchestrations such as Kubernetes and host configurations.
​
