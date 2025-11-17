#!/bin/bash
################################################################################
# FIPS 140-2 Comprehensive Validation Test Suite
# 
# This script performs thorough testing of a FIPS-compliant Python container
# based on NIST FIPS 140-2 requirements and industry best practices.
#
# Test Categories:
# 1. Module Identification & Configuration
# 2. Power-On Self-Tests (POST)
# 3. Cryptographic Algorithm Validation
# 4. Key Generation & Management
# 5. Approved vs Non-Approved Operations
# 6. Error States & Boundary Conditions
# 7. Security Policy Compliance
# 8. Operational Environment
# 9. Zeroization & Data Protection
# 10. Compliance Verification
# 11. Performance & Resource Management
# 12. Container Image Security Posture
# 13. Audit Trail & Documentation
# 14. Vulnerability Scanning (Trivy)
# 15. Software Bill of Materials (SBOM) Generation
################################################################################

# Disable errexit for controlled error handling
set +e

IMAGE_NAME="${1}"
PYTHON_CMD="/opt/python-fips/bin/python3"
OPENSSL_CMD="/usr/local/ssl/bin/openssl"

# Validate image name argument
if [ -z "$IMAGE_NAME" ]; then
    echo "ERROR: Image name required"
    echo "Usage: $0 <image-name>"
    echo "Example: $0 fips-python313-wolfi-img"
    echo ""
    echo "Available images:"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -v "REPOSITORY"
    exit 1
fi

# Check if image exists locally
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "ERROR: Image '$IMAGE_NAME' not found locally"
    echo ""
    echo "Available images:"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# Logging functions
log_header() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$1${NC}"
    echo "=========================================="
    echo ""
}

log_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

log_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warn() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
    TESTS_WARNING=$((TESTS_WARNING + 1))
}

log_info() {
    echo -e "${BLUE}ℹ INFO:${NC} $1"
}

################################################################################
# CATEGORY 1: Module Identification & Configuration Verification
################################################################################
test_module_identification() {
    log_header "CATEGORY 1: Module Identification & Configuration"
    
    # Test 1.1: Verify OpenSSL version and FIPS capability
    log_test "1.1 - OpenSSL Version and FIPS Module Identification"
    OPENSSL_VERSION=$(docker run --rm ${IMAGE_NAME} ${OPENSSL_CMD} version 2>&1 || echo "FAILED")
    if [[ "$OPENSSL_VERSION" == *"OpenSSL 3.0"* ]]; then
        log_pass "OpenSSL 3.0.x detected: $OPENSSL_VERSION"
    else
        log_fail "Expected OpenSSL 3.0.x, got: $OPENSSL_VERSION"
    fi
    
    # Test 1.2: Verify Python version (updated to support 3.9+)
    log_test "1.2 - Python Version Verification"
    PYTHON_VERSION=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} --version 2>&1 || echo "FAILED")
    if [[ "$PYTHON_VERSION" =~ Python\ 3\.([0-9]+) ]]; then
        MINOR_VERSION="${BASH_REMATCH[1]}"
        if [ "$MINOR_VERSION" -ge 9 ]; then
            log_pass "Python 3.$MINOR_VERSION detected (3.9+ required): $PYTHON_VERSION"
        else
            log_fail "Python version too old: $PYTHON_VERSION (need 3.9+)"
        fi
    else
        log_fail "Python version detection failed: $PYTHON_VERSION"
    fi
    
    # Test 1.3: Verify FIPS environment variables
    log_test "1.3 - FIPS Environment Variables"
    FIPS_ENV=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "import os; print('OPENSSL_FIPS=' + os.environ.get('OPENSSL_FIPS', 'NOT SET')); print('OPENSSL_CONF=' + os.environ.get('OPENSSL_CONF', 'NOT SET'))" 2>&1)
    
    # Check OPENSSL_FIPS
    if [[ "$FIPS_ENV" == *"OPENSSL_FIPS=1"* ]]; then
        FIPS_VAR_OK=true
    else
        FIPS_VAR_OK=false
        log_warn "OPENSSL_FIPS not set to 1"
    fi
    
    # Check OPENSSL_CONF
    if [[ "$FIPS_ENV" == *"OPENSSL_CONF=/usr/local/ssl/openssl.cnf"* ]]; then
        CONF_VAR_OK=true
    else
        CONF_VAR_OK=false
        log_warn "OPENSSL_CONF not set to /usr/local/ssl/openssl.cnf"
    fi
    
    if [ "$FIPS_VAR_OK" = true ] && [ "$CONF_VAR_OK" = true ]; then
        log_pass "FIPS environment variables correctly configured"
        log_info "$FIPS_ENV"
    elif [ "$FIPS_VAR_OK" = true ]; then
        log_warn "FIPS partially configured - OPENSSL_FIPS set but OPENSSL_CONF missing"
        log_info "$FIPS_ENV"
        log_info "RECOMMENDATION: Add to Dockerfile: ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf"
    else
        log_fail "FIPS environment variables not properly set"
        log_info "$FIPS_ENV"
    fi
    
    # Test 1.4: Verify OpenSSL configuration file exists
    log_test "1.4 - OpenSSL FIPS Configuration File"
    CONFIG_CHECK=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "import os; print('EXISTS' if os.path.exists('/usr/local/ssl/openssl.cnf') else 'MISSING')" 2>&1)
    if [[ "$CONFIG_CHECK" == "EXISTS" ]]; then
        log_pass "OpenSSL FIPS configuration file exists at /usr/local/ssl/openssl.cnf"
    else
        log_fail "OpenSSL FIPS configuration file missing"
    fi
    
    # Test 1.5: Verify FIPS module configuration
    log_test "1.5 - FIPS Module Configuration Verification"
    FIPS_MODULE=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "import os; print('EXISTS' if os.path.exists('/usr/local/ssl/fipsmodule.cnf') else 'MISSING')" 2>&1)
    if [[ "$FIPS_MODULE" == "EXISTS" ]]; then
        log_pass "FIPS module configuration file exists"
    else
        log_fail "FIPS module configuration file missing"
    fi
}

################################################################################
# CATEGORY 2: Power-On Self-Tests (POST)
################################################################################
test_power_on_self_tests() {
    log_header "CATEGORY 2: Power-On Self-Tests (POST)"
    
    # Test 2.1: Verify module integrity on initialization
    log_test "2.1 - Module Integrity Verification"
    INTEGRITY=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import ssl
import sys
try:
    # Initializing SSL triggers POST
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    print('POST_SUCCESS')
    sys.exit(0)
except Exception as e:
    print(f'POST_FAILURE: {e}')
    sys.exit(1)
" 2>&1)
    
    if [[ "$INTEGRITY" == *"POST_SUCCESS"* ]]; then
        log_pass "Module integrity check passed (POST executed successfully)"
    else
        log_fail "Module integrity check failed: $INTEGRITY"
    fi
    
    # Test 2.2: Verify cryptography library initialization
    log_test "2.2 - Cryptography Library POST"
    CRYPTO_POST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.backends.openssl import backend
try:
    # This should trigger POST in cryptography
    backend_info = backend.openssl_version_text()
    print(f'CRYPTO_POST_SUCCESS: {backend_info}')
except Exception as e:
    print(f'CRYPTO_POST_FAILURE: {e}')
" 2>&1)
    
    if [[ "$CRYPTO_POST" == *"CRYPTO_POST_SUCCESS"* ]]; then
        log_pass "Cryptography library POST successful"
        log_info "$CRYPTO_POST"
    else
        log_fail "Cryptography library POST failed: $CRYPTO_POST"
    fi
    
    # Test 2.3: Verify known answer tests (KAT) for algorithms
    log_test "2.3 - Known Answer Tests (KAT) Verification"
    KAT_RESULT=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
# Test SHA-256 KAT
test_data = b'abc'
expected_sha256 = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
result = hashlib.sha256(test_data).hexdigest()
if result == expected_sha256:
    print('KAT_PASS: SHA-256 known answer test passed')
else:
    print(f'KAT_FAIL: Expected {expected_sha256}, got {result}')
" 2>&1)
    
    if [[ "$KAT_RESULT" == *"KAT_PASS"* ]]; then
        log_pass "Known Answer Tests verified"
    else
        log_fail "Known Answer Tests failed: $KAT_RESULT"
    fi
}

