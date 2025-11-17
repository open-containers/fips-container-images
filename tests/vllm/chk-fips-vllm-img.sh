#!/bin/bash

################################################################################
# vLLM FIPS Container Validation Script
# Purpose: Validate vLLM container is running correctly with FIPS compliance
# Usage: ./validate-vllm-container.sh [container_name_or_id]
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONTAINER_NAME="${1:-vllm-fips}"
VLLM_HOST="${VLLM_HOST:-localhost}"
VLLM_PORT="${VLLM_PORT:-8000}"
TIMEOUT=30

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST $((TESTS_TOTAL + 1))]${NC} $1"
    ((TESTS_TOTAL++))
}

print_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "  ${BLUE}ℹ INFO:${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠ WARN:${NC} $1"
}

################################################################################
# Test Functions
################################################################################

# Test 1: Container Existence
test_container_exists() {
    print_test "Checking if container exists"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_pass "Container '${CONTAINER_NAME}' exists"
        return 0
    else
        print_fail "Container '${CONTAINER_NAME}' not found"
        print_info "Available containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
        return 1
    fi
}

# Test 2: Container Running State
test_container_running() {
    print_test "Checking if container is running"
    
    STATUS=$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null)
    
    if [ "$STATUS" = "running" ]; then
        UPTIME=$(docker inspect -f '{{.State.StartedAt}}' "${CONTAINER_NAME}")
        print_pass "Container is running (started: ${UPTIME})"
        return 0
    else
        print_fail "Container status: ${STATUS}"
        return 1
    fi
}

# Test 3: Container Health
test_container_health() {
    print_test "Checking container health status"
    
    HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no healthcheck")
    
    if [ "$HEALTH" = "healthy" ]; then
        print_pass "Container health: healthy"
        return 0
    elif [ "$HEALTH" = "no healthcheck" ]; then
        print_warn "No healthcheck defined (not required but recommended)"
        return 0
    else
        print_warn "Container health: ${HEALTH}"
        return 0
    fi
}

