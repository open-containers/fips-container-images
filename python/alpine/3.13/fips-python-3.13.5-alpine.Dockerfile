# syntax=docker/dockerfile:1

###############################
# Stage 1: Build OpenSSL 3.0.9 with FIPS on Alpine
###############################
FROM alpine:3.20 AS openssl-build

ARG OPENSSL_VERSION=3.0.9
ARG PYTHON_VERSION=3.13.5
WORKDIR /build

# Install build dependencies for OpenSSL with SSL support
RUN apk add --no-cache \
    ca-certificates \
    ca-certificates-bundle \
    build-base \
    linux-headers \
    perl \
    wget \
 && update-ca-certificates \
 && rm -rf /var/cache/apk/*

# Build OpenSSL 3.0.9 with FIPS provider
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
 && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
 && rm openssl-${OPENSSL_VERSION}.tar.gz \
 && cd openssl-${OPENSSL_VERSION} \
 && ./Configure linux-x86_64 \
      --prefix=/usr/local/ssl \
      --openssldir=/usr/local/ssl \
      --libdir=/usr/local/ssl/lib \
      shared enable-fips \
 && make depend \
 && make -j"$(nproc)" \
 && make install_sw \
 && make install_fips

# Generate fipsmodule.cnf
RUN /usr/local/ssl/bin/openssl fipsinstall \
      -module /usr/local/ssl/lib/ossl-modules/fips.so \
      -out /usr/local/ssl/fipsmodule.cnf \
      -provider_name fips \
      -section_name fips_sect

# Create OpenSSL configuration with FIPS enabled
RUN cat > /usr/local/ssl/openssl.cnf <<'EOF'
config_diagnostics = 1
openssl_conf = openssl_init

.include /usr/local/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
base = base_sect
fips = fips_sect

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
EOF

# Validate OpenSSL FIPS installation
RUN /usr/local/ssl/bin/openssl version \
 && /usr/local/ssl/bin/openssl list -providers

# Download Python source here (before curl conflicts occur in next stage)
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz

###############################
# Stage 2: Build Python 3.13.5 with FIPS OpenSSL
###############################
FROM alpine:3.20 AS python-build

ARG PYTHON_VERSION=3.13.5
ARG OPENSSL_VERSION=3.0.9
WORKDIR /build

# Install Python build dependencies (without curl to avoid OpenSSL conflicts)
RUN apk add --no-cache \
    build-base \
    linux-headers \
    bzip2-dev \
    expat-dev \
    gdbm-dev \
    libffi-dev \
    libc-dev \
    ncurses-dev \
    readline-dev \
    sqlite-dev \
    xz-dev \
    zlib-dev \
 && rm -rf /var/cache/apk/*

# Copy OpenSSL FIPS build
COPY --from=openssl-build /usr/local/ssl /usr/local/ssl

# Copy pre-downloaded Python source
COPY --from=openssl-build /build/Python-${PYTHON_VERSION}.tgz .

# Extract Python source
RUN tar -xzf Python-${PYTHON_VERSION}.tgz \
 && rm Python-${PYTHON_VERSION}.tgz

# Set environment for OpenSSL linkage
ENV PATH="/usr/local/ssl/bin:$PATH"
ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/ssl/lib/ossl-modules
ENV LD_LIBRARY_PATH=/usr/local/ssl/lib
ENV LDFLAGS="-L/usr/local/ssl/lib -Wl,-rpath=/usr/local/ssl/lib"
ENV CPPFLAGS="-I/usr/local/ssl/include"
ENV PKG_CONFIG_PATH="/usr/local/ssl/lib/pkgconfig"

WORKDIR /build/Python-${PYTHON_VERSION}

# Patch Python _hashopenssl.c for FIPS fallback to default provider for MD5
RUN sed -i '/#if OPENSSL_VERSION_NUMBER >= 0x30000000L/a#include <openssl/provider.h>' Modules/_hashopenssl.c \
 && sed -i '/} _hashlibstate;/a\
\
static void try_load_default_provider(void) {\
#if OPENSSL_VERSION_NUMBER >= 0x30000000L\
    OPENSSL_init_crypto(OPENSSL_INIT_LOAD_CONFIG, NULL);\
    if (!OSSL_PROVIDER_available(NULL, "default")) {\
        OSSL_PROVIDER_load(NULL, "default");\
    }\
#endif\
}\
' Modules/_hashopenssl.c \
 && sed -i '/case Py_ht_evp_nosecurity:/,/break;/s/if (digest == NULL) {/if (digest == NULL) { try_load_default_provider(); /' Modules/_hashopenssl.c \
 && sed -i '/case Py_ht_evp_nosecurity:/a\
    try_load_default_provider();' Modules/_hashopenssl.c

# Configure and build Python with FIPS OpenSSL (with explicit RPATH for system libs)
RUN LDFLAGS="-L/usr/local/ssl/lib -L/usr/lib -Wl,-rpath=/opt/python-fips/lib -Wl,-rpath=/usr/local/ssl/lib -Wl,-rpath=/usr/lib -Wl,-rpath=/lib" \
    LD_LIBRARY_PATH="/usr/local/ssl/lib:/usr/lib" \
    CPPFLAGS="-I/usr/local/ssl/include" \
    ./configure \
      --enable-shared \
      --with-builtin-hashlib-hashes=blake2 \
      --prefix=/opt/python-fips \
      --with-openssl=/usr/local/ssl \
      --with-openssl-rpath=/usr/local/ssl/lib \
      --with-ssl-default-suites=openssl \
      --without-ensurepip \
 && make -j"$(nproc)" \
 && make install

# Install pip and cryptography package
RUN /opt/python-fips/bin/python3.13 -m ensurepip \
 && /opt/python-fips/bin/python3.13 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
 && CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
    CFLAGS="-I/usr/local/ssl/include" \
    LDFLAGS="-L/usr/local/ssl/lib" \
    /opt/python-fips/bin/python3.13 -m pip install --no-cache-dir cryptography \
 && ln -sf /opt/python-fips/bin/pip3.13 /opt/python-fips/bin/pip

# Strip binaries for smaller size
RUN strip --strip-unneeded /usr/local/ssl/bin/openssl /opt/python-fips/bin/python3.13 || true

# Clean up unnecessary files to reduce image size
RUN find /opt/python-fips -depth \
    \( -name 'test' -o -name 'tests' -o -name '*.pyc' -o -name '*.pyo' -o -name 'idlelib' -o -name 'tkinter' \) \
    -exec rm -rf {} +

###############################
# Stage 3: Minimal runtime with Alpine
###############################
FROM alpine:3.20 AS runtime

ARG OPENSSL_VERSION=3.0.9

# Install minimal runtime dependencies including zlib and apply security updates
RUN apk add --no-cache \
    ca-certificates \
    libffi \
    libgcc \
    libstdc++ \
    zlib \
    bzip2 \
    expat \
    gdbm \
    ncurses-libs \
    readline \
    sqlite-libs \
    xz-libs \
 && apk upgrade --no-cache \
 && rm -rf /var/cache/apk/*

# Copy OpenSSL with FIPS
COPY --from=openssl-build /usr/local/ssl /usr/local/ssl

# Copy Python with FIPS support
COPY --from=python-build /opt/python-fips /opt/python-fips

# Create symlinks for OpenSSL and Python
RUN ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl \
 && ln -sf /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
 && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python3 \
 && ln -sf /opt/python-fips/bin/python3.13 /usr/local/bin/python3 \
 && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python \
 && ln -sf /opt/python-fips/bin/pip3.13 /usr/bin/pip \
 && ln -sf /opt/python-fips/bin/pip3.13 /usr/local/bin/pip

# Fix zlib library paths for Python dynamic modules - copy system libs to Python lib directory
RUN mkdir -p /opt/python-fips/lib \
 && cp -L /usr/lib/libz.so* /opt/python-fips/lib/ 2>/dev/null || true \
 && cp -L /lib/libz.so* /opt/python-fips/lib/ 2>/dev/null || true \
 && cp -L /usr/lib/libbz2.so* /opt/python-fips/lib/ 2>/dev/null || true

# Set runtime environment variables with proper library paths
ENV PATH="/opt/python-fips/bin:/usr/local/ssl/bin:$PATH"
ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/ssl/lib/ossl-modules
ENV LD_LIBRARY_PATH=/opt/python-fips/lib:/usr/local/ssl/lib:/usr/lib:/lib
ENV OPENSSL_FIPS=1

# Create non-root user for security
RUN adduser -D -u 1001 -g '' appuser \
 && mkdir -p /app \
 && chown -R appuser:appuser /app

WORKDIR /app
USER appuser

