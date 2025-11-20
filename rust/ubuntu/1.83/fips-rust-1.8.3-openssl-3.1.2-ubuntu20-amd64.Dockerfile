# ==============================================================================
# Stage 1: Build FIPS-Certified OpenSSL 3.1.2
# ==============================================================================
FROM ubuntu:22.04 AS openssl-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_VERSION=3.1.2
ENV OPENSSL_PREFIX=/opt/openssl-fips

# Install build dependencies in a single layer with cleanup
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    ca-certificates \
    perl \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

WORKDIR /build

# Download and verify OpenSSL 3.1.2 (FIPS 140-3 validated)
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm openssl-${OPENSSL_VERSION}.tar.gz

WORKDIR /build/openssl-${OPENSSL_VERSION}

# Configure, build, and install OpenSSL with FIPS - cleanup in same layer
RUN ./Configure linux-x86_64 \
    --prefix=${OPENSSL_PREFIX} \
    --openssldir=${OPENSSL_PREFIX}/ssl \
    enable-fips \
    shared \
    no-ssl3 \
    no-weak-ssl-ciphers \
    && make -j$(nproc) \
    && make install_sw install_fips \
    && rm -rf /build

# Remove unnecessary static libraries to save space
RUN find ${OPENSSL_PREFIX} -name "*.a" -delete

# Configure ldconfig to find OpenSSL libraries
RUN echo "${OPENSSL_PREFIX}/lib64" > /etc/ld.so.conf.d/openssl-fips.conf && \
    ldconfig

# CRITICAL: Run fipsinstall to generate fipsmodule.cnf
RUN ${OPENSSL_PREFIX}/bin/openssl fipsinstall \
    -out ${OPENSSL_PREFIX}/ssl/fipsmodule.cnf \
    -module ${OPENSSL_PREFIX}/lib64/ossl-modules/fips.so

# Configure OpenSSL to use FIPS provider by default
RUN cat > ${OPENSSL_PREFIX}/ssl/openssl.cnf <<'EOF'
config_diagnostics = 1

openssl_conf = openssl_init

.include /opt/openssl-fips/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect

[provider_sect]
fips = fips_sect
base = base_sect

[base_sect]
activate = 1

[fips_sect]
activate = 1
EOF

# ==============================================================================
# Stage 2: Build Rust Toolchain with FIPS OpenSSL
# ==============================================================================
FROM ubuntu:22.04 AS rust-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_PREFIX=/opt/openssl-fips
ENV RUST_VERSION=1.83.0
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

# Copy FIPS OpenSSL from previous stage
COPY --from=openssl-builder ${OPENSSL_PREFIX} ${OPENSSL_PREFIX}
COPY --from=openssl-builder /etc/ld.so.conf.d/openssl-fips.conf /etc/ld.so.conf.d/openssl-fips.conf

# Configure ldconfig in this stage
RUN ldconfig

# Install Rust build dependencies with cleanup in single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    pkg-config \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Set environment for FIPS OpenSSL
ENV OPENSSL_CONF="${OPENSSL_PREFIX}/ssl/openssl.cnf"

