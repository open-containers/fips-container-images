# ------------------------------------------------------------------------------
# Stage 1: Patch Stage - Apply FIPS patches to Python source
# ------------------------------------------------------------------------------
FROM alpine:3.21 AS patch

ARG PYTHON_VERSION="3.11.9"
ARG PATCH_INCLUDE="fips_3.11.patch"

WORKDIR /fips

# Copy FIPS patch for Python
COPY ${PATCH_INCLUDE} fips.patch

# Install minimal tools for patching and downloading
RUN apk add --no-cache \
    ca-certificates \
    patch \
    tar \
    wget \
    && wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar -xzf Python-${PYTHON_VERSION}.tgz \
    && cd Python-${PYTHON_VERSION} \
    && patch -p1 < ../fips.patch \
    && cd .. \
    && rm -f Python-${PYTHON_VERSION}.tgz

# ------------------------------------------------------------------------------
# Stage 2: Build Stage - Compile OpenSSL FIPS and Python
# ------------------------------------------------------------------------------
FROM alpine:3.21 AS build

ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PYTHON_VERSION="3.11.9"

WORKDIR /fips

# Copy patched Python source from patch stage
COPY --from=patch /fips/Python-${PYTHON_VERSION} ./Python-${PYTHON_VERSION}

# Install build dependencies
# Note: Alpine uses musl-dev instead of glibc-dev
RUN apk add --no-cache \
    # Build tools
    build-base \
    gcc \
    g++ \
    make \
    perl \
    linux-headers \
    # Python build dependencies
    bzip2-dev \
    expat-dev \
    gdbm-dev \
    libffi-dev \
    libnsl-dev \
    libtirpc-dev \
    ncurses-dev \
    openssl-dev \
    readline-dev \
    sqlite-dev \
    tk-dev \
    xz-dev \
    zlib-dev \
    # Required for cryptography package
    cargo \
    rust \
    # Utilities
    ca-certificates \
    wget

# ------------------------------------------------------------------------------
# Build OpenSSL 3.0.9 with FIPS Provider (Certificate #4282)
# ------------------------------------------------------------------------------
RUN echo "==> Building OpenSSL ${OPENSSL_FIPS_VERSION} with FIPS module..." \
    && wget -q https://www.openssl.org/source/openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && tar -xzf openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_FIPS_VERSION} \
    # Configure OpenSSL with FIPS support
    # Using --prefix=/usr/local/ssl to avoid conflicts with system OpenSSL
    && ./Configure \
        linux-x86_64 \
        --prefix=/usr/local/ssl \
        --openssldir=/usr/local/ssl \
        --libdir=/usr/local/ssl/lib \
        shared \
        enable-fips \
        no-ssl3 \
        no-weak-ssl-ciphers \
    && make -j$(nproc) \
    && make install \
    # Install FIPS module
    && /usr/local/ssl/bin/openssl fipsinstall \
        -out /usr/local/ssl/fipsmodule.cnf \
        -module /usr/local/ssl/lib/ossl-modules/fips.so \
    && cd .. \
    && rm -rf openssl-${OPENSSL_FIPS_VERSION}.tar.gz openssl-${OPENSSL_FIPS_VERSION}

# ------------------------------------------------------------------------------
# Configure OpenSSL to use FIPS mode by default
# ------------------------------------------------------------------------------
RUN echo "==> Configuring OpenSSL for FIPS mode..." \
    && cat > /usr/local/ssl/openssl.cnf <<'EOF'
openssl_conf = openssl_init

.include /usr/local/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
fips = fips_sect
base = base_sect

[fips_sect]
activate = 1

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
EOF

# ------------------------------------------------------------------------------
# Build Python 3.11.9 with FIPS-enabled OpenSSL
# ------------------------------------------------------------------------------
RUN echo "==> Building Python ${PYTHON_VERSION} with FIPS OpenSSL..." \
    && cd Python-${PYTHON_VERSION} \
    && export PKG_CONFIG_PATH="/usr/local/ssl/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export LD_LIBRARY_PATH="/usr/local/ssl/lib:${LD_LIBRARY_PATH}" \
    && export LDFLAGS="-L/usr/local/ssl/lib -Wl,-rpath=/opt/python-fips/lib -Wl,-rpath=/usr/local/ssl/lib" \
    && export CPPFLAGS="-I/usr/local/ssl/include" \
    && export CFLAGS="-I/usr/local/ssl/include" \
    # Configure Python with custom OpenSSL and optimizations
    && ./configure \
        --prefix=/opt/python-fips \
        --enable-shared \
        --enable-optimizations \
        --with-lto \
        --with-builtin-hashlib-hashes=blake2 \
        --with-openssl=/usr/local/ssl \
        --with-openssl-rpath=/usr/local/ssl/lib \
        --with-ssl-default-suites=openssl \
        --without-ensurepip \
        --enable-ipv6 \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf Python-${PYTHON_VERSION}

