# Contributing

Thank you for your interest in contributing to FIPS Container Images!
Contributions of all kinds are welcome: code, documentation, testing, and real-world feedback from regulated environments.

## How to get started

1. **Check open issues**  
   Look for issues labeled `good first issue`, `help wanted`, or for the runtime/OS you care about.

2. **Discuss significant changes**  
   For larger proposals (new language runtime, new OS family, major refactors), open a GitHub Discussion or issue first so we can agree on design and scope.

3. **Fork and create a branch**
git clone https://github.com/open-containers/fips-container-images.git
cd fips-container-images
git checkout -b feature/my-change

4. **Run checks locally**  
   - Lint Dockerfiles (Hadolint or equivalent if configured).
   - Run any available unit or integration tests.  
   - Build and locally verify that FIPS mode is correctly enabled for your image.

5. **Submit a pull request**  
   - Describe the motivation and what you changed.  
   - Include any relevant references (FIPS modules, OS docs, etc.).

## Code style and conventions

- Keep Dockerfiles **minimal and explicit** – no unnecessary packages or tools.
- Prefer **configuration via environment variables** and documented entrypoints over baked-in secrets or one-off hacks.
- Document any behavior that affects FIPS mode (for example `OPENSSL_CONF`, provider configuration, JVM flags).

## Adding a new image

When adding a new image (e.g., new OS or language version), include:

- A Dockerfile named clearly (for example `Dockerfile.python-3.12-ubuntu20.04`).
- Documentation in `docs/images/` describing usage and FIPS verification steps.
- CI configuration updates, if needed, so the image is built and scanned.
- A brief note in the CHANGELOG (if present) or release notes.

## Reporting bugs and feature requests

Please use GitHub Issues to report problems or suggest enhancements. Provide adequate details and steps to reproduce.

---

## Communication channels

Use GitHub Discussions or open an issue for questions or collaboration.

---

## Licensing

By contributing, you agree that your contributions are licensed under the Apache 2.0 license used by this project.
Please ensure that any third-party content or code you introduce is compatible with this license and that you respect all relevant intellectual property and copyright obligations.