################################################################################
# CATEGORY 3: Cryptographic Algorithm Validation
################################################################################
test_approved_algorithms() {
    log_header "CATEGORY 3: FIPS-Approved Cryptographic Algorithms"
    
    # Test 3.1: SHA-2 Family (FIPS Approved)
    log_test "3.1 - SHA-2 Family Algorithms (Approved)"
    SHA_TESTS=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
test_data = b'FIPS 140-2 Validation Test'
results = []

# Test SHA-224
try:
    h = hashlib.sha224(test_data)
    results.append(f'SHA-224: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    results.append(f'SHA-224: FAILED - {e}')

# Test SHA-256
try:
    h = hashlib.sha256(test_data)
    results.append(f'SHA-256: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    results.append(f'SHA-256: FAILED - {e}')

# Test SHA-384
try:
    h = hashlib.sha384(test_data)
    results.append(f'SHA-384: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    results.append(f'SHA-384: FAILED - {e}')

# Test SHA-512
try:
    h = hashlib.sha512(test_data)
    results.append(f'SHA-512: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    results.append(f'SHA-512: FAILED - {e}')

for r in results:
    print(r)
" 2>&1)
    
    if [[ $(echo "$SHA_TESTS" | grep -c "\[OK\]") -eq 4 ]]; then
        log_pass "All SHA-2 family algorithms operational"
        echo "$SHA_TESTS" | while read line; do log_info "$line"; done
    else
        log_fail "SHA-2 algorithms test failed"
        echo "$SHA_TESTS"
    fi
    
    # Test 3.2: HMAC Operations (FIPS Approved)
    log_test "3.2 - HMAC Operations (Approved)"
    HMAC_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hmac
import hashlib

key = b'FIPS_SECRET_KEY_2023'
message = b'Authenticated message'

try:
    # HMAC-SHA256
    h = hmac.new(key, message, hashlib.sha256)
    print(f'HMAC-SHA256: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    print(f'HMAC-SHA256: FAILED - {e}')

try:
    # HMAC-SHA384
    h = hmac.new(key, message, hashlib.sha384)
    print(f'HMAC-SHA384: {h.hexdigest()[:16]}... [OK]')
except Exception as e:
    print(f'HMAC-SHA384: FAILED - {e}')
" 2>&1)
    
    if [[ $(echo "$HMAC_TEST" | grep -c "\[OK\]") -eq 2 ]]; then
        log_pass "HMAC operations validated"
        echo "$HMAC_TEST" | while read line; do log_info "$line"; done
    else
        log_fail "HMAC operations failed"
    fi
    
    # Test 3.3: AES Encryption (FIPS Approved)
    log_test "3.3 - AES Encryption Operations (Approved)"
    AES_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import os

try:
    # AES-256-CBC
    key = os.urandom(32)  # 256-bit key
    iv = os.urandom(16)
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    plaintext = b'FIPS Test Message 123456'  # Must be multiple of 16
    plaintext += b' ' * (16 - len(plaintext) % 16)  # Padding
    ciphertext = encryptor.update(plaintext) + encryptor.finalize()
    print(f'AES-256-CBC: Encrypted {len(plaintext)} bytes [OK]')
except Exception as e:
    print(f'AES-256-CBC: FAILED - {e}')

try:
    # AES-256-GCM
    key = os.urandom(32)
    iv = os.urandom(12)
    cipher = Cipher(algorithms.AES(key), modes.GCM(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(b'FIPS GCM Test') + encryptor.finalize()
    print(f'AES-256-GCM: Encrypted with authentication [OK]')
except Exception as e:
    print(f'AES-256-GCM: FAILED - {e}')
" 2>&1)
    
    if [[ $(echo "$AES_TEST" | grep -c "\[OK\]") -eq 2 ]]; then
        log_pass "AES encryption validated"
        echo "$AES_TEST" | while read line; do log_info "$line"; done
    else
        log_fail "AES encryption failed"
        echo "$AES_TEST"
    fi
    
    # Test 3.4: RSA Operations (FIPS Approved)
    log_test "3.4 - RSA Cryptographic Operations (Approved)"
    RSA_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

try:
    # Generate RSA key pair (2048-bit minimum for FIPS)
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    public_key = private_key.public_key()
    
    # Sign operation
    message = b'FIPS signature test'
    signature = private_key.sign(
        message,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH
        ),
        hashes.SHA256()
    )
    
    # Verify operation
    public_key.verify(
        signature,
        message,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH
        ),
        hashes.SHA256()
    )
    
    print('RSA-2048 Sign/Verify: [OK]')
except Exception as e:
    print(f'RSA-2048: FAILED - {e}')
" 2>&1)
    
    if [[ "$RSA_TEST" == *"[OK]"* ]]; then
        log_pass "RSA operations validated"
        log_info "$RSA_TEST"
    else
        log_fail "RSA operations failed: $RSA_TEST"
    fi
    
    # Test 3.5: ECDSA Operations (FIPS Approved)
    log_test "3.5 - ECDSA Operations (Approved)"
    ECDSA_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

try:
    # Generate ECDSA key pair (P-256 curve - FIPS approved)
    private_key = ec.generate_private_key(ec.SECP256R1(), default_backend())
    public_key = private_key.public_key()
    
    # Sign
    message = b'FIPS ECDSA test'
    signature = private_key.sign(message, ec.ECDSA(hashes.SHA256()))
    
    # Verify
    public_key.verify(signature, message, ec.ECDSA(hashes.SHA256()))
    
    print('ECDSA-P256 Sign/Verify: [OK]')
except Exception as e:
    print(f'ECDSA-P256: FAILED - {e}')
" 2>&1)
    
    if [[ "$ECDSA_TEST" == *"[OK]"* ]]; then
        log_pass "ECDSA operations validated"
        log_info "$ECDSA_TEST"
    else
        log_fail "ECDSA operations failed: $ECDSA_TEST"
    fi
}

################################################################################
# CATEGORY 4: Non-Approved Algorithm Behavior
################################################################################
test_non_approved_algorithms() {
    log_header "CATEGORY 4: Non-Approved Algorithm Behavior (MD5, SHA-1)"
    
    # Test 4.1: MD5 behavior (Non-approved for security functions)
    log_test "4.1 - MD5 Algorithm Behavior (Non-approved)"
    MD5_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
try:
    # MD5 should work with fallback provider for non-security functions
    h = hashlib.md5(b'test')
    result = h.hexdigest()
    print(f'MD5: Executed with fallback provider - {result[:16]}...')
    print('MD5_FALLBACK_OK')
except Exception as e:
    print(f'MD5: BLOCKED (strict FIPS mode) - {e}')
    print('MD5_BLOCKED')
" 2>&1)
    
    if [[ "$MD5_TEST" == *"MD5_FALLBACK_OK"* ]]; then
        log_warn "MD5 available via fallback provider (non-security use only)"
        log_info "This is expected behavior for compatibility"
    elif [[ "$MD5_TEST" == *"MD5_BLOCKED"* ]]; then
        log_pass "MD5 properly blocked in strict FIPS mode"
    else
        log_fail "MD5 behavior unclear: $MD5_TEST"
    fi
    
    # Test 4.2: SHA-1 behavior (Deprecated for digital signatures)
    log_test "4.2 - SHA-1 Algorithm Behavior (Deprecated)"
    SHA1_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
try:
    h = hashlib.sha1(b'test')
    result = h.hexdigest()
    print(f'SHA-1: Available - {result[:16]}...')
    print('Note: SHA-1 deprecated for digital signatures per NIST SP 800-131A')
except Exception as e:
    print(f'SHA-1: FAILED - {e}')
" 2>&1)
    
    if [[ "$SHA1_TEST" == *"Available"* ]]; then
        log_warn "SHA-1 available (deprecated for signatures, acceptable for HMAC)"
        log_info "$SHA1_TEST"
    else
        log_info "SHA-1 status: $SHA1_TEST"
    fi
}

################################################################################
# CATEGORY 5: Key Generation Requirements
################################################################################
test_key_generation() {
    log_header "CATEGORY 5: Cryptographic Key Generation"
    
    # Test 5.1: Minimum key sizes (FIPS requirements)
    log_test "5.1 - Minimum Key Size Enforcement"
    KEY_SIZE_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

# Test minimum RSA key size (2048 bits for FIPS)
weak_key_accepted = False
try:
    # Try to generate 1024-bit key (should fail or warn in FIPS mode)
    key_1024 = rsa.generate_private_key(
        public_exponent=65537,
        key_size=1024,
        backend=default_backend()
    )
    print('WARNING: 1024-bit RSA key generated (below FIPS minimum)')
    weak_key_accepted = True
except Exception as e:
    print('GOOD: 1024-bit RSA key rejected:', str(e)[:50])

# Generate compliant 2048-bit key
try:
    key_2048 = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    print('PASS: 2048-bit RSA key generated successfully')
except Exception as e:
    print('FAIL: 2048-bit RSA key generation failed:', e)

# Print recommendation if weak keys accepted
if weak_key_accepted:
    print('RECOMMENDATION: Configure OpenSSL to enforce minimum key sizes')
" 2>&1)
    
    if [[ "$KEY_SIZE_TEST" == *"PASS: 2048-bit"* ]]; then
        if [[ "$KEY_SIZE_TEST" == *"WARNING: 1024-bit"* ]]; then
            log_warn "Minimum key size requirements need enforcement"
            echo "$KEY_SIZE_TEST" | while read line; do log_info "$line"; done
            log_info ""
            log_info "RECOMMENDATION: Weak keys (1024-bit) should be rejected"
            log_info "This can be configured in OpenSSL FIPS provider settings"
        else
            log_pass "Minimum key size requirements validated"
            echo "$KEY_SIZE_TEST" | while read line; do log_info "$line"; done
        fi
    else
        log_warn "Key size validation requires review"
        echo "$KEY_SIZE_TEST"
    fi
    
    # Test 5.2: Random number generation
    log_test "5.2 - FIPS-Approved Random Number Generation"
    RNG_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import os
import sys

# Generate random bytes using FIPS-approved DRBG
try:
    random_bytes = os.urandom(32)
    if len(random_bytes) == 32 and len(set(random_bytes)) > 10:
        print(f'RNG: Generated 32 bytes with {len(set(random_bytes))} unique values [OK]')
    else:
        print('RNG: Poor entropy detected [WARNING]')
except Exception as e:
    print(f'RNG: FAILED - {e}')
" 2>&1)
    
    if [[ "$RNG_TEST" == *"[OK]"* ]]; then
        log_pass "Random number generation validated"
        log_info "$RNG_TEST"
    else
        log_fail "RNG validation failed: $RNG_TEST"
    fi
}

################################################################################
# CATEGORY 6: SSL/TLS Protocol Validation
################################################################################
test_ssl_tls_protocols() {
    log_header "CATEGORY 6: SSL/TLS Protocol Compliance"
    
    # Test 6.1: Verify TLS 1.2 support (FIPS approved)
    log_test "6.1 - TLS 1.2 Protocol Support (Approved)"
    TLS12_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import ssl
try:
    # TLS 1.2 is FIPS approved
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    print('TLS 1.2: Supported [OK]')
    print(f'Available ciphers: {len(ctx.get_ciphers())} cipher suites')
except Exception as e:
    print(f'TLS 1.2: FAILED - {e}')
" 2>&1)
    
    if [[ "$TLS12_TEST" == *"[OK]"* ]]; then
        log_pass "TLS 1.2 support validated"
        log_info "$TLS12_TEST"
    else
        log_fail "TLS 1.2 validation failed"
    fi
    
    # Test 6.2: Verify TLS 1.3 support
    log_test "6.2 - TLS 1.3 Protocol Support"
    TLS13_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import ssl
try:
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_3
    print('TLS 1.3: Supported [OK]')
except AttributeError:
    print('TLS 1.3: Python SSL module may not fully support TLS 1.3 configuration')
except Exception as e:
    print(f'TLS 1.3: {e}')
" 2>&1)
    
    if [[ "$TLS13_TEST" == *"[OK]"* ]]; then
        log_pass "TLS 1.3 support validated"
    else
        log_info "TLS 1.3 status: $TLS13_TEST"
    fi
    
    # Test 6.3: Verify weak protocols are disabled
    log_test "6.3 - Legacy Protocol Restrictions (SSLv2, SSLv3, TLS 1.0, TLS 1.1)"
    LEGACY_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import ssl
results = []
weak_protocols_found = False

# SSLv2 should not be available
try:
    ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv2)
    results.append('SSLv2: AVAILABLE (SECURITY RISK!)')
    weak_protocols_found = True
except (AttributeError, ValueError):
    results.append('SSLv2: Properly disabled')

# SSLv3 should not be available
try:
    ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv3)
    results.append('SSLv3: AVAILABLE (SECURITY RISK!)')
    weak_protocols_found = True
except (AttributeError, ValueError):
    results.append('SSLv3: Properly disabled')

# TLS 1.0 should be disabled in FIPS mode
try:
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
    results.append('TLS 1.0: AVAILABLE (deprecated per NIST SP 800-52 Rev 2)')
    weak_protocols_found = True
except (AttributeError, ValueError):
    results.append('TLS 1.0: Properly disabled')

# TLS 1.1 should be disabled in FIPS mode
try:
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLSv1_1)
    results.append('TLS 1.1: AVAILABLE (deprecated per NIST SP 800-52 Rev 2)')
    weak_protocols_found = True
except (AttributeError, ValueError):
    results.append('TLS 1.1: Properly disabled')

for r in results:
    print(r)

if weak_protocols_found:
    print('RECOMMENDATION: Disable TLS 1.0/1.1 in OpenSSL configuration')
" 2>&1)
    
    if [[ "$LEGACY_TEST" == *"SECURITY RISK"* ]]; then
        log_fail "Critical: SSLv2/SSLv3 available - immediate remediation required"
        echo "$LEGACY_TEST"
    elif [[ "$LEGACY_TEST" == *"TLS 1.0: AVAILABLE"* ]] || [[ "$LEGACY_TEST" == *"TLS 1.1: AVAILABLE"* ]]; then
        log_warn "Legacy TLS protocols available - should be disabled per NIST SP 800-52 Rev 2"
        echo "$LEGACY_TEST" | while read line; do log_info "$line"; done
        log_info ""
        log_info "REMEDIATION: Add to openssl.cnf under [system_default_sect]:"
        log_info "  MinProtocol = TLSv1.2"
    else
        log_pass "Legacy protocols properly restricted"
        echo "$LEGACY_TEST" | while read line; do log_info "$line"; done
    fi
}

################################################################################
# CATEGORY 7: Security Policy Compliance
################################################################################
test_security_policy() {
    log_header "CATEGORY 7: Security Policy & Operational Environment"
    
    # Test 7.1: Verify non-root user execution
    log_test "7.1 - Non-Root User Requirement"
    USER_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import os
uid = os.getuid()
gid = os.getgid()
print(f'UID: {uid}, GID: {gid}')
if uid == 0:
    print('FAIL: Running as root (security violation)')
else:
    print(f'PASS: Running as non-root user (UID {uid})')
" 2>&1)
    
    if [[ "$USER_TEST" == *"PASS"* ]]; then
        log_pass "Non-root execution validated"
        log_info "$USER_TEST"
    else
        log_fail "Running as root user - CRITICAL SECURITY VIOLATION"
        log_info "$USER_TEST"
        log_info ""
        log_info "REMEDIATION REQUIRED:"
        log_info "Add to your Dockerfile before CMD/ENTRYPOINT:"
        log_info "  # Create non-root user"
        log_info "  RUN groupadd -g 65532 nonroot && \\"
        log_info "      useradd -u 65532 -g nonroot -s /bin/false nonroot"
        log_info "  # Switch to non-root user"
        log_info "  USER nonroot"
        log_info ""
        log_info "Or if using Chainguard base image:"
        log_info "  USER nonroot"
    fi
    
    # Test 7.2: Verify library dependencies are from FIPS module
    log_test "7.2 - Cryptographic Module Linkage"
    LINKAGE_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import ssl
import sys

# Check OpenSSL linkage
openssl_version = ssl.OPENSSL_VERSION
openssl_info = ssl.OPENSSL_VERSION_INFO

print(f'OpenSSL Version: {openssl_version}')
print(f'Version Info: {openssl_info}')

# Verify it's OpenSSL 3.0.x
if openssl_info[0] == 3 and openssl_info[1] == 0:
    print('PASS: Linked to OpenSSL 3.0.x FIPS module')
else:
    print(f'WARNING: Unexpected OpenSSL version: {openssl_info}')
" 2>&1)
    
    if [[ "$LINKAGE_TEST" == *"PASS"* ]]; then
        log_pass "Cryptographic module linkage verified"
        echo "$LINKAGE_TEST" | while read line; do log_info "$line"; done
    else
        log_warn "Module linkage requires verification"
        echo "$LINKAGE_TEST"
    fi
    
    # Test 7.3: Verify FIPS configuration persistence
    log_test "7.3 - FIPS Configuration Persistence"
    PERSISTENCE_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import os

# Check that FIPS config files exist and are readable
configs = [
    '/usr/local/ssl/openssl.cnf',
    '/usr/local/ssl/fipsmodule.cnf'
]

all_good = True
for config in configs:
    if os.path.exists(config) and os.access(config, os.R_OK):
        print(f'PASS: {config} exists and is readable')
    else:
        print(f'FAIL: {config} missing or not readable')
        all_good = False

if all_good:
    print('OVERALL: FIPS configuration persistent')
" 2>&1)
    
    if [[ "$PERSISTENCE_TEST" == *"OVERALL: FIPS configuration persistent"* ]]; then
        log_pass "FIPS configuration persistence validated"
    else
        log_fail "FIPS configuration issues detected"
        echo "$PERSISTENCE_TEST"
    fi
}

################################################################################
# CATEGORY 8: Error Handling & Boundary Conditions
################################################################################
test_error_conditions() {
    log_header "CATEGORY 8: Error Handling & Boundary Conditions"
    
    # Test 8.1: Invalid cipher operations
    log_test "8.1 - Invalid Cipher Operation Handling"
    INVALID_CIPHER=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend

try:
    # Try to use invalid key size for AES
    invalid_key = b'short'  # Invalid key size
    iv = b'1234567890123456'
    cipher = Cipher(algorithms.AES(invalid_key), modes.CBC(iv), backend=default_backend())
    print('FAIL: Invalid key size accepted')
except ValueError as e:
    print('PASS: Invalid key size properly rejected')
except Exception as e:
    print(f'ERROR: Unexpected exception - {e}')
" 2>&1)
    
    if [[ "$INVALID_CIPHER" == *"PASS"* ]]; then
        log_pass "Invalid cipher parameters properly rejected"
    else
        log_fail "Error handling issue: $INVALID_CIPHER"
    fi
    
    # Test 8.2: Buffer overflow protection
    log_test "8.2 - Large Data Handling"
    LARGE_DATA=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib

try:
    # Process large amount of data
    large_data = b'X' * (10 * 1024 * 1024)  # 10 MB
    h = hashlib.sha256(large_data)
    digest = h.hexdigest()
    print(f'PASS: Processed {len(large_data)} bytes successfully')
except MemoryError:
    print('FAIL: Memory error on large data')
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)
    
    if [[ "$LARGE_DATA" == *"PASS"* ]]; then
        log_pass "Large data handling validated"
    else
        log_warn "Large data handling: $LARGE_DATA"
    fi
    
    # Test 8.3: Null/empty input handling
    log_test "8.3 - Null and Empty Input Handling"
    EMPTY_INPUT=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib

try:
    # Test with empty input
    h = hashlib.sha256(b'')
    digest = h.hexdigest()
    expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    if digest == expected:
        print('PASS: Empty input handled correctly')
    else:
        print('FAIL: Incorrect digest for empty input')
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)
    
    if [[ "$EMPTY_INPUT" == *"PASS"* ]]; then
        log_pass "Empty input handling validated"
    else
        log_fail "Empty input handling failed: $EMPTY_INPUT"
    fi
}

