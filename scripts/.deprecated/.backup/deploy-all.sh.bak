#!/bin/bash
#===============================================================================
# deploy-all.sh
#
# Complete orchestrator for DistriAgent Platform
# Deploys infrastructure + MCP Server in a single command
#
# Usage:
#   ./scripts/deploy-all.sh                    # Full: Infra + MCP
#   ./scripts/deploy-all.sh --skip-infra       # MCP Server only
#   ./scripts/deploy-all.sh --skip-mcp         # Infrastructure only
#   ./scripts/deploy-all.sh --what-if          # Preview without deploying
#
# Options:
#   --skip-infra          Skip infrastructure deployment (use existing)
#   --skip-mcp            Skip MCP Server build & deploy
#   --what-if             Preview mode (no actual deployment)
#   --auto                Non-interactive mode (use defaults)
#   --project <name>      Project name prefix (default: distriplatform)
#   --help                Show this help
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Flags
SKIP_INFRA=false
SKIP_MCP=false
WHAT_IF=false
AUTO_MODE=false
PROJECT_NAME="distriplatform"

# Logging
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║   🚀 DistriAgent Platform - Full Deployment                                   ║"
    echo "║                                                                               ║"
    echo "║   Infrastructure (Bicep) + MCP Server (Container Apps)                        ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

show_help() {
    head -22 "$0" | tail -19
    exit 0
}

check_azure_login() {
    if ! az account show &>/dev/null; then
        log_warning "Not logged in to Azure CLI"
        az login
    fi
    
    if ! azd auth login --check-status &>/dev/null; then
        log_warning "Not logged in to Azure Developer CLI"
        azd auth login --use-device-code
    fi
}

get_acr_name() {
    # ACR name derived from project name (no hyphens allowed)
    echo "${PROJECT_NAME//[^a-zA-Z0-9]/}acr"
}

check_infra_exists() {
    local rg_name="RG-DistriAgentPlatform"
    local acr_name
    acr_name=$(get_acr_name)
    
    # Check if RG and ACR exist
    if az group show --name "$rg_name" &>/dev/null && \
       az acr show --name "$acr_name" &>/dev/null; then
        return 0
    fi
    return 1
}

get_aca_environment() {
    local rg_name="RG-DistriAgentPlatform"
    az containerapp env list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null || echo ""
}

#===============================================================================
# Parse Arguments
#===============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-infra) SKIP_INFRA=true; shift ;;
        --skip-mcp) SKIP_MCP=true; shift ;;
        --what-if) WHAT_IF=true; shift ;;
        --auto) AUTO_MODE=true; shift ;;
        --project) PROJECT_NAME="$2"; shift 2 ;;
        --help|-h) show_help ;;
        *) log_error "Unknown option: $1"; show_help ;;
    esac
done

#===============================================================================
# Main
#===============================================================================

print_banner

# Check authentication
print_header "🔐 Checking Azure Authentication"
check_azure_login

SUBSCRIPTION=$(az account show --query name -o tsv)
log_success "Logged in to: $SUBSCRIPTION"
echo ""

# Show plan
print_header "📋 Deployment Plan"

echo -e "${BOLD}Project:${NC} $PROJECT_NAME"
echo ""

if [ "$SKIP_INFRA" = true ]; then
    echo -e "  1. Infrastructure:  ${YELLOW}SKIP${NC} (--skip-infra)"
else
    if [ "$WHAT_IF" = true ]; then
        echo -e "  1. Infrastructure:  ${CYAN}PREVIEW ONLY${NC}"
    else
        echo -e "  1. Infrastructure:  ${GREEN}DEPLOY${NC}"
    fi
    echo -e "     • Resource Group, Log Analytics, App Insights"
    echo -e "     • Storage, CosmosDB, AI Search"
    echo -e "     • Container Registry, Key Vault"
    echo -e "     • Container Apps Environment"
    echo -e "     • AI Foundry (Hub + Project)"
    echo -e "     • Communication Service + Email"
fi

echo ""

if [ "$SKIP_MCP" = true ]; then
    echo -e "  2. MCP Server:      ${YELLOW}SKIP${NC} (--skip-mcp)"