# ------------------------------------------------------------------------------
# Install pip, setuptools, wheel, and cryptography with FIPS support
# ------------------------------------------------------------------------------
RUN echo "==> Installing Python packages with FIPS support..." \
    && export LD_LIBRARY_PATH="/usr/local/ssl/lib:/opt/python-fips/lib:${LD_LIBRARY_PATH}" \
    && export OPENSSL_CONF=/usr/local/ssl/openssl.cnf \
    # Install ensurepip
    && /opt/python-fips/bin/python3.11 -m ensurepip \
    # Upgrade pip and setuptools
    && /opt/python-fips/bin/python3.11 -m pip install --no-cache-dir \
        --upgrade pip setuptools wheel \
    # Install cryptography with FIPS-enabled OpenSSL
    # CRYPTOGRAPHY_DONT_BUILD_RUST=1 forces use of system OpenSSL
    && CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
       CFLAGS="-I/usr/local/ssl/include" \
       LDFLAGS="-L/usr/local/ssl/lib" \
       /opt/python-fips/bin/python3.11 -m pip install --no-cache-dir cryptography

# ------------------------------------------------------------------------------
# Optimize and clean up build artifacts
# ------------------------------------------------------------------------------
RUN echo "==> Optimizing Python installation..." \
    # Create symbolic links
    && ln -sf /opt/python-fips/bin/python3.11 /opt/python-fips/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.11 /opt/python-fips/bin/python \
    && ln -sf /opt/python-fips/bin/pip3.11 /opt/python-fips/bin/pip3 \
    && ln -sf /opt/python-fips/bin/pip3.11 /opt/python-fips/bin/pip \
    # Remove test files and cached bytecode to reduce size
    && find /opt/python-fips -depth \
        \( \
            -type d -name '__pycache__' -o \
            -type d -name 'test' -o \
            -type d -name 'tests' -o \
            -type f -name '*.pyc' -o \
            -type f -name '*.pyo' -o \
            -type f -name '*.a' \
        \) -exec rm -rf '{}' + \
    # Strip debug symbols from binaries
    && find /opt/python-fips -type f -name '*.so' -exec strip --strip-unneeded '{}' \; 2>/dev/null || true \
    && strip --strip-unneeded /opt/python-fips/bin/python3.11 2>/dev/null || true \
    && strip --strip-unneeded /usr/local/ssl/bin/openssl 2>/dev/null || true

# ------------------------------------------------------------------------------
# Stage 3: Final Runtime Stage - Minimal Alpine with FIPS Python
# ------------------------------------------------------------------------------
FROM alpine:3.21

ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PYTHON_VERSION="3.11.9"

LABEL maintainer="DevOps Team" \
      description="FIPS-compliant Python ${PYTHON_VERSION} on Alpine Linux with OpenSSL ${OPENSSL_FIPS_VERSION}" \
      org.opencontainers.image.title="Python FIPS Alpine" \
      org.opencontainers.image.description="FIPS 140-2 compliant Python runtime on Alpine Linux" \
      org.opencontainers.image.version="${PYTHON_VERSION}" \
      org.opencontainers.image.vendor="Your Organization"

# Install minimal runtime dependencies and apply security updates
RUN apk add --no-cache \
    # Essential runtime libraries
    ca-certificates \
    libffi \
    libbz2 \
    libgcc \
    libstdc++ \
    ncurses-libs \
    readline \
    sqlite-libs \
    xz-libs \
    zlib \
    # Required for cryptography at runtime
    libssl3 \
    libcrypto3 \
    && apk upgrade --no-cache \
    # Clean up
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Copy OpenSSL with FIPS module from build stage
COPY --from=build /usr/local/ssl /usr/local/ssl

# Copy Python installation from build stage
COPY --from=build /opt/python-fips /opt/python-fips

# ------------------------------------------------------------------------------
# Configure runtime environment
# ------------------------------------------------------------------------------
# Create symbolic links for easy access
RUN ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/local/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/bin/python \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/local/bin/python \
    && ln -sf /opt/python-fips/bin/pip3 /usr/bin/pip3 \
    && ln -sf /opt/python-fips/bin/pip3 /usr/local/bin/pip3 \
    && ln -sf /opt/python-fips/bin/pip /usr/bin/pip \
    && ln -sf /opt/python-fips/bin/pip /usr/local/bin/pip

# ------------------------------------------------------------------------------
# Security: Create non-root user for running applications
# ------------------------------------------------------------------------------
RUN addgroup -g 1001 -S appuser \
    && adduser -u 1001 -S appuser -G appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

# ------------------------------------------------------------------------------
# Environment variables
# ------------------------------------------------------------------------------
ENV PATH=/opt/python-fips/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # OpenSSL FIPS configuration
    OPENSSL_CONF=/usr/local/ssl/openssl.cnf \
    OPENSSL_FIPS=1 \
    OPENSSL_MODULES=/usr/local/ssl/lib/ossl-modules \
    LD_LIBRARY_PATH=/usr/local/ssl/lib:/opt/python-fips/lib

# Set working directory
WORKDIR /app

# Switch to non-root user
USER appuser