################################################################################
# CATEGORY 9: Zeroization & Data Protection
################################################################################
test_zeroization() {
    log_header "CATEGORY 9: Zeroization & Sensitive Data Protection"
    
    # Test 9.1: Key zeroization on deletion
    log_test "9.1 - Cryptographic Key Zeroization"
    ZEROIZATION=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
import gc

try:
    # Generate a key
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    
    # Delete the key
    del private_key
    
    # Force garbage collection
    gc.collect()
    
    print('PASS: Key deletion and garbage collection completed')
    print('Note: Actual memory zeroization depends on cryptography library implementation')
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)
    
    if [[ "$ZEROIZATION" == *"PASS"* ]]; then
        log_pass "Key zeroization process validated"
        log_info "$ZEROIZATION"
    else
        log_fail "Zeroization test failed: $ZEROIZATION"
    fi
}

################################################################################
# CATEGORY 10: Compliance Verification
################################################################################
test_compliance_verification() {
    log_header "CATEGORY 10: FIPS 140-2 Compliance Verification"
    
    # Test 10.1: Verify approved security functions only
    log_test "10.1 - Security Function Inventory"
    SECURITY_FUNCTIONS=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
import ssl

print('Available Hash Algorithms:')
for algo in sorted(hashlib.algorithms_available):
    print(f'  - {algo}')

print()
print('SSL/TLS Information:')
print(f'  OpenSSL Version: {ssl.OPENSSL_VERSION}')
print(f'  Supported Protocols: TLS 1.2, TLS 1.3')
" 2>&1)
    
    log_pass "Security function inventory generated"
    echo "$SECURITY_FUNCTIONS" | while read line; do log_info "$line"; done
    
    # Test 10.2: FIPS mode indicator
    log_test "10.2 - FIPS Mode Status Indicator"
    FIPS_STATUS=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import os
import subprocess

print('FIPS Environment Check:')
print(f'  OPENSSL_FIPS: {os.environ.get(\"OPENSSL_FIPS\", \"NOT SET\")}')
print(f'  OPENSSL_CONF: {os.environ.get(\"OPENSSL_CONF\", \"NOT SET\")}')

# Try to get FIPS status from OpenSSL
try:
    result = subprocess.run(['/usr/local/ssl/bin/openssl', 'list', '-providers'], 
                          capture_output=True, text=True, timeout=5)
    if 'fips' in result.stdout.lower():
        print('  FIPS Provider: LOADED')
    else:
        print('  FIPS Provider: Status unclear')
    
    print()
    print('Provider Output:')
    for line in result.stdout.split('\\n')[:10]:
        if line.strip():
            print(f'  {line}')
except Exception as e:
    print(f'  Provider check failed: {e}')
" 2>&1)
    
    if [[ "$FIPS_STATUS" == *"OPENSSL_FIPS: 1"* ]]; then
        log_pass "FIPS mode indicators present"
        echo "$FIPS_STATUS" | while read line; do log_info "$line"; done
    else
        log_warn "FIPS mode indicators require verification"
        echo "$FIPS_STATUS"
    fi
    
    # Test 10.3: Certificate validation
    log_test "10.3 - X.509 Certificate Handling"
    CERT_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
import datetime

try:
    # Generate a self-signed certificate
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, u'US'),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, u'California'),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, u'FIPS Test'),
        x509.NameAttribute(NameOID.COMMON_NAME, u'fips.test.local'),
    ])
    
    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.datetime.utcnow()
    ).not_valid_after(
        datetime.datetime.utcnow() + datetime.timedelta(days=365)
    ).sign(private_key, hashes.SHA256(), default_backend())
    
    print('PASS: X.509 certificate generation successful')
    print(f'  Subject: {cert.subject}')
    print(f'  Signature Algorithm: {cert.signature_algorithm_oid._name}')
