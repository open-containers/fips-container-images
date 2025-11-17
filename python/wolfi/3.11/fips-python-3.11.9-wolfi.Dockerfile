# Build stage - compile FIPS-enabled OpenSSL and Python
FROM cgr.dev/chainguard/wolfi-base:latest AS build

ARG PYTHON_VERSION="3.11.9"
ARG OPENSSL_FIPS_VERSION="3.0.9"
ARG PATCH_INCLUDE="fips_3.11.patch"

WORKDIR /build

# Install build dependencies from Wolfi repos (added perl for OpenSSL Configure)
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    wget \
    patch \
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

# Download and patch Python
COPY ${PATCH_INCLUDE} fips.patch
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar -xzf Python-${PYTHON_VERSION}.tgz \
    && cd Python-${PYTHON_VERSION} \
    && patch -p1 < ../fips.patch \
    && cd ..

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
    && /usr/local/ssl/bin/openssl fipsinstall \
        -out /usr/local/ssl/fipsmodule.cnf \
        -module /usr/local/ssl/lib/ossl-modules/fips.so \
    && cd .. \
    && rm -rf openssl-${OPENSSL_FIPS_VERSION}.tar.gz openssl-${OPENSSL_FIPS_VERSION}

# Configure OpenSSL for FIPS mode
RUN echo 'openssl_conf = openssl_init\n\
\n\
.include /usr/local/ssl/fipsmodule.cnf\n\
\n\
[openssl_init]\n\
providers = provider_sect\n\
alg_section = algorithm_sect\n\
\n\
[provider_sect]\n\
fips = fips_sect\n\
base = base_sect\n\
\n\
[base_sect]\n\
activate = 1\n\
\n\
[algorithm_sect]\n\
default_properties = fips=yes\n\
' > /usr/local/ssl/openssl.cnf

# Build Python with FIPS-enabled OpenSSL
RUN cd Python-${PYTHON_VERSION} \
    && LDFLAGS="-L/usr/local/ssl/lib -Wl,-rpath=/opt/python-fips/lib" \
       LD_LIBRARY_PATH="/usr/local/ssl/lib" \
       CPPFLAGS="-I/usr/local/ssl/include" \
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
    && cd .. \
    && rm -rf Python-${PYTHON_VERSION}

# Install pip and cryptography with FIPS support
RUN /opt/python-fips/bin/python3.11 -m ensurepip \
    && /opt/python-fips/bin/python3.11 -m pip install --no-cache-dir wheel \
    && /opt/python-fips/bin/python3.11 -m pip install --no-cache-dir --upgrade pip setuptools \
    && CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
       CFLAGS="-I/usr/local/ssl/include" \
       LDFLAGS="-L/usr/local/ssl/lib" \
       /opt/python-fips/bin/python3.11 -m pip install --no-cache-dir cryptography

# Strip binaries and remove unnecessary files
RUN find /opt/python-fips -depth \
    \( -name 'test' -o -name 'tests' -o -name '*.pyc' -o -name '*.pyo' \
       -o -name 'idlelib' -o -name 'tkinter' -o -name '__pycache__' \) \
    -exec rm -rf {} + \
    && strip --strip-unneeded /usr/local/ssl/bin/openssl /opt/python-fips/bin/python3.11 2>/dev/null || true

# Final stage - minimal runtime with Wolfi base
FROM cgr.dev/chainguard/wolfi-base:latest

ARG OPENSSL_FIPS_VERSION="3.0.9"

# Install only runtime dependencies from Wolfi
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
    ncurses

# Copy compiled OpenSSL and Python from build stage
COPY --from=build /usr/local/ssl /usr/local/ssl
COPY --from=build /opt/python-fips /opt/python-fips

# Configure library paths
RUN echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl-fips.conf \
    && echo "/opt/python-fips/lib" > /etc/ld.so.conf.d/python-fips.conf \
    && ldconfig

# Create symlinks
RUN ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/bin/python3 \
    && ln -sf /opt/python-fips/bin/python3.11 /usr/bin/python \
    && ln -sf /opt/python-fips/bin/pip3.11 /opt/python-fips/bin/pip

# Create non-root user and app directory
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