else
    if [ "$WHAT_IF" = true ]; then
        echo -e "  2. MCP Server:      ${YELLOW}SKIP (what-if mode)${NC}"
    else
        echo -e "  2. MCP Server:      ${GREEN}BUILD & DEPLOY${NC}"
        echo -e "     • Build .NET project"
        echo -e "     • Create Docker image"
        echo -e "     • Push to ACR"
        echo -e "     • Deploy to Container Apps"
    fi
fi

echo ""

# Confirm
if [ "$AUTO_MODE" = false ] && [ "$WHAT_IF" = false ]; then
    echo -en "${BOLD}Proceed with deployment?${NC} [Y/n]: "
    read -r response
    if [[ "${response,,}" == "n" ]]; then
        log_warning "Deployment cancelled"
        exit 0
    fi
fi

#===============================================================================
# Step 1: Infrastructure
#===============================================================================

if [ "$SKIP_INFRA" = false ]; then
    print_header "🏗️  Step 1: Deploying Infrastructure"
    
    INFRA_ARGS=""
    [ "$WHAT_IF" = true ] && INFRA_ARGS="--what-if"
    [ "$AUTO_MODE" = true ] && INFRA_ARGS="$INFRA_ARGS --auto --yes"
    
    "$SCRIPT_DIR/deploy-infrastructure.sh" $INFRA_ARGS
    
    if [ "$WHAT_IF" = true ]; then
        log_info "What-if completed. Run without --what-if to deploy."
        exit 0
    fi
    
    log_success "Infrastructure deployed"
else
    print_header "🏗️  Step 1: Infrastructure"
    
    if check_infra_exists; then
        log_success "Using existing infrastructure"
    else
        log_error "Infrastructure not found. Run without --skip-infra first."
        exit 1
    fi
fi

#===============================================================================
# Step 2: MCP Server
#===============================================================================

if [ "$SKIP_MCP" = false ] && [ "$WHAT_IF" = false ]; then
    print_header "📦 Step 2: Building & Deploying MCP Server"
    
    ACR_NAME=$(get_acr_name)
    
    # Verify ACR exists
    if ! az acr show --name "$ACR_NAME" &>/dev/null; then
        log_error "ACR '$ACR_NAME' not found. Deploy infrastructure first."
        exit 1
    fi
    
    log_info "Using ACR: $ACR_NAME"
    
    # Run MCP deployment
    "$SCRIPT_DIR/deploy-custom-mcp.sh" --acr-name "$ACR_NAME"
    
    log_success "MCP Server deployed"
fi

#===============================================================================
# Summary
#===============================================================================

print_header "🎉 Deployment Complete!"

echo -e "${BOLD}Resources deployed:${NC}"
echo ""

RG_NAME="RG-DistriAgentPlatform"

# Get key outputs
ACR_NAME=$(get_acr_name)
ACA_ENV=$(get_aca_environment)

echo -e "  ${BOLD}Resource Group:${NC}        $RG_NAME"
echo -e "  ${BOLD}Container Registry:${NC}    ${ACR_NAME}.azurecr.io"
[ -n "$ACA_ENV" ] && echo -e "  ${BOLD}Container Apps Env:${NC}    $ACA_ENV"

echo ""

# Get MCP endpoint if deployed
if [ "$SKIP_MCP" = false ] && [ -f "$ROOT_DIR/remoteAzureMCP/.azure/"*"/config.json" ] 2>/dev/null; then
    MCP_ENDPOINT=$(azd env get-values -C "$ROOT_DIR/remoteAzureMCP" 2>/dev/null | grep "MCP_ENDPOINT" | cut -d'=' -f2 | tr -d '"')
    if [ -n "$MCP_ENDPOINT" ]; then
        echo -e "${BOLD}🔗 MCP Server Endpoint:${NC}"
        echo -e "   ${GREEN}$MCP_ENDPOINT${NC}"
        echo ""
    fi
fi

echo -e "${BOLD}Next steps:${NC}"
echo "  1. Configure your MCP client with the endpoint above"
echo "  2. Test: auth_context_get, auth_context_set, resourcegraph_query"
echo "  3. View resources in Azure Portal: https://portal.azure.com"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ All done! Your DistriAgent Platform is ready.                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