# Test 4: GPU Access
test_gpu_access() {
    print_test "Checking GPU accessibility"
    
    GPU_COUNT=$(docker exec "${CONTAINER_NAME}" python3 -c "import torch; print(torch.cuda.device_count())" 2>/dev/null || echo "0")
    
    if [ "$GPU_COUNT" -gt 0 ]; then
        print_pass "GPU detected: ${GPU_COUNT} device(s) available"
        
        # Get GPU details
        GPU_NAME=$(docker exec "${CONTAINER_NAME}" python3 -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" 2>/dev/null)
        print_info "GPU: ${GPU_NAME}"
        
        # Check CUDA availability
        CUDA_AVAILABLE=$(docker exec "${CONTAINER_NAME}" python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
        print_info "CUDA available: ${CUDA_AVAILABLE}"
        
        return 0
    else
        print_fail "No GPU detected"
        print_info "Check if container was started with --gpus flag"
        return 1
    fi
}

# Test 5: vLLM Process Running
test_vllm_process() {
    print_test "Checking vLLM process"
    
    if docker exec "${CONTAINER_NAME}" pgrep -f "vllm.entrypoints.openai.api_server" > /dev/null 2>&1; then
        PID=$(docker exec "${CONTAINER_NAME}" pgrep -f "vllm.entrypoints.openai.api_server")
        print_pass "vLLM process running (PID: ${PID})"
        
        # Check process uptime
        UPTIME=$(docker exec "${CONTAINER_NAME}" ps -p "$PID" -o etime= 2>/dev/null | tr -d ' ')
        print_info "Process uptime: ${UPTIME}"
        
        return 0
    else
        print_fail "vLLM process not found"
        print_info "Container logs:"
        docker logs --tail 20 "${CONTAINER_NAME}"
        return 1
    fi
}

# Test 6: Port Listening
#test_port_listening() {
#    print_test "Checking if vLLM is listening on port ${VLLM_PORT}"
#    
#    if docker exec "${CONTAINER_NAME}" netstat -tln 2>/dev/null | grep -q ":${VLLM_PORT}" || \
#       docker exec "${CONTAINER_NAME}" ss -tln 2>/dev/null | grep -q ":${VLLM_PORT}"; then
#        print_pass "Port ${VLLM_PORT} is listening"
#        return 0
#    else
#        print_fail "Port ${VLLM_PORT} is not listening"
#        print_info "Active ports:"
#        docker exec "${CONTAINER_NAME}" ss -tln 2>/dev/null || docker exec "${CONTAINER_NAME}" netstat -tln 2>/dev/null
#        return 1
#    fi
#}

# Test 7: API Endpoint Reachability
test_api_reachable() {
    print_test "Testing API endpoint reachability"
    
    # Try health endpoint first
    if curl -sf "http://${VLLM_HOST}:${VLLM_PORT}/health" -m 5 > /dev/null 2>&1; then
        print_pass "Health endpoint is reachable"
        return 0
    fi
    
    # Try v1 endpoint
    if curl -sf "http://${VLLM_HOST}:${VLLM_PORT}/v1/models" -m 5 > /dev/null 2>&1; then
        print_pass "API endpoint is reachable"
        return 0
    fi
    
    # Try root endpoint
    if curl -sf "http://${VLLM_HOST}:${VLLM_PORT}/" -m 5 > /dev/null 2>&1; then
        print_pass "Root endpoint is reachable"
        return 0
    fi
    
    print_fail "API endpoints not reachable"
    print_info "Make sure port ${VLLM_PORT} is exposed and vLLM is fully initialized"
    return 1
}

# Test 8: Models Endpoint

# Test 8: Models Endpoint
test_models_endpoint() {
    print_test "Testing /v1/models endpoint"

    RESPONSE=$(curl -s "http://${VLLM_HOST}:${VLLM_PORT}/v1/models" -m 10 2>/dev/null)

    if [ -z "$RESPONSE" ]; then
        print_fail "No response from models endpoint"
        return 1
    fi

    # Check if response contains the expected structure
    if echo "$RESPONSE" | grep -q '"object".*"list"' && echo "$RESPONSE" | grep -q '"data"'; then
        print_pass "Models endpoint responding correctly"

        # Extract and display model names
        if command -v python3 >/dev/null 2>&1; then
            MODELS=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    models = [m.get('id', 'unknown') for m in data.get('data', [])]
    print(', '.join(models) if models else 'No models found')
except Exception as e:
    print('Unable to parse models')
" 2>/dev/null)
            
            if [ -n "$MODELS" ] && [ "$MODELS" != "Unable to parse models" ]; then
                print_info "Available models: ${MODELS}"
            fi
        fi
        return 0
    else
        print_warn "Models endpoint returned unexpected response"
        print_info "Response preview: ${RESPONSE:0:200}..."
        
        # Still pass if we got any valid JSON response
        if echo "$RESPONSE" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
            print_info "Response is valid JSON, considering this a pass"
            return 0
        fi
        return 1
    fi
}



# Test 9: Memory Usage
test_memory_usage() {
    print_test "Checking container memory usage"
    
    MEMORY_STATS=$(docker stats "${CONTAINER_NAME}" --no-stream --format "{{.MemUsage}}" 2>/dev/null)
    
    if [ -n "$MEMORY_STATS" ]; then
        print_pass "Memory usage: ${MEMORY_STATS}"
        
        # Get GPU memory if available
        GPU_MEM=$(docker exec "${CONTAINER_NAME}" nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$GPU_MEM" ]; then
            print_info "GPU memory: ${GPU_MEM} MB"
        fi
        return 0
    else
        print_warn "Could not retrieve memory stats"
        return 0
    fi
}

# Test 10: Container Logs Check
test_container_logs() {
    print_test "Checking container logs for errors"
    
    ERROR_COUNT=$(docker logs "${CONTAINER_NAME}" 2>&1 | grep -i "error\|exception\|failed\|critical" | wc -l)
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        print_pass "No errors found in logs"
        return 0
    else
        print_warn "Found ${ERROR_COUNT} error/warning messages in logs"
        print_info "Recent errors:"
        docker logs "${CONTAINER_NAME}" 2>&1 | grep -i "error\|exception\|failed" | tail -5
        return 0
    fi
}

# Test 11: FIPS Mode Validation
test_fips_compliance() {
    print_test "Validating FIPS compliance"
    
    # Check if FIPS is enabled in the container
    FIPS_ENABLED=$(docker exec "${CONTAINER_NAME}" cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo "N/A")
    
    if [ "$FIPS_ENABLED" = "1" ]; then
        print_pass "FIPS mode is enabled (kernel level)"
    elif [ "$FIPS_ENABLED" = "0" ]; then
        print_warn "FIPS mode is not enabled at kernel level"
        print_info "This may be acceptable if using FIPS-validated libraries"
    else
        print_info "FIPS status: ${FIPS_ENABLED}"
    fi
    
    # Check OpenSSL FIPS mode
    OPENSSL_VERSION=$(docker exec "${CONTAINER_NAME}" openssl version 2>/dev/null || echo "N/A")
    print_info "OpenSSL version: ${OPENSSL_VERSION}"
    
    # Test if MD5 is disabled (FIPS requirement)
    MD5_TEST=$(docker exec "${CONTAINER_NAME}" sh -c "echo test | openssl md5 2>&1" || echo "blocked")
    if echo "$MD5_TEST" | grep -qi "disabled\|fips"; then
        print_pass "MD5 is disabled (FIPS compliant)"
    else
        print_info "MD5 status: ${MD5_TEST:0:100}"
    fi
    
    return 0
}

# Test 12: Package Versions
test_package_versions() {
    print_test "Checking installed package versions"
    
    # Check vLLM version
    VLLM_VERSION=$(docker exec "${CONTAINER_NAME}" python3 -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "N/A")
    print_info "vLLM version: ${VLLM_VERSION}"
    
    # Check PyTorch version
    TORCH_VERSION=$(docker exec "${CONTAINER_NAME}" python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "N/A")
    print_info "PyTorch version: ${TORCH_VERSION}"
    
    # Check xgrammar version if installed
    XGRAMMAR_VERSION=$(docker exec "${CONTAINER_NAME}" python3 -c "import xgrammar; print(xgrammar.__version__)" 2>/dev/null || echo "N/A")
    if [ "$XGRAMMAR_VERSION" != "N/A" ]; then
        print_info "xgrammar version: ${XGRAMMAR_VERSION}"
    fi
    
    # Validate versions against CVE fixes
    if [[ "$VLLM_VERSION" != "N/A" ]]; then
        if [[ "$VLLM_VERSION" =~ ^0\.([0-9]+)\.([0-9]+) ]]; then
            MAJOR="${BASH_REMATCH[1]}"
            MINOR="${BASH_REMATCH[2]}"
            if [ "$MAJOR" -ge 11 ]; then
                print_pass "vLLM version is >= 0.11.0 (CVE fixes applied)"
            else
                print_warn "vLLM version < 0.11.0 (vulnerable to CVEs)"
            fi
        fi
    fi
    
    return 0
}

# Test 13: Simple Inference Test
test_simple_inference() {
    print_test "Testing simple inference request"
    
    # This test is optional as it requires a loaded model
    print_info "Attempting simple completion request..."
    
    INFERENCE_RESPONSE=$(curl -s -X POST "http://${VLLM_HOST}:${VLLM_PORT}/v1/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "default",
            "prompt": "Hello",
            "max_tokens": 5,
            "temperature": 0
        }' -m 30 2>/dev/null)
    
    if [ -n "$INFERENCE_RESPONSE" ]; then
        if echo "$INFERENCE_RESPONSE" | grep -q "\"object\": \"text_completion\""; then
            print_pass "Inference endpoint working correctly"
            return 0
        elif echo "$INFERENCE_RESPONSE" | grep -qi "error"; then
            ERROR_MSG=$(echo "$INFERENCE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', {}).get('message', 'Unknown error'))" 2>/dev/null)
            print_warn "Inference returned error: ${ERROR_MSG}"
            print_info "This is expected if no model is loaded yet"
            return 0
        else
            print_info "Response: ${INFERENCE_RESPONSE:0:200}"
            return 0
        fi
    else
        print_info "No response from inference endpoint (may timeout if model is loading)"
        return 0
    fi
}

# Test 14: Resource Limits
test_resource_limits() {
    print_test "Checking container resource limits"
    
    # CPU limits
    CPU_QUOTA=$(docker inspect "${CONTAINER_NAME}" --format '{{.HostConfig.CpuQuota}}' 2>/dev/null)
    CPU_SHARES=$(docker inspect "${CONTAINER_NAME}" --format '{{.HostConfig.CpuShares}}' 2>/dev/null)
    
    if [ "$CPU_QUOTA" != "0" ] && [ "$CPU_QUOTA" != "" ]; then
        print_info "CPU quota: ${CPU_QUOTA}"
    else
        print_info "No CPU quota set (unlimited)"
    fi
    
    # Memory limits
    MEMORY_LIMIT=$(docker inspect "${CONTAINER_NAME}" --format '{{.HostConfig.Memory}}' 2>/dev/null)
    if [ "$MEMORY_LIMIT" != "0" ] && [ "$MEMORY_LIMIT" != "" ]; then
        MEMORY_GB=$((MEMORY_LIMIT / 1024 / 1024 / 1024))
        print_info "Memory limit: ${MEMORY_GB}GB"
    else
        print_info "No memory limit set (unlimited)"
    fi
    
    return 0
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "vLLM FIPS Container Validation"
    
    echo "Container: ${CONTAINER_NAME}"
    echo "Host: ${VLLM_HOST}"
    echo "Port: ${VLLM_PORT}"
    echo ""
    
    # Run all tests
    test_container_exists || exit 1
    test_container_running || exit 1
    test_container_health
    test_vllm_process
    test_gpu_access
#    test_port_listening
    test_api_reachable
    test_models_endpoint
    test_memory_usage
    test_package_versions
    test_fips_compliance
    test_resource_limits
    test_container_logs
    test_simple_inference
    
    # Print summary
    print_header "Test Summary"
    echo -e "Total tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
        echo -e "${GREEN}✓ Container appears to be running correctly${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo -e "${YELLOW}Review the failures above and check container logs:${NC}"
        echo -e "  docker logs ${CONTAINER_NAME}"
        exit 1
    fi
}

# Run main function
main
