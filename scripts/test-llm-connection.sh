#!/bin/bash
# Test LLM Provider Connectivity
#
# Usage:
#   ./scripts/test-llm-connection.sh [provider]
#   ./scripts/test-llm-connection.sh claude
#   ./scripts/test-llm-connection.sh openai
#   ./scripts/test-llm-connection.sh replicate
#   ./scripts/test-llm-connection.sh all

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running in Kubernetes pod
check_kubernetes_context() {
    print_header "Kubernetes Context Check"

    if [ -f /run/secrets/kubernetes.io/serviceaccount/token ]; then
        print_success "Running inside Kubernetes pod"
        IN_KUBERNETES=true
    else
        print_warning "Not running inside Kubernetes pod - ensure API keys are available"
        IN_KUBERNETES=false
    fi
}

# Load environment variables
load_env() {
    print_header "Environment Variables"

    if [ -f .env ]; then
        print_info "Found .env file, loading..."
        set -a
        source .env
        set +a
    elif [ -f k8s/n8n-secret.yaml ]; then
        print_info "Found k8s/n8n-secret.yaml - extract values and set as env vars"
        print_warning "Manual extraction required - see docs for details"
    else
        print_warning "No .env file found - using Kubernetes secrets if available"
    fi

    # Check required variables
    print_info "Checking for configured LLM providers..."

    if [ -n "$CLAUDE_API_KEY" ]; then
        print_success "CLAUDE_API_KEY is set"
        CLAUDE_CONFIGURED=true
    else
        print_warning "CLAUDE_API_KEY not set"
        CLAUDE_CONFIGURED=false
    fi

    if [ -n "$OPENAI_API_KEY" ]; then
        print_success "OPENAI_API_KEY is set"
        OPENAI_CONFIGURED=true
    else
        print_warning "OPENAI_API_KEY not set"
        OPENAI_CONFIGURED=false
    fi

    if [ -n "$REPLICATE_API_TOKEN" ]; then
        print_success "REPLICATE_API_TOKEN is set"
        REPLICATE_CONFIGURED=true
    else
        print_warning "REPLICATE_API_TOKEN not set"
        REPLICATE_CONFIGURED=false
    fi

    echo ""
}

# Test Claude API
test_claude() {
    print_header "Testing Anthropic Claude API"

    if [ ! "$CLAUDE_CONFIGURED" = true ]; then
        print_error "CLAUDE_API_KEY not configured"
        return 1
    fi

    MODEL="${AI_MODEL:-claude-opus-4-5-20251101}"
    print_info "Using model: $MODEL"

    print_info "Sending test request to Claude API..."

    RESPONSE=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d '{
            "model": "'"$MODEL"'",
            "max_tokens": 100,
            "messages": [
                {
                    "role": "user",
                    "content": "Say only the words: Claude API working"
                }
            ]
        }')

    # Check for errors
    if echo "$RESPONSE" | grep -q '"error"'; then
        print_error "Claude API returned an error:"
        echo "$RESPONSE" | jq '.error' 2>/dev/null || echo "$RESPONSE"
        return 1
    fi

    # Extract response
    if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        CONTENT=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null)
        if [ -n "$CONTENT" ]; then
            print_success "Claude API is working!"
            print_info "Response: $CONTENT"
            return 0
        fi
    fi

    print_error "Unexpected response format:"
    echo "$RESPONSE"
    return 1
}

# Test OpenAI API
test_openai() {
    print_header "Testing OpenAI API"

    if [ ! "$OPENAI_CONFIGURED" = true ]; then
        print_error "OPENAI_API_KEY not configured"
        return 1
    fi

    MODEL="${AI_MODEL:-gpt-4o}"
    print_info "Using model: $MODEL"

    print_info "Sending test request to OpenAI API..."

    RESPONSE=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d '{
            "model": "'"$MODEL"'",
            "messages": [
                {
                    "role": "user",
                    "content": "Say only the words: OpenAI API working"
                }
            ],
            "max_tokens": 10
        }')

    # Check for errors
    if echo "$RESPONSE" | grep -q '"error"'; then
        print_error "OpenAI API returned an error:"
        echo "$RESPONSE" | jq '.error' 2>/dev/null || echo "$RESPONSE"
        return 1
    fi

    # Extract response
    if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
        if [ -n "$CONTENT" ]; then
            print_success "OpenAI API is working!"
            print_info "Response: $CONTENT"
            return 0
        fi
    fi

    print_error "Unexpected response format:"
    echo "$RESPONSE"
    return 1
}