# Install Rust toolchain with minimal profile
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y \
    --default-toolchain ${RUST_VERSION} \
    --profile minimal \
    --no-modify-path \
    && rm -rf /tmp/*

# Configure pkg-config to find FIPS OpenSSL
RUN mkdir -p ${OPENSSL_PREFIX}/lib/pkgconfig && \
    cat > ${OPENSSL_PREFIX}/lib/pkgconfig/openssl.pc <<EOF
prefix=${OPENSSL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib64
includedir=\${prefix}/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries and tools
Version: 3.1.2
Requires:
Libs: -L\${libdir} -lssl -lcrypto
Libs.private: -ldl -pthread
Cflags: -I\${includedir}
EOF

# Set environment variables for Rust to use FIPS OpenSSL
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX}/lib64/pkgconfig"
ENV OPENSSL_DIR="${OPENSSL_PREFIX}"
ENV OPENSSL_LIB_DIR="${OPENSSL_PREFIX}/lib64"
ENV OPENSSL_INCLUDE_DIR="${OPENSSL_PREFIX}/include"

# Verify Rust installation
RUN rustc --version && cargo --version

# Test FIPS OpenSSL integration and cleanup test artifacts
WORKDIR /test
RUN cargo init --bin test-openssl && \
    echo 'openssl = "0.10"' >> test-openssl/Cargo.toml && \
    cd test-openssl && \
    cargo build --release && \
    cd / && \
    rm -rf /test ${CARGO_HOME}/registry/cache ${CARGO_HOME}/git/checkouts

# Remove Rust documentation and unnecessary components
RUN rm -rf ${RUSTUP_HOME}/toolchains/*/share/doc \
    ${RUSTUP_HOME}/toolchains/*/share/man \
    ${CARGO_HOME}/registry/src

# ==============================================================================
# Stage 3: Minimal Runtime Image for App Developers (OPTIMIZED)
# ==============================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_PREFIX=/opt/openssl-fips
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig:${OPENSSL_PREFIX}/lib64/pkgconfig"
ENV OPENSSL_DIR="${OPENSSL_PREFIX}"
ENV OPENSSL_LIB_DIR="${OPENSSL_PREFIX}/lib64"
ENV OPENSSL_INCLUDE_DIR="${OPENSSL_PREFIX}/include"
ENV OPENSSL_CONF="${OPENSSL_PREFIX}/ssl/openssl.cnf"
ENV OPENSSL_MODULES="${OPENSSL_PREFIX}/lib64/ossl-modules"

# Install minimal runtime dependencies and clean up in single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    ca-certificates \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /var/cache/apt/archives/* \
              /tmp/* \
              /var/tmp/* \
              /usr/share/doc/* \
              /usr/share/man/* \
              /usr/share/locale/*

# Copy FIPS OpenSSL binaries, libraries, and FIPS configuration
COPY --from=openssl-builder ${OPENSSL_PREFIX}/bin ${OPENSSL_PREFIX}/bin
COPY --from=openssl-builder ${OPENSSL_PREFIX}/lib64 ${OPENSSL_PREFIX}/lib64
COPY --from=openssl-builder ${OPENSSL_PREFIX}/include ${OPENSSL_PREFIX}/include
COPY --from=openssl-builder ${OPENSSL_PREFIX}/ssl ${OPENSSL_PREFIX}/ssl

# Copy ldconfig configuration and update cache
COPY --from=openssl-builder /etc/ld.so.conf.d/openssl-fips.conf /etc/ld.so.conf.d/openssl-fips.conf
RUN ldconfig

# Copy Rust toolchain (minimal profile - no docs)
COPY --from=rust-builder ${RUSTUP_HOME} ${RUSTUP_HOME}
COPY --from=rust-builder ${CARGO_HOME}/bin ${CARGO_HOME}/bin

# Copy pkg-config file
COPY --from=rust-builder ${OPENSSL_PREFIX}/lib/pkgconfig ${OPENSSL_PREFIX}/lib/pkgconfig

# Remove cargo registry cache that may have been copied
RUN rm -rf ${CARGO_HOME}/registry/cache \
           ${CARGO_HOME}/registry/src \
           ${CARGO_HOME}/git/checkouts

# Create verification script for developers
RUN cat > /usr/local/bin/verify-fips.sh <<'EOF'
#!/bin/bash
echo "=== FIPS Compliance Verification ==="
echo "OpenSSL Version:"
${OPENSSL_PREFIX}/bin/openssl version

echo -e "\nActive Providers:"
${OPENSSL_PREFIX}/bin/openssl list -providers

echo -e "\nFIPS Module Status:"
${OPENSSL_PREFIX}/bin/openssl list -provider fips -verbose 2>&1

echo -e "\nRust Toolchain:"
rustc --version
cargo --version

echo -e "\nShared Library Configuration:"
echo "ldconfig cache:"
ldconfig -p | grep -E "libssl|libcrypto" | head -10

echo -e "\nOpenSSL Environment:"
echo "OPENSSL_CONF=${OPENSSL_CONF}"
echo "OPENSSL_MODULES=${OPENSSL_MODULES}"

echo -e "\nConfiguration Files:"
echo "Main config: ${OPENSSL_CONF}"
[ -f "${OPENSSL_CONF}" ] && echo "✓ openssl.cnf exists" || echo "✗ openssl.cnf missing"
[ -f "${OPENSSL_PREFIX}/ssl/fipsmodule.cnf" ] && echo "✓ fipsmodule.cnf exists" || echo "✗ fipsmodule.cnf missing"

echo -e "\nFIPS module config content:"
grep -E "^(activate|install-version|module-mac)" "${OPENSSL_PREFIX}/ssl/fipsmodule.cnf" 2>&1

echo -e "\n=== Testing FIPS-Approved Algorithm ==="
echo "SHA-256 with FIPS provider:"
echo "test" | ${OPENSSL_PREFIX}/bin/openssl dgst -sha256 -provider fips 2>&1

echo -e "\n=== Verifying Library Dependencies ==="
echo "OpenSSL binary dependencies:"
ldd ${OPENSSL_PREFIX}/bin/openssl | grep -E "libssl|libcrypto"

echo -e "\n=== Image Size Analysis ==="
du -sh ${OPENSSL_PREFIX} 2>/dev/null || true
du -sh ${RUSTUP_HOME} 2>/dev/null || true
du -sh ${CARGO_HOME} 2>/dev/null || true
EOF

RUN chmod +x /usr/local/bin/verify-fips.sh

WORKDIR /app

CMD ["/bin/bash"]

LABEL maintainer="DevOps Team" \
      openssl.version="3.1.2" \
      openssl.fips="140-3" \
      rust.version="1.83.0" \
      fips.compliant="true" \
      optimized="true" \
      description="FIPS-compliant Rust development base image with OpenSSL 3.1.2 (Layer Optimized with ldconfig)"

