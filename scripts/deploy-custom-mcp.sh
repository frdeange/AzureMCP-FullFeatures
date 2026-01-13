#!/bin/bash
#===============================================================================
# deploy-custom-mcp.sh
# 
# Script to build and deploy a custom version of Azure MCP Server
# to Azure Container Apps using your own Azure Container Registry.
#
# Usage:
#   ./scripts/deploy-custom-mcp.sh --acr-name <name> [options]
#
# Required:
#   --acr-name <name>         ACR name (without .azurecr.io)
#
# Options:
#   --image-name <name>       Image name (default: azure-mcp-custom)
#   --image-tag <tag>         Image tag (default: latest)
#   --skip-build              Skip .NET compilation
#   --skip-docker             Skip Docker build
#   --skip-push               Skip push to ACR
#   --skip-deploy             Skip deployment to ACA
#   --help                    Show this help
#
# Example:
#   ./scripts/deploy-custom-mcp.sh --acr-name myacr
#   ./scripts/deploy-custom-mcp.sh --acr-name myacr --image-name my-mcp --image-tag v1.0
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
ACR_NAME=""
IMAGE_NAME="azure-mcp-custom"
IMAGE_TAG="latest"
SKIP_BUILD=false
SKIP_DOCKER=false
SKIP_PUSH=false
SKIP_DEPLOY=false

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_SERVER_DIR="AzureMCPServer"
SERVER_PROJECT="${MCP_SERVER_DIR}/servers/Azure.Mcp.Server/src"
PUBLISH_DIR="${MCP_SERVER_DIR}/.work/build/Azure.Mcp.Server/linux-musl-x64"
REMOTE_AZD_DIR="remoteAzureMCP"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

show_help() {
    head -30 "$0" | tail -25
    exit 0
}

check_prerequisites() {
    log_step "Checking prerequisites"
    local missing=()
    command -v dotnet &>/dev/null || missing+=("dotnet")
    command -v docker &>/dev/null || missing+=("docker")
    command -v az &>/dev/null || missing+=("az (Azure CLI)")
    command -v azd &>/dev/null || missing+=("azd (Azure Developer CLI)")
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing tools:"
        for tool in "${missing[@]}"; do echo "  - $tool"; done
        exit 1
    fi
    log_success "All prerequisites installed"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --acr-name) ACR_NAME="$2"; shift 2 ;;
        --image-name) IMAGE_NAME="$2"; shift 2 ;;
        --image-tag) IMAGE_TAG="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --skip-docker) SKIP_DOCKER=true; shift ;;
        --skip-push) SKIP_PUSH=true; shift ;;
        --skip-deploy) SKIP_DEPLOY=true; shift ;;
        --help|-h) show_help ;;
        *) log_error "Unknown option: $1"; show_help ;;
    esac
done

# Validate required parameters
if [ -z "$ACR_NAME" ]; then
    log_error "ACR name is required. Use --acr-name <name>"
    echo "Example: ./scripts/deploy-custom-mcp.sh --acr-name myacr"
    exit 1
fi

# Derived variables
ACR_SERVER="${ACR_NAME}.azurecr.io"
FULL_IMAGE_NAME="${ACR_SERVER}/${IMAGE_NAME}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Start
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🚀 Azure MCP Server - Custom Deployment Script                              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}\n"

log_info "Configuration:"
echo "  ACR Server:  ${ACR_SERVER}"
echo "  Image:       ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Timestamp:   ${TIMESTAMP}"
echo ""

cd "$ROOT_DIR"
check_prerequisites

# Step 1: Build .NET project
if [ "$SKIP_BUILD" = false ]; then
    log_step "Step 1: Building .NET project"
    log_info "Publishing for linux-musl-x64 (Alpine Linux)..."
    dotnet publish "$SERVER_PROJECT" -c Release -r linux-musl-x64 --self-contained -o "$PUBLISH_DIR"
    [ -f "$PUBLISH_DIR/azmcp" ] && log_success "Build completed" || { log_error "Build failed"; exit 1; }
else
    log_warning "Skipping build (--skip-build)"
fi

# Step 2: Build Docker image
if [ "$SKIP_DOCKER" = false ]; then
    log_step "Step 2: Building Docker image"
    log_info "Building: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    docker build --platform linux/amd64 \
        --build-arg PUBLISH_DIR="$PUBLISH_DIR" \
        --build-arg EXECUTABLE_NAME=azmcp \
        -t "${FULL_IMAGE_NAME}:${IMAGE_TAG}" \
        -t "${FULL_IMAGE_NAME}:${TIMESTAMP}" \
        -f "${MCP_SERVER_DIR}/Dockerfile" .
    log_success "Docker image built"
else
    log_warning "Skipping Docker build (--skip-docker)"
fi

# Step 3: Push to ACR
if [ "$SKIP_PUSH" = false ]; then
    log_step "Step 3: Pushing to ACR"
    log_info "Authenticating with ACR using admin credentials..."
    
    # Always use admin credentials (more reliable than az acr login)
    ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv 2>/dev/null)
    ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv 2>/dev/null)
    
    if [ -z "$ACR_USER" ] || [ -z "$ACR_PASS" ]; then
        log_error "Failed to get ACR credentials. Ensure admin user is enabled:"
        echo "  az acr update --name $ACR_NAME --admin-enabled true"
        exit 1
    fi
    
    docker logout "$ACR_SERVER" 2>/dev/null || true
    echo "$ACR_PASS" | docker login "$ACR_SERVER" -u "$ACR_USER" --password-stdin
    
    log_info "Pushing image..."
    docker push "${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    log_success "Image pushed to ${ACR_SERVER}"
else
    log_warning "Skipping push (--skip-push)"
fi

# Step 4: Deploy to ACA
if [ "$SKIP_DEPLOY" = false ]; then
    log_step "Step 4: Deploying to Azure Container Apps"
    log_info "Checking azd authentication..."
    azd auth login --check-status &>/dev/null || { log_warning "Logging in..."; azd auth login --use-device-code; }
    cd "$REMOTE_AZD_DIR"
    log_info "Running azd up..."
    azd up
    log_success "Deployment completed"
    
    # Show deployment outputs
    log_step "Step 5: Deployment Information"
    log_info "Azure environment values:"
    echo ""
    azd env get-values | while IFS='=' read -r key value; do
        # Remove quotes from value
        value="${value%\"}"
        value="${value#\"}"
        printf "  %-35s %s\n" "${key}:" "${value}"
    done
    echo ""
    cd "$ROOT_DIR"
else
    log_warning "Skipping deployment (--skip-deploy)"
fi

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Deployment completed successfully!                                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}\n"

log_info "Summary:"
echo "  📦 Image: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
echo "  🏷️  Tag:   ${FULL_IMAGE_NAME}:${TIMESTAMP}"
echo ""
log_info "Next steps:"
echo "  1. Verify deployment in Azure Portal"
echo "  2. Test new tools: auth context get/set, resourcegraph query"
echo "  3. Configure MCP client to connect using the MCP_ENDPOINT above"
echo ""
