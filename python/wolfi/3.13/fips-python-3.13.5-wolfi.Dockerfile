# Patch stage: Download and extract Python source
FROM cgr.dev/chainguard/wolfi-base:latest AS patch

ARG PYTHON_VERSION="3.13.5"

WORKDIR /fips

RUN apk add --no-cache \
    ca-certificates \
    wget \
    && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar -xzf Python-${PYTHON_VERSION}.tgz \
    && rm -f Python-${PYTHON_VERSION}.tgz

# Build stage: Build OpenSSL (FIPS), patch Python, build Python
FROM cgr.dev/chainguard/wolfi-base:latest AS build

ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PYTHON_VERSION="3.13.5"

WORKDIR /fips

COPY --from=patch /fips/Python-${PYTHON_VERSION} ./Python-${PYTHON_VERSION}

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    wget \
    curl \
    perl \
    bzip2-dev \
    libffi-dev \
    ncurses-dev \
    readline-dev \
    sqlite-dev \
    xz-dev \
    zlib-dev \
    gdbm-dev \
    linux-headers

# Build FIPS-enabled OpenSSL
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && tar -xzf openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_FIPS_VERSION} \
    && ./Configure linux-x86_64 \
        --prefix=/usr/local/ssl \
        --openssldir=/usr/local/ssl \
        --libdir=/usr/local/ssl/lib \
        shared \
        enable-fips \
    && make depend \
    && make -j$(nproc) \
    && make install \
    && echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf \
    && mkdir -p /usr/local/bin \
    && ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -sf /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && ldconfig -v \
    && cd .. \
    && rm -rf openssl-${OPENSSL_FIPS_VERSION}.tar.gz openssl-${OPENSSL_FIPS_VERSION}

# Configure OpenSSL for FIPS mode
RUN cat > /usr/local/ssl/openssl.cnf <<'EOF'
openssl_conf = openssl_init

.include /usr/local/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
fips = fips_sect
base = base_sect

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
EOF

# Inline patching for MD5/FIPS fallback provider logic using sed
RUN cd Python-${PYTHON_VERSION} \
    && sed -i '/#if OPENSSL_VERSION_NUMBER >= 0x30000000L/a#include <openssl/provider.h>' Modules/_hashopenssl.c \
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
    try_load_default_provider();' Modules/_hashopenssl.c \
    && LDFLAGS="-L/usr/local/lib/ -L/usr/local/lib64/ -Wl,-rpath=/opt/python-fips/lib" \
       LD_LIBRARY_PATH="/usr/local/lib/:/usr/local/lib64/" \
       CPPFLAGS="-I/usr/local/include -I/usr/local/ssl/include" \
       ./configure \
        --enable-shared \
        --enable-optimizations \
        --with-builtin-hashlib-hashes=blake2 \
        --prefix=/opt/python-fips \
        --with-openssl=/usr/local/ssl \
        --with-openssl-rpath=/usr/local/ssl/lib \
        --with-ssl-default-suites=openssl \
        --without-ensurepip \
    && make -j$(nproc) \
    && make install \
    && echo "/opt/python-fips/lib" > /etc/ld.so.conf.d/python.conf \
    && ldconfig -v \
    && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.13 /usr/local/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python

# Install pip and cryptography with FIPS support
RUN /opt/python-fips/bin/python3 -m ensurepip \
    && /opt/python-fips/bin/python3 -m pip install --no-cache-dir wheel \
    && /opt/python-fips/bin/python3 -m pip install --no-cache-dir --upgrade pip setuptools \
    && CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
       CFLAGS="-I/usr/local/ssl/include" \
       LDFLAGS="-L/usr/local/ssl/lib" \
       /opt/python-fips/bin/python3 -m pip install --no-cache-dir cryptography \
    && ln -sf /opt/python-fips/bin/pip3.13 /opt/python-fips/bin/pip \
    && rm -rf Python-${PYTHON_VERSION} \
    && find /opt/python-fips -depth \
       \( -name 'test' -o -name 'tests' -o -name '*.pyc' -o -name '*.pyo' \
          -o -name 'idlelib' -o -name 'tkinter' -o -name '__pycache__' \) \
       -exec rm -rf {} + \
    && strip --strip-unneeded /usr/local/ssl/bin/openssl /opt/python-fips/bin/python3.13 2>/dev/null || true

# Final stage: Minimal runtime with Wolfi
FROM cgr.dev/chainguard/wolfi-base:latest

ARG OPENSSL_FIPS_VERSION="3.0.9"

# Install only runtime dependencies from Wolfi (no CVE-prone packages)
RUN apk add --no-cache \
    ca-certificates \
    glibc \
    libgcc \
    libffi \
    zlib \
    bzip2 \
    xz \
    readline \
    sqlite-libs \
    ncurses \
    gdbm

# Copy compiled artifacts from build stage (includes /usr/local/bin with symlinks)
COPY --from=build /usr/local/ssl /usr/local/ssl
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf
COPY --from=build /opt/python-fips /opt/python-fips
COPY --from=build /etc/ld.so.conf.d/python.conf /etc/ld.so.conf.d/python.conf

# Configure library paths and remaining symlinks
RUN ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.13 /usr/bin/python \
    && ldconfig -v

# Add non-root user and create /app directory with correct ownership
RUN addgroup -g 1001 appuser \
    && adduser -D -u 1001 -G appuser appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

WORKDIR /app

# Set environment variables
ENV PATH=/opt/python-fips/bin:$PATH \
    OPENSSL_CONF=/usr/local/ssl/openssl.cnf \
    OPENSSL_FIPS=1 \
    LD_LIBRARY_PATH=/usr/local/ssl/lib:/opt/python-fips/lib

USER appuser

CMD ["python3"]