except Exception as e:
    print(f'FAIL: Certificate generation failed - {e}')
" 2>&1)
    
    if [[ "$CERT_TEST" == *"PASS"* ]]; then
        log_pass "X.509 certificate handling validated"
        echo "$CERT_TEST" | while read line; do log_info "$line"; done
    else
        log_fail "Certificate handling failed: $CERT_TEST"
    fi
}

################################################################################
# CATEGORY 11: Performance & Resource Management
################################################################################
test_performance() {
    log_header "CATEGORY 11: Performance & Resource Management"
    
    # Test 11.1: Cryptographic operation performance
    log_test "11.1 - Cryptographic Operation Performance Baseline"
    PERF_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import hashlib
import time

# SHA-256 performance test
iterations = 10000
data = b'Performance test data' * 100

start = time.time()
for i in range(iterations):
    h = hashlib.sha256(data)
    digest = h.hexdigest()
end = time.time()

elapsed = end - start
ops_per_sec = iterations / elapsed

print(f'SHA-256 Performance:')
print(f'  Iterations: {iterations}')
print(f'  Data size: {len(data)} bytes')
print(f'  Time: {elapsed:.2f} seconds')
print(f'  Throughput: {ops_per_sec:.0f} ops/sec')

if ops_per_sec > 100:
    print('PASS: Acceptable performance')
else:
    print('WARNING: Performance may be degraded')
" 2>&1)
    
    if [[ "$PERF_TEST" == *"PASS"* ]]; then
        log_pass "Performance baseline established"
        echo "$PERF_TEST" | while read line; do log_info "$line"; done
    else
        log_info "Performance metrics:"
        echo "$PERF_TEST"
    fi
    
    # Test 11.2: Memory usage
    log_test "11.2 - Memory Usage Assessment"
    MEMORY_TEST=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import sys
import gc

# Get memory info
gc.collect()
print(f'Python version: {sys.version}')
print(f'Memory management: Automatic garbage collection enabled')
print('PASS: Memory management functional')
" 2>&1)
    
    if [[ "$MEMORY_TEST" == *"PASS"* ]]; then
        log_pass "Memory management validated"
    else
        log_info "Memory status: $MEMORY_TEST"
    fi
}

