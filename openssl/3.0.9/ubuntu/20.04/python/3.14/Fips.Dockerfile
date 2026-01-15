########################################
# Patch stage: Download and extract Python source
########################################
FROM ubuntu:focal AS patch

ARG PYTHON_VERSION="3.14.0"

WORKDIR /fips

RUN apt-get update && apt-get install -y --no-install-recommends \
        tar=1.30+dfsg-7ubuntu0.20.04.4 \
        wget=1.20.3-1ubuntu2.1 \
        ca-certificates=20240203~20.04.1 \
        build-essential=12.8ubuntu1.1 \
    && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar -xzf Python-${PYTHON_VERSION}.tgz \
    && rm -f Python-${PYTHON_VERSION}.tgz \
    && rm -rf /var/lib/apt/lists/*

########################################
# Build stage: Build OpenSSL (FIPS), patch Python, build Python
########################################
FROM ubuntu:focal AS build

ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PYTHON_VERSION="3.14.0"

WORKDIR /fips

COPY --from=patch /fips/Python-${PYTHON_VERSION} ./Python-${PYTHON_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential=12.8ubuntu1.1 \
        curl=7.68.0-1ubuntu2.25 \
        ca-certificates=20240203~20.04.1 \
        libc6=2.31-0ubuntu9.18 \
        libgcc-s1=10.5.0-1ubuntu1~20.04 \
        libbz2-1.0=1.0.8-2 \
        libbz2-dev=1.0.8-2 \
        liblzma-dev=5.2.4-1ubuntu1.1 \
        libffi-dev=3.3-4 \
        libncurses5-dev=6.2-0ubuntu2.1 \
        libreadline-dev=8.0-4 \
        libsqlite3-dev=3.31.1-4ubuntu0.7 \
        libssl-dev=1.1.1f-1ubuntu2.24 \
        zlib1g-dev=1:1.2.11.dfsg-2ubuntu1.5 \
        wget=1.20.3-1ubuntu2.1 \
    && rm -rf /var/lib/apt/lists/*

# Build and install OpenSSL FIPS
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && tar -xzf openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_FIPS_VERSION} \
    && ./Configure linux-x86_64 \
         --prefix=/usr/local/ssl \
         --openssldir=/usr/local/ssl \
         --libdir=/usr/local/ssl/lib \
         shared enable-fips \
    && make depend \
    && make -j"$(nproc)" \
    && make install \
    && echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && ldconfig -v \
    && cd /fips \
    && rm -rf openssl-${OPENSSL_FIPS_VERSION} openssl-${OPENSSL_FIPS_VERSION}.tar.gz

# Configure OpenSSL FIPS provider
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

# Inline patching for MD5/FIPS fallback provider logic and build Python
RUN PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) \
    && cd Python-${PYTHON_VERSION} \
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
    && make -j"$(nproc)" \
    && make install \
    && echo "/opt/python-fips/lib" > /etc/ld.so.conf.d/python.conf \
    && ldconfig -v \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python

# Install pip/setuptools/wheel/cryptography (pinned)
RUN PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) \
    && /opt/python-fips/bin/python3 -m ensurepip \
    && /opt/python-fips/bin/python3 -m pip install --no-cache-dir \
         wheel==0.45.1 \
    && /opt/python-fips/bin/python3 -m pip install --no-cache-dir --upgrade \
         pip==25.3 \
         setuptools==80.9.0 \
    && CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
       CFLAGS="-I/usr/local/ssl/include" \
       LDFLAGS="-L/usr/local/ssl/lib" \
       /opt/python-fips/bin/python3 -m pip install --no-cache-dir \
         cryptography==46.0.3 \
    && ln -s -f /opt/python-fips/bin/pip${PYTHON_MAJOR_MINOR} /opt/python-fips/bin/pip \
    && rm -rf Python-${PYTHON_VERSION} \
    && find /opt/python-fips -depth \
       \( -name 'test' -o -name 'tests' -o -name '*.pyc' -o -name '*.pyo' -o -name 'idlelib' -o -name 'tkinter' \) \
       -exec rm -rf {} + \
    && strip --strip-unneeded /usr/local/ssl/bin/openssl /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR}

########################################
# Final stage: Minimal runtime
########################################
FROM ubuntu:focal

ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PYTHON_VERSION="3.14.0"

# Fix CVE-2025-4802: Update libc-bin and related packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates=20240203~20.04.1 \
        libc6=2.31-0ubuntu9.18 \
        libgcc-s1=10.5.0-1ubuntu1~20.04 \
        libffi7=3.3-4 \
        zlib1g=1:1.2.11.dfsg-2ubuntu1.5 \
    && apt-get upgrade -y libc-bin libc6 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /var/log/* \
    && find /usr/share -type f \( -name 'man' -o -name 'doc' -o -name 'locale' \) -exec rm -rf {} + \
    && apt-get clean

COPY --from=build /usr/local/ssl /usr/local/ssl
COPY --from=build /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf /etc/ld.so.conf.d/openssl-${OPENSSL_FIPS_VERSION}.conf
COPY --from=build /opt/python-fips /opt/python-fips
COPY --from=build /etc/ld.so.conf.d/python.conf /etc/ld.so.conf.d/python.conf

RUN PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python \
    && ln -s -f /opt/python-fips/bin/pip${PYTHON_MAJOR_MINOR} /opt/python-fips/bin/pip \
    && ldconfig -v

# Add non-root user and create /app directory with correct ownership
RUN adduser --disabled-password --gecos '' --uid 1001 appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

WORKDIR /app

ENV PATH=/opt/python-fips/bin:$PATH
ENV OPENSSL_FIPS=1

USER appuser