# Test Replicate API
test_replicate() {
    print_header "Testing Replicate API"

    if [ ! "$REPLICATE_CONFIGURED" = true ]; then
        print_error "REPLICATE_API_TOKEN not configured"
        return 1
    fi

    MODEL="${REPLICATE_MODEL:-meta/llama-2-70b-chat}"
    print_info "Using model: $MODEL"
    print_warning "Replicate testing requires model version - using default if available"

    print_info "Sending test request to Replicate API..."

    RESPONSE=$(curl -s -X POST https://api.replicate.com/v1/predictions \
        -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "version": "2c1608e18606feda752c7d6d27d9974e5f36bada1301c8b3b287f15985f373a6",
            "input": {
                "prompt": "Say: Replicate API working"
            }
        }')

    # Check for errors
    if echo "$RESPONSE" | grep -q '"error"'; then
        print_error "Replicate API returned an error:"
        echo "$RESPONSE" | jq '.error' 2>/dev/null || echo "$RESPONSE"
        return 1
    fi

    # Extract prediction ID and status
    if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        PREDICTION_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null)
        STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null)
        if [ -n "$PREDICTION_ID" ]; then
            print_success "Replicate API is responding!"
            print_info "Prediction ID: $PREDICTION_ID"
            print_info "Status: $STATUS"
            print_warning "Replicate requests are async - result will be available after processing"
            return 0
        fi
    fi

    print_error "Unexpected response format:"
    echo "$RESPONSE"
    return 1
}

# Network connectivity check
test_network() {
    print_header "Network Connectivity Check"

    ENDPOINTS=(
        "api.anthropic.com"
        "api.openai.com"
        "api.replicate.com"
    )

    for endpoint in "${ENDPOINTS[@]}"; do
        print_info "Testing connectivity to $endpoint..."
        if curl -s --connect-timeout 5 "https://$endpoint" >/dev/null 2>&1; then
            print_success "$endpoint is reachable"
        else
            print_warning "$endpoint is not reachable (check firewall/network)"
        fi
    done
    echo ""
}

# Test if curl and jq are available
check_dependencies() {
    print_header "Dependency Check"

    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        return 1
    fi
    print_success "curl is installed"

    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (for JSON parsing)"
        print_info "Some tests will still work but with reduced output quality"
    else
        print_success "jq is installed"
    fi
    echo ""
}

# Main execution
main() {
    local PROVIDER="${1:-all}"

    echo ""
    print_header "AutoMarket OS - LLM Provider Test"
    echo ""

    # Check dependencies
    check_dependencies

    # Check context
    check_kubernetes_context
    echo ""

    # Load environment
    load_env

    # Test network
    test_network

    # Run tests based on provider argument
    FAILED=0

    case "$PROVIDER" in
        claude)
            test_claude || FAILED=$((FAILED+1))
            ;;
        openai)
            test_openai || FAILED=$((FAILED+1))
            ;;
        replicate)
            test_replicate || FAILED=$((FAILED+1))
            ;;
        all|"")
            echo ""
            test_claude || FAILED=$((FAILED+1))
            echo ""
            test_openai || FAILED=$((FAILED+1))
            echo ""
            test_replicate || FAILED=$((FAILED+1))
            ;;
        *)
            print_error "Unknown provider: $PROVIDER"
            print_info "Usage: $0 [claude|openai|replicate|all]"
            exit 1
            ;;
    esac

    # Summary
    echo ""
    print_header "Test Summary"

    if [ $FAILED -eq 0 ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "$FAILED test(s) failed"
        return 1
    fi
}

# Run main function
main "$@"