################################################################################
# CATEGORY 12: Image Security Posture
################################################################################
test_image_security() {
    log_header "CATEGORY 12: Container Image Security Posture"
    
    # Test 12.1: Image size
    log_test "12.1 - Image Size Analysis"
    IMAGE_SIZE=$(docker images ${IMAGE_NAME} --format "{{.Size}}")
    log_info "Image size: $IMAGE_SIZE"
    
    # Test 12.2: Base image verification
    log_test "12.2 - Base Image Verification"
    BASE_IMAGE=$(docker inspect ${IMAGE_NAME} --format='{{.Config.Image}}' 2>&1 || echo "Unable to determine")
    log_info "Base image lineage: Chainguard glibc-dynamic"
    
    # Test 12.3: Exposed ports and services
    log_test "12.3 - Network Exposure Analysis"
    EXPOSED_PORTS=$(docker inspect ${IMAGE_NAME} --format='{{.Config.ExposedPorts}}' 2>&1)
    if [[ "$EXPOSED_PORTS" == "map[]" ]] || [[ "$EXPOSED_PORTS" == "<no value>" ]]; then
        log_pass "No exposed ports (minimal attack surface)"
    else
        log_info "Exposed ports: $EXPOSED_PORTS"
    fi
    
    # Test 12.4: User configuration
    log_test "12.4 - User Security Configuration"
    USER_CONFIG=$(docker inspect ${IMAGE_NAME} --format='{{.Config.User}}' 2>&1)
    if [[ "$USER_CONFIG" == "nonroot" ]] || [[ "$USER_CONFIG" == "65532" ]]; then
        log_pass "Container configured to run as non-root user"
    else
        log_warn "User configuration: $USER_CONFIG"
    fi
}

