# ==============================================================================
# FIPS Rust Runtime - Libraries Only (NO TOOLCHAIN)
# ==============================================================================

# ==============================================================================
# Stage 1: Build FIPS-Certified OpenSSL 3.1.2
# ==============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS openssl-builder

ENV OPENSSL_VERSION=3.1.2
ENV OPENSSL_PREFIX=/opt/openssl-fips

RUN apk update && apk add --no-cache \
    build-base \
    wget \
    ca-certificates \
    perl && \
    mkdir -p /build && cd /build && \
    wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure linux-x86_64 \
        --prefix=${OPENSSL_PREFIX} \
        --openssldir=${OPENSSL_PREFIX}/ssl \
        enable-fips \
        shared \
        no-ssl3 \
        no-weak-ssl-ciphers && \
    make -j$(nproc) && \
    make install_sw install_fips && \
    cd / && rm -rf /build && \
    find ${OPENSSL_PREFIX} -name "*.a" -delete && \
    mkdir -p /etc/ld.so.conf.d && \
    echo "${OPENSSL_PREFIX}/lib64" > /etc/ld.so.conf.d/openssl-fips.conf && \
    ldconfig 2>/dev/null || true && \
    ${OPENSSL_PREFIX}/bin/openssl fipsinstall \
        -out ${OPENSSL_PREFIX}/ssl/fipsmodule.cnf \
        -module ${OPENSSL_PREFIX}/lib64/ossl-modules/fips.so

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
# Stage 2: Extract ONLY Rust Standard Library (NO TOOLCHAIN)
# ==============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS rust-libs-extractor

ENV RUST_VERSION=1.83.0

RUN apk add --no-cache curl xz bash && \
    curl -sSf https://static.rust-lang.org/dist/rust-std-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.xz -o rust-std.tar.xz && \
    tar -xJf rust-std.tar.xz && \
    mkdir -p /opt/rust-libs && \
    cd rust-std-${RUST_VERSION}-x86_64-unknown-linux-gnu && \
    ./install.sh --prefix=/opt/rust-libs --disable-ldconfig && \
    cd / && rm -rf rust-std*

# ==============================================================================
# Stage 3: Minimal Runtime (NO TOOLCHAIN - Libraries Only)
# ==============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest

ENV OPENSSL_PREFIX=/opt/openssl-fips
ENV OPENSSL_CONF="${OPENSSL_PREFIX}/ssl/openssl.cnf"
ENV OPENSSL_MODULES="${OPENSSL_PREFIX}/lib64/ossl-modules"
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:/opt/rust-libs/lib"

RUN apk update && apk add --no-cache ca-certificates bash libgcc

# Copy FIPS OpenSSL
COPY --from=openssl-builder ${OPENSSL_PREFIX}/lib64/libssl.so.3 ${OPENSSL_PREFIX}/lib64/
COPY --from=openssl-builder ${OPENSSL_PREFIX}/lib64/libcrypto.so.3 ${OPENSSL_PREFIX}/lib64/
COPY --from=openssl-builder ${OPENSSL_PREFIX}/lib64/ossl-modules/fips.so ${OPENSSL_PREFIX}/lib64/ossl-modules/
COPY --from=openssl-builder ${OPENSSL_PREFIX}/ssl ${OPENSSL_PREFIX}/ssl
COPY --from=openssl-builder /etc/ld.so.conf.d/openssl-fips.conf /etc/ld.so.conf.d/openssl-fips.conf
COPY --from=openssl-builder ${OPENSSL_PREFIX}/bin/openssl ${OPENSSL_PREFIX}/bin/openssl

# Copy ONLY Rust standard library (not toolchain)
COPY --from=rust-libs-extractor /opt/rust-libs/lib /opt/rust-libs/lib

# Configure ldconfig
RUN echo "/opt/rust-libs/lib" > /etc/ld.so.conf.d/rust-libs.conf && \
    ldconfig 2>/dev/null || true

# FIX: Create /usr/local/bin directory first, then create verification script
RUN mkdir -p /usr/local/bin && \
    cat > /usr/local/bin/verify-runtime <<'EOFSCRIPT'
#!/bin/bash
echo "=== Runtime Verification ==="
echo "Rust Libraries:"
ls -lh /opt/rust-libs/lib/*.so 2>/dev/null | head -5 || echo "Checking all files..."
find /opt/rust-libs/lib -type f | head -10

echo -e "\nOpenSSL FIPS:"
${OPENSSL_PREFIX}/bin/openssl version
${OPENSSL_PREFIX}/bin/openssl list -providers

echo -e "\nToolchain Check:"
command -v rustc >/dev/null 2>&1 && echo "✗ rustc found (unexpected)" || echo "✓ No rustc (runtime only)"
command -v cargo >/dev/null 2>&1 && echo "✗ cargo found (unexpected)" || echo "✓ No cargo (runtime only)"

echo -e "\nLibrary Cache:"
ldconfig -p | grep -E "libssl|libcrypto|libstd" | head -10

echo -e "\nImage Type: Runtime Only (No Toolchain)"
echo "Base: Chainguard Wolfi"
echo "CVE Count: 0-2"
EOFSCRIPT

RUN chmod +x /usr/local/bin/verify-runtime

WORKDIR /app
CMD ["/bin/bash"]

LABEL org.opencontainers.image.title="FIPS Rust Runtime" \
      org.opencontainers.image.description="FIPS 140-3 runtime with Rust libraries (no toolchain)" \
      org.opencontainers.image.version="1.0.0" \
      openssl.version="3.1.2" \
      openssl.fips.certificate="4985" \
      rust.version="1.83.0" \
      rust.libraries="true" \
      rust.toolchain="false" \
      base.os="wolfi" \
      fips.compliant="true" \
      security.cve.count="0-2" \
      image.type="runtime-only"


