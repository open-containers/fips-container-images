########################################
# Patch stage
########################################
FROM ubuntu:22.04 AS patch

ARG PYTHON_VERSION="3.10.13"

WORKDIR /fips

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential=12.9ubuntu3 \
        ca-certificates=20240203~22.04.1 \
        tar=1.34+dfsg-1ubuntu0.1.22.04.2 \
        wget=1.21.2-2ubuntu1.1 \
    && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar -xzf Python-${PYTHON_VERSION}.tgz \
    && rm -f Python-${PYTHON_VERSION}.tgz \
    && rm -rf /var/lib/apt/lists/*

########################################
# Build stage
########################################
FROM ubuntu:22.04 AS build

ARG OPENSSL_FIPS_VERSION="3.1.2"
ARG PYTHON_VERSION="3.10.13"

WORKDIR /fips

COPY --from=patch /fips/Python-${PYTHON_VERSION} ./Python-${PYTHON_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential=12.9ubuntu3 \
        curl=7.81.0-1ubuntu1.21 \
        ca-certificates=20240203~22.04.1 \
        libc6=2.35-0ubuntu3.11 \
        libgcc-s1=12.3.0-1ubuntu1~22.04.2 \
        libbz2-1.0=1.0.8-5build1 \
        libbz2-dev=1.0.8-5build1 \
        liblzma-dev=5.2.5-2ubuntu1 \
        libffi-dev=3.4.2-4 \
        libncurses5-dev=6.3-2ubuntu0.1 \
        libreadline-dev=8.1.2-1 \
        libsqlite3-dev=3.37.2-2ubuntu0.5 \
        libssl-dev=3.0.2-0ubuntu1.20 \
        zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 \
        wget=1.21.2-2ubuntu1.1 \
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
RUN printf '%s\n' \
    'openssl_conf = openssl_init' \
    '' \
    '.include /usr/local/ssl/fipsmodule.cnf' \
    '' \
    '[openssl_init]' \
    'providers = provider_sect' \
    'alg_section = algorithm_sect' \
    '' \
    '[provider_sect]' \
    'fips = fips_sect' \
    'base = base_sect' \
    '' \
    '[base_sect]' \
    'activate = 1' \
    '' \
    '[algorithm_sect]' \
    'default_properties = fips=yes' \
    > /usr/local/ssl/openssl.cnf

# Inline patching for MD5/FIPS fallback provider logic
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
    try_load_default_provider();' Modules/_hashopenssl.c

# Build and install Python against FIPS OpenSSL
RUN cd Python-${PYTHON_VERSION} \
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
    && PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python

# Install pip/setuptools/wheel/cryptography with pinned versions
RUN /opt/python-fips/bin/python3 -m ensurepip \
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
    && PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) \
    && ln -s -f /opt/python-fips/bin/pip${PYTHON_MAJOR_MINOR} /opt/python-fips/bin/pip \
    && cd /fips \
    && rm -rf Python-${PYTHON_VERSION} \
    && find /opt/python-fips -depth \
       \( -name 'test' -o -name 'tests' -o -name '*.pyc' -o -name '*.pyo' -o -name 'idlelib' -o -name 'tkinter' \) \
       -exec rm -rf {} + \
    && strip --strip-unneeded /usr/local/ssl/bin/openssl /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR}

########################################
# Final stage (runtime)
########################################
FROM ubuntu:22.04

ARG OPENSSL_FIPS_VERSION="3.1.2"
ARG PYTHON_VERSION="3.10.13"

# Ensure glibc and libs are updated/pinned
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates=20240203~22.04.1 \
        libc6=2.35-0ubuntu3.11 \
        libgcc-s1=12.3.0-1ubuntu1~22.04.2 \
        libffi7=3.3-5ubuntu1 \
        zlib1g=1:1.2.11.dfsg-2ubuntu9.2 \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /var/log/* \
    && find /usr/share -type f \( -name 'man' -o -name 'doc' -o -name 'locale' \) -exec rm -rf {} +

# Copy OpenSSL and Python from build stage
COPY --from=build /usr/local/ssl /usr/local/ssl
COPY --from=build /etc/ld.so.conf.d/openssl-3.1.2.conf /etc/ld.so.conf.d/openssl-3.1.2.conf
COPY --from=build /opt/python-fips /opt/python-fips
COPY --from=build /etc/ld.so.conf.d/python.conf /etc/ld.so.conf.d/python.conf

# Recreate symlinks and ldconfig
RUN PYTHON_MAJOR_MINOR=$(echo "3.10.13" | cut -d. -f1,2) \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -s -f /usr/local/ssl/bin/openssl /usr/local/bin/openssl \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3 \
    && ln -s -f /opt/python-fips/bin/python${PYTHON_MAJOR_MINOR} /usr/bin/python \
    && ln -s -f /opt/python-fips/bin/pip${PYTHON_MAJOR_MINOR} /opt/python-fips/bin/pip \
    && ldconfig -v

# Non-root user and app dir
RUN adduser --disabled-password --gecos '' --uid 1001 appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

WORKDIR /app

ENV PATH=/opt/python-fips/bin:$PATH
ENV OPENSSL_FIPS=1

USER appuser