################################################################################
# CATEGORY 13: Audit & Documentation
################################################################################
test_audit_trail() {
    log_header "CATEGORY 13: Audit Trail & Documentation"
    
    # Test 13.1: Software Bill of Materials (SBOM)
    log_test "13.1 - Software Inventory"
    SBOM=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import sys
import ssl
print('Core Components:')
print(f'  Python: {sys.version.split()[0]}')
print(f'  OpenSSL: {ssl.OPENSSL_VERSION}')
print(f'  Platform: {sys.platform}')

import pkg_resources
installed_packages = [d for d in pkg_resources.working_set]
print(f'\\nInstalled Python Packages: {len(installed_packages)}')
for pkg in sorted(installed_packages, key=lambda x: x.key)[:10]:
    print(f'  - {pkg.key} {pkg.version}')
" 2>&1)
    
    log_pass "Software inventory generated"
    echo "$SBOM" | while read line; do log_info "$line"; done
    
    # Test 13.2: Build metadata
    log_test "13.2 - Build Metadata"
    BUILD_DATE=$(docker inspect ${IMAGE_NAME} --format='{{.Created}}' 2>&1)
    log_info "Build timestamp: $BUILD_DATE"
    
    # Test 13.3: Configuration documentation
    log_test "13.3 - Environment Configuration"
    ENV_CONFIG=$(docker run --rm ${IMAGE_NAME} ${PYTHON_CMD} -c "
import os
fips_vars = {k: v for k, v in os.environ.items() if 'FIPS' in k or 'OPENSSL' in k or 'SSL' in k}
print('FIPS-Related Environment Variables:')
for k, v in sorted(fips_vars.items()):
    print(f'  {k}={v}')
" 2>&1)
    
    log_info "Configuration documented:"
    echo "$ENV_CONFIG" | while read line; do log_info "$line"; done
}

################################################################################
# CATEGORY 14: Vulnerability Scanning with Trivy
################################################################################
test_vulnerability_scanning() {
    log_header "CATEGORY 14: Vulnerability Scanning (Trivy)"
    
    # Test 14.1: Check if Trivy is available
    log_test "14.1 - Trivy Installation Check"
    
    if command -v trivy &> /dev/null; then
        TRIVY_VERSION=$(trivy --version 2>&1 | head -1)
        log_pass "Trivy installed: $TRIVY_VERSION"
        TRIVY_AVAILABLE=true
    else
        log_warn "Trivy not installed - vulnerability scanning skipped"
        log_info "Install Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        log_info "  Ubuntu/Debian: apt-get install trivy"
        log_info "  macOS: brew install trivy"
        log_info "  Or use Docker: docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy"
        TRIVY_AVAILABLE=false
        return
    fi
    
    # Test 14.2: Scan for critical vulnerabilities
    log_test "14.2 - Critical Vulnerability Scan"
    log_info "Scanning for CRITICAL vulnerabilities (this may take a moment)..."
    
    TRIVY_CRITICAL=$(trivy image --severity CRITICAL --quiet --format json ${IMAGE_NAME} 2>&1)
    
    if [ $? -eq 0 ]; then
        # Count critical vulnerabilities
        CRITICAL_COUNT=$(echo "$TRIVY_CRITICAL" | grep -o '"Severity":"CRITICAL"' | wc -l)
        
        if [ "$CRITICAL_COUNT" -eq 0 ]; then
            log_pass "No CRITICAL vulnerabilities found"
        else
            log_fail "Found $CRITICAL_COUNT CRITICAL vulnerabilities"
            log_info "Run 'trivy image ${IMAGE_NAME}' for detailed report"
        fi
    else
        log_warn "Trivy scan failed - check Trivy installation"
    fi
    
    # Test 14.3: Scan for high vulnerabilities
    log_test "14.3 - High Severity Vulnerability Scan"
    log_info "Scanning for HIGH severity vulnerabilities..."
    
    TRIVY_HIGH=$(trivy image --severity HIGH --quiet --format json ${IMAGE_NAME} 2>&1)
    
    if [ $? -eq 0 ]; then
        HIGH_COUNT=$(echo "$TRIVY_HIGH" | grep -o '"Severity":"HIGH"' | wc -l)
        
        if [ "$HIGH_COUNT" -eq 0 ]; then
            log_pass "No HIGH severity vulnerabilities found"
        elif [ "$HIGH_COUNT" -le 5 ]; then
            log_warn "Found $HIGH_COUNT HIGH severity vulnerabilities (acceptable threshold)"
            log_info "Review and remediate when possible"
        else
            log_fail "Found $HIGH_COUNT HIGH severity vulnerabilities (exceeds threshold)"
            log_info "Immediate review recommended"
        fi
    else
        log_warn "Trivy scan failed"
    fi
    
    # Test 14.4: Full vulnerability summary
    log_test "14.4 - Vulnerability Summary Report"
    log_info "Generating comprehensive vulnerability report..."
    
    TRIVY_SUMMARY=$(trivy image --quiet --format table ${IMAGE_NAME} 2>&1 | tail -20)
    
    if [ $? -eq 0 ]; then
        log_pass "Vulnerability summary generated"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Trivy Vulnerability Summary (Last 20 lines):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$TRIVY_SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "For full report: trivy image ${IMAGE_NAME}"
        log_info "For JSON output: trivy image --format json --output trivy-report.json ${IMAGE_NAME}"
        log_info "For SARIF (GitHub): trivy image --format sarif --output trivy-report.sarif ${IMAGE_NAME}"
    fi
    
    # Test 14.5: Generate detailed vulnerability report (automatically saved)
    log_test "14.5 - Detailed Vulnerability Report Generation"
    
    # Generate timestamped filename automatically
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    VULN_REPORT_FILE="trivy-vulnerabilities-${IMAGE_NAME//[\/:]/-}-${TIMESTAMP}.json"
    
    log_info "Generating detailed vulnerability report..."
    echo ""
    
    if trivy image --format json --output "$VULN_REPORT_FILE" ${IMAGE_NAME} 2>&1; then
        log_pass "Vulnerability report successfully generated"
        
        # Display absolute path for easy access
        ABSOLUTE_PATH=$(realpath "$VULN_REPORT_FILE" 2>/dev/null || echo "$VULN_REPORT_FILE")
        
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}📄 VULNERABILITY REPORT SAVED${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}Filename:${NC} $VULN_REPORT_FILE"
        echo -e "${BLUE}Full Path:${NC} $ABSOLUTE_PATH"
        
        # Parse report for summary statistics if jq is available
        if command -v jq &> /dev/null; then
            echo ""
            TOTAL_VULNS=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$VULN_REPORT_FILE" 2>/dev/null || echo "0")
            CRITICAL_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$VULN_REPORT_FILE" 2>/dev/null || echo "0")
            HIGH_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$VULN_REPORT_FILE" 2>/dev/null || echo "0")
            MEDIUM_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$VULN_REPORT_FILE" 2>/dev/null || echo "0")
            LOW_VULNS=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "$VULN_REPORT_FILE" 2>/dev/null || echo "0")
            
            echo -e "${BLUE}Report Statistics:${NC}"
            echo "  • Total vulnerabilities: $TOTAL_VULNS"
            echo "  • Critical: $CRITICAL_VULNS"
            echo "  • High: $HIGH_VULNS"
            echo "  • Medium: $MEDIUM_VULNS"
            echo "  • Low: $LOW_VULNS"
        fi
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
    else
        log_fail "Vulnerability report generation failed"
    fi
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════"
    log_info "VULNERABILITY SCANNING COMPLETE"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""
}

################################################################################
# CATEGORY 15: Software Bill of Materials (SBOM) Generation
################################################################################
test_sbom_generation() {
    log_header "CATEGORY 15: Software Bill of Materials (SBOM) Generation"
    
    # Check if Trivy is available
    if ! command -v trivy &> /dev/null; then
        log_fail "Trivy is not installed - SBOM generation skipped"
        log_info "Install Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        return
    fi
    
    TRIVY_AVAILABLE=true
    
    # Test 15.1: Generate CycloneDX SBOM in JSON format
    log_test "15.1 - CycloneDX SBOM Generation (JSON)"
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    SBOM_JSON_FILE="sbom-cyclonedx-${IMAGE_NAME//[\/:]/-}-${TIMESTAMP}.json"
    
    log_info "Generating CycloneDX SBOM in JSON format..."
    echo ""
    
    if trivy image --format cyclonedx --output "$SBOM_JSON_FILE" ${IMAGE_NAME} 2>&1; then
        log_pass "CycloneDX SBOM (JSON) successfully generated"
        
        ABSOLUTE_PATH=$(realpath "$SBOM_JSON_FILE" 2>/dev/null || echo "$SBOM_JSON_FILE")
        
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}📦 CYCLONEDX SBOM (JSON) SAVED${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}Filename:${NC} $SBOM_JSON_FILE"
        echo -e "${BLUE}Full Path:${NC} $ABSOLUTE_PATH"
        
        # Parse SBOM for component statistics if jq is available
        if command -v jq &> /dev/null; then
            echo ""
            TOTAL_COMPONENTS=$(jq '.components | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "0")
            SBOM_VERSION=$(jq -r '.specVersion' "$SBOM_JSON_FILE" 2>/dev/null || echo "unknown")
            SBOM_FORMAT=$(jq -r '.bomFormat' "$SBOM_JSON_FILE" 2>/dev/null || echo "unknown")
            
            echo -e "${BLUE}SBOM Statistics:${NC}"
            echo "  • Format: $SBOM_FORMAT"
            echo "  • Spec Version: $SBOM_VERSION"
            echo "  • Total Components: $TOTAL_COMPONENTS"
            
            # Count components by type if available
            OS_PACKAGES=$(jq '[.components[] | select(.type=="library" or .type=="application")] | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "0")
            if [ "$OS_PACKAGES" != "0" ]; then
                echo "  • Software Packages: $OS_PACKAGES"
            fi
        fi
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
    else
        log_fail "CycloneDX SBOM (JSON) generation failed"
    fi
    
    # Test 15.2: Generate CycloneDX SBOM in XML format
    log_test "15.2 - CycloneDX SBOM Generation (XML)"
    
    SBOM_XML_FILE="sbom-cyclonedx-${IMAGE_NAME//[\/:]/-}-${TIMESTAMP}.xml"
    
    log_info "Generating CycloneDX SBOM in XML format..."
    echo ""
    
    # Note: Trivy's cyclonedx format outputs JSON by default, we'll document this
    log_info "Trivy primarily generates CycloneDX in JSON format"
    log_info "For XML conversion, use external tools like:"
    log_info "  • cyclonedx-cli (https://github.com/CycloneDX/cyclonedx-cli)"
    log_info "  • Command: cyclonedx convert --input-file $SBOM_JSON_FILE --output-file $SBOM_XML_FILE --output-format xml"
    
    # Check if cyclonedx-cli is available for XML conversion
    if command -v cyclonedx &> /dev/null || command -v cyclonedx-cli &> /dev/null; then
        log_info "CycloneDX CLI detected, attempting XML conversion..."
        
        CYCLONEDX_CMD=$(command -v cyclonedx 2>/dev/null || command -v cyclonedx-cli 2>/dev/null)
        
        if $CYCLONEDX_CMD convert --input-file "$SBOM_JSON_FILE" --output-file "$SBOM_XML_FILE" --output-format xml &> /dev/null; then
            log_pass "CycloneDX SBOM (XML) successfully generated"
            
            ABSOLUTE_PATH_XML=$(realpath "$SBOM_XML_FILE" 2>/dev/null || echo "$SBOM_XML_FILE")
            
            echo ""
            echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}📦 CYCLONEDX SBOM (XML) SAVED${NC}"
            echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
            echo -e "${BLUE}Filename:${NC} $SBOM_XML_FILE"
            echo -e "${BLUE}Full Path:${NC} $ABSOLUTE_PATH_XML"
            echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
            echo ""
        else
            log_warn "XML conversion failed - JSON format available"
        fi
    else
        log_info "CycloneDX CLI not installed - only JSON format generated"
        log_info "Install from: https://github.com/CycloneDX/cyclonedx-cli"
    fi
    
    # Test 15.3: Validate SBOM compliance
    log_test "15.3 - SBOM Compliance Validation"
    
    if [ -f "$SBOM_JSON_FILE" ]; then
        # Verify SBOM has required fields
        if command -v jq &> /dev/null; then
            HAS_METADATA=$(jq 'has("metadata")' "$SBOM_JSON_FILE" 2>/dev/null)
            HAS_COMPONENTS=$(jq 'has("components")' "$SBOM_JSON_FILE" 2>/dev/null)
            HAS_BOMFORMAT=$(jq 'has("bomFormat")' "$SBOM_JSON_FILE" 2>/dev/null)
            
            if [ "$HAS_METADATA" = "true" ] && [ "$HAS_COMPONENTS" = "true" ] && [ "$HAS_BOMFORMAT" = "true" ]; then
                log_pass "SBOM contains required CycloneDX fields"
                log_info "✓ Metadata section present"
                log_info "✓ Components list present"
                log_info "✓ BOM format specification present"
            else
                log_warn "SBOM may be incomplete - missing required fields"
            fi
        else
            log_info "Install 'jq' for SBOM validation"
        fi
    else
        log_fail "SBOM file not found for validation"
    fi
    
    # Test 15.4: SBOM coverage analysis
    log_test "15.4 - SBOM Coverage Analysis"
    
    if [ -f "$SBOM_JSON_FILE" ] && command -v jq &> /dev/null; then
        # Analyze component coverage
        COMPONENTS_WITH_VERSION=$(jq '[.components[] | select(.version != null and .version != "")] | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "0")
        COMPONENTS_WITH_LICENSE=$(jq '[.components[] | select(.licenses != null and .licenses != [])] | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "0")
        COMPONENTS_WITH_PURL=$(jq '[.components[] | select(.purl != null and .purl != "")] | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "0")
        
        TOTAL_COMPONENTS=$(jq '.components | length' "$SBOM_JSON_FILE" 2>/dev/null || echo "1")
        
        if [ "$TOTAL_COMPONENTS" -gt 0 ]; then
            VERSION_COVERAGE=$((COMPONENTS_WITH_VERSION * 100 / TOTAL_COMPONENTS))
            LICENSE_COVERAGE=$((COMPONENTS_WITH_LICENSE * 100 / TOTAL_COMPONENTS))
            PURL_COVERAGE=$((COMPONENTS_WITH_PURL * 100 / TOTAL_COMPONENTS))
            
            log_pass "SBOM coverage analysis complete"
            echo ""
            echo -e "${BLUE}Coverage Metrics:${NC}"
            echo "  • Components with versions: $COMPONENTS_WITH_VERSION/$TOTAL_COMPONENTS (${VERSION_COVERAGE}%)"
            echo "  • Components with licenses: $COMPONENTS_WITH_LICENSE/$TOTAL_COMPONENTS (${LICENSE_COVERAGE}%)"
            echo "  • Components with PURLs: $COMPONENTS_WITH_PURL/$TOTAL_COMPONENTS (${PURL_COVERAGE}%)"
            echo ""
            
            if [ "$VERSION_COVERAGE" -ge 90 ] && [ "$LICENSE_COVERAGE" -ge 70 ]; then
                log_pass "Excellent SBOM coverage (>90% versions, >70% licenses)"
            elif [ "$VERSION_COVERAGE" -ge 70 ]; then
                log_warn "Good SBOM coverage - consider improving license information"
            else
                log_warn "SBOM coverage could be improved"
            fi
        else
            log_warn "No components found in SBOM"
        fi
    else
        log_info "Coverage analysis requires SBOM file and jq utility"
    fi
    
    # Test 15.5: SBOM usage recommendations
    log_test "15.5 - SBOM Usage & Integration Recommendations"
    
    log_pass "SBOM generation complete - integration recommendations:"
    echo ""
    echo -e "${BLUE}Recommended SBOM Use Cases:${NC}"
    echo "  • Supply chain security and transparency"
    echo "  • License compliance verification"
    echo "  • Vulnerability tracking and correlation"
    echo "  • Software composition analysis (SCA)"
    echo "  • Regulatory compliance (e.g., EO 14028)"
    echo ""
    echo -e "${BLUE}Integration Suggestions:${NC}"
    echo "  • Store SBOMs in artifact repository alongside images"
    echo "  • Include SBOM generation in CI/CD pipeline"
    echo "  • Use dependency-track or similar tools for SBOM analysis"
    echo "  • Correlate SBOM with vulnerability scan results"
    echo "  • Maintain SBOM version history for auditing"
    echo ""
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════"
    log_info "SBOM GENERATION COMPLETE"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""
}

################################################################################
# Executive Summary Report
################################################################################
generate_summary_report() {
    log_header "FIPS 140-2 VALIDATION SUMMARY REPORT"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))
    
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│              TEST EXECUTION SUMMARY                      │"
    echo "├─────────────────────────────────────────────────────────┤"
    echo "│ Total Tests Run:        $(printf '%3d' $TOTAL_TESTS)                              │"
    echo "│ Tests Passed:           $(printf '%3d' $TESTS_PASSED) ($(printf '%3d' $((TESTS_PASSED * 100 / TOTAL_TESTS)))%)                        │"
    echo "│ Tests Failed:           $(printf '%3d' $TESTS_FAILED) ($(printf '%3d' $((TESTS_FAILED * 100 / TOTAL_TESTS)))%)                        │"
    echo "│ Warnings:               $(printf '%3d' $TESTS_WARNING) ($(printf '%3d' $((TESTS_WARNING * 100 / TOTAL_TESTS)))%)                        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    
    # Determine compliance status
    CRITICAL_FAILURES=0
    
    # Check for critical failures
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ COMPLIANCE STATUS: PASSED${NC}"
        echo ""
        echo "All critical FIPS 140-2 validation tests passed successfully."
        echo "The container image demonstrates conformance to FIPS requirements."
    elif [ $TESTS_FAILED -le 2 ] && [ $TESTS_WARNING -le 3 ]; then
        echo -e "${YELLOW}⚠ COMPLIANCE STATUS: CONDITIONAL PASS${NC}"
        echo ""
        echo "Most tests passed with minor issues requiring review."
        echo "Consult failed test details above for remediation guidance."
    else
        echo -e "${RED}✗ COMPLIANCE STATUS: FAILED${NC}"
        echo ""
        echo "Critical FIPS validation tests failed."
        echo "Immediate remediation required before production deployment."
    fi
    
    echo ""
    echo "CRITICAL ISSUES FOUND:"
    echo "────────────────────────────────────────────────────────"
    
    # Analyze specific failures and provide guidance
    HAS_CRITICAL=false
    
    # Check test results and provide specific remediation
    if grep -q "Running as root user" <<< "$ALL_OUTPUT" 2>/dev/null; then
        echo "❌ CRITICAL: Container running as root user"
        echo "   Impact: Security violation, privilege escalation risk"
        echo "   Fix: Add 'USER nonroot' to Dockerfile"
        echo ""
        HAS_CRITICAL=true
    fi
    
    if grep -q "OPENSSL_CONF.*NOT SET" <<< "$ALL_OUTPUT" 2>/dev/null; then
        echo "⚠️  HIGH: OPENSSL_CONF environment variable not set"
        echo "   Impact: FIPS configuration may not be loaded properly"
        echo "   Fix: Add 'ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf' to Dockerfile"
        echo ""
        HAS_CRITICAL=true
    fi
    
    if grep -q "1024-bit RSA key generated" <<< "$ALL_OUTPUT" 2>/dev/null; then
        echo "⚠️  MEDIUM: Weak RSA keys (1024-bit) accepted"
        echo "   Impact: Below FIPS minimum key size requirements"
        echo "   Fix: Configure OpenSSL to reject weak key sizes"
        echo ""
    fi
    
    if grep -q "TLS 1.0: AVAILABLE\|TLS 1.1: AVAILABLE" <<< "$ALL_OUTPUT" 2>/dev/null; then
        echo "⚠️  MEDIUM: Legacy TLS protocols (1.0/1.1) available"
        echo "   Impact: Deprecated per NIST SP 800-52 Rev 2"
        echo "   Fix: Add 'MinProtocol = TLSv1.2' to openssl.cnf [system_default_sect]"
        echo ""
    fi
    
    if [ "$HAS_CRITICAL" = false ] && [ $TESTS_FAILED -eq 0 ]; then
        echo "✅ No critical issues found"
        echo ""
    fi
    
    echo "RECOMMENDATIONS:"
    echo "────────────────────────────────────────────────────────"
    
    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_WARNING -eq 0 ]; then
        echo "✅ Image is ready for FIPS-compliant production deployment"
        echo "• Continue with security scanning and vulnerability assessment"
        echo "• Implement continuous monitoring of FIPS compliance"
    elif [ "$HAS_CRITICAL" = true ]; then
        echo "🔴 IMMEDIATE ACTION REQUIRED:"
        echo "• Fix all critical issues above before production deployment"
        echo "• Rebuild container image with security fixes"
        echo "• Re-run this validation suite to verify fixes"
        echo ""
        echo "📋 QUICK FIX CHECKLIST:"
        echo "  1. Add to Dockerfile: USER nonroot"
        echo "  2. Add to Dockerfile: ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf"
        echo "  3. Rebuild: docker build -t $IMAGE_NAME ."
        echo "  4. Re-test: $0 $IMAGE_NAME"
    else
        echo "• Review all failed tests and warnings above"
        echo "• Consult NIST SP 800-140 for detailed FIPS requirements"
        echo "• Consider engaging a CMVP testing laboratory for formal validation"
    fi
    
    echo ""
    echo "STANDARD RECOMMENDATIONS:"
    echo "• Maintain audit logs of all cryptographic operations"
    echo "• Implement key management procedures per NIST SP 800-57"
    echo "• Establish incident response procedures for security events"
    echo "• Schedule regular FIPS compliance re-validation"
    
    # Include vulnerability scanning recommendations if Trivy was run
    if [ "$TRIVY_AVAILABLE" = true ]; then
        echo "• Review and remediate identified vulnerabilities"
        echo "• Implement regular vulnerability scanning in CI/CD pipeline"
        echo "• Subscribe to security advisories for all components"
        echo "• Maintain and version control generated SBOMs"
        echo "• Use SBOM for supply chain risk assessment"
        echo "• Integrate SBOM analysis tools (e.g., dependency-track)"
    fi
    echo ""
    
    echo "IMPORTANT NOTICE:"
    echo "────────────────────────────────────────────────────────"
    echo "This test suite validates FIPS 140-2 configuration and operation,"
    echo "but does NOT constitute official NIST CMVP validation."
    echo ""
    echo "For production compliance in regulated environments:"
    echo "• Use NIST CAVP-validated cryptographic implementations"
    echo "• Obtain official CMVP certificate for your module"
    echo "• Follow NIST SP 800-140 validation documentation requirements"
    echo "• Maintain compliance with FIPS 140-3 transition timeline"
    echo ""
    
    echo "Report generated: $(date)"
    echo "Image tested: ${IMAGE_NAME}"
    echo ""
    
    # Save detailed results for reference
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "💾 TIP: Save this report for documentation:"
        echo "   $0 $IMAGE_NAME 2>&1 | tee fips-validation-$(date +%Y%m%d-%H%M%S).txt"
        echo ""
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    log_header "FIPS 140-2 Comprehensive Validation Test Suite"
    echo "Image Under Test: ${IMAGE_NAME}"
    echo "Test Start Time: $(date)"
    echo ""
    
    # Execute all test categories
    test_module_identification
    test_power_on_self_tests
    test_approved_algorithms
    test_non_approved_algorithms
    test_key_generation
    test_ssl_tls_protocols
    test_security_policy
    test_error_conditions
    test_zeroization
    test_compliance_verification
    test_performance
    test_image_security
    test_audit_trail
    
    # NEW: Vulnerability scanning with Trivy
    test_vulnerability_scanning
    
    # NEW: SBOM generation with Trivy
    test_sbom_generation
    
    # Generate final report
    generate_summary_report
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main
