#!/bin/bash
# ============================================================================
# DistriAgent Platform - Unified Deployment Script
# ============================================================================
#
# This script handles the complete deployment of the DistriAgent Platform:
# 1. Infrastructure (Bicep) - All Azure resources
# 2. MCP Server - Build, push to ACR, deploy to Container Apps
#
# Usage:
#   ./deploy.sh                           # Interactive menu mode
#   ./deploy.sh --project myproject       # Specify project name
#   ./deploy.sh --with-mcp                # Include MCP Server deployment
#   ./deploy.sh --mcp-only                # Only deploy MCP (infra must exist)
#   ./deploy.sh --what-if                 # Preview changes only
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Defaults
PROJECT_NAME=""
RESOURCE_GROUP=""
LOCATION="swedencentral"
DEPLOY_MCP=false
MCP_ONLY=false
WHAT_IF=false
IMAGE_NAME="azure-mcp-custom"
IMAGE_TAG="latest"
MCP_READ_ONLY=false
RESOURCE_SUFFIX=""
INTERACTIVE_MODE=true

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║   🚀 DistriAgent Platform - Unified Deployment                                ║"
    echo "║                                                                               ║"
    echo "║   Infrastructure + MCP Server in one command                                  ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Without options, the script runs in interactive menu mode."
    echo ""
    echo "Options:"
    echo "  --project NAME        Project name (used for resource naming)"
    echo "  --resource-group RG   Resource group name (default: RG-{ProjectName})"
    echo "  --location LOC        Azure location (default: swedencentral)"
    echo "  --suffix SUFFIX       Resource suffix to avoid conflicts (default: random 4 chars)"
    echo "  --with-mcp            Include MCP Server deployment"
    echo "  --mcp-only            Only deploy MCP Server (skip infrastructure)"
    echo "  --image-tag TAG       Docker image tag (default: latest)"
    echo "  --mcp-read-only       Deploy MCP in read-only mode"
    echo "  --what-if             Preview deployment without making changes"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 --project myapp --with-mcp"
    echo "  $0 --mcp-only --image-tag v2.0.0"
    exit 0
}

# Generate random suffix (4 lowercase alphanumeric characters)
generate_suffix() {
    echo $(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
}

# ============================================================================
# Parse Arguments
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT_NAME="$2"; INTERACTIVE_MODE=false; shift 2 ;;
        --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
        --location) LOCATION="$2"; shift 2 ;;
        --suffix) RESOURCE_SUFFIX="$2"; shift 2 ;;
        --with-mcp) DEPLOY_MCP=true; shift ;;
        --mcp-only) MCP_ONLY=true; DEPLOY_MCP=true; shift ;;
        --image-tag) IMAGE_TAG="$2"; shift 2 ;;
        --mcp-read-only) MCP_READ_ONLY=true; shift ;;
        --what-if) WHAT_IF=true; shift ;;
        --help|-h) show_help ;;
        *) log_error "Unknown option: $1"; show_help ;;
    esac
done

# ============================================================================
# Interactive Menu Functions
# ============================================================================

show_main_menu() {
    echo ""
    echo -e "${BOLD}What would you like to do?${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 🏗️  Deploy new infrastructure (will ask about MCP)"
    echo -e "  ${CYAN}2)${NC} 🚀 Quick deploy: Infrastructure + MCP Server"
    echo -e "  ${CYAN}3)${NC} 📦 Update MCP Server only (existing infrastructure)"
    echo -e "  ${CYAN}4)${NC} 👁️  Preview (What-If) - See what would be created"
    echo -e "  ${CYAN}5)${NC} ⚙️  Advanced settings"
    echo -e "  ${CYAN}6)${NC} ❌ Exit"
    echo ""
    echo -ne "${BOLD}Select an option [1-6]: ${NC}"
}

show_advanced_menu() {
    echo ""
    echo -e "${BOLD}Advanced Settings${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 📍 Change location (current: ${YELLOW}$LOCATION${NC})"
    echo -e "  ${CYAN}2)${NC} 🔒 MCP read-only mode (current: ${YELLOW}$MCP_READ_ONLY${NC})"
    echo -e "  ${CYAN}3)${NC} 🏷️  Change image tag (current: ${YELLOW}$IMAGE_TAG${NC})"
    echo -e "  ${CYAN}4)${NC} 🔙 Back to main menu"
    echo ""
    echo -ne "${BOLD}Select an option [1-4]: ${NC}"
}

prompt_project_name() {
    echo ""
    echo -e "${BOLD}📝 Project Configuration${NC}"
    echo -e "${DIM}This name will be used to name all Azure resources${NC}"
    echo ""
    
    while true; do
        echo -ne "${BOLD}Project name: ${NC}"
        read -r PROJECT_NAME
        
        if [ -z "$PROJECT_NAME" ]; then
            log_error "Project name is required"
            continue
        fi
        
        # Validate: only lowercase, numbers, and hyphens
        if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
            log_error "Name must be lowercase, numbers, and hyphens (cannot start/end with hyphen)"
            continue
        fi
        
        if [ ${#PROJECT_NAME} -gt 12 ]; then
            log_error "Name must be max 12 characters (Storage Account limit: 24 chars)"
            continue
        fi
        
        break
    done
}

prompt_resource_suffix() {
    echo ""
    local suggested_suffix
    suggested_suffix=$(generate_suffix)
    
    echo -e "${BOLD}🔑 Resource Suffix${NC}"
    echo -e "${DIM}Added to names to avoid conflicts with existing resources${NC}"
    echo ""
    echo -e "Suggested suffix: ${YELLOW}$suggested_suffix${NC}"
    echo ""
    echo -ne "${BOLD}Use suggested suffix? [Y/n] or type a custom one: ${NC}"
    read -r suffix_input
    
    if [ -z "$suffix_input" ] || [[ "$suffix_input" =~ ^[Yy]$ ]]; then
        RESOURCE_SUFFIX="$suggested_suffix"
    elif [[ "$suffix_input" =~ ^[Nn]$ ]]; then
        echo -ne "${BOLD}Enter custom suffix (4 chars): ${NC}"
        read -r RESOURCE_SUFFIX
    else
        RESOURCE_SUFFIX="$suffix_input"
    fi
    
    # Validate suffix
    if [[ ! "$RESOURCE_SUFFIX" =~ ^[a-z0-9]{2,6}$ ]]; then
        log_warning "Invalid suffix, using auto-generated one"
        RESOURCE_SUFFIX=$(generate_suffix)
    fi
}

prompt_resource_group() {
    local default_rg="RG-${PROJECT_NAME^}-${RESOURCE_SUFFIX}"
    
    echo ""
    echo -e "${BOLD}📁 Resource Group${NC}"
    echo -e "Suggested: ${YELLOW}$default_rg${NC}"
    echo ""
    echo -ne "${BOLD}Use suggested name? [Y/n] or type your own: ${NC}"
    read -r rg_input
    
    if [ -z "$rg_input" ] || [[ "$rg_input" =~ ^[Yy]$ ]]; then
        RESOURCE_GROUP="$default_rg"
    elif [[ "$rg_input" =~ ^[Nn]$ ]]; then
        echo -ne "${BOLD}Resource Group name: ${NC}"
        read -r RESOURCE_GROUP
    else
        RESOURCE_GROUP="$rg_input"
    fi
}

prompt_deploy_mcp() {
    echo ""
    echo -e "${BOLD}🖥️  MCP Server${NC}"
    echo -e "${DIM}The MCP Server enables AI agents to access Azure resources${NC}"
    echo ""
    echo -ne "${BOLD}Include MCP Server in deployment? [y/N]: ${NC}"
    read -r mcp_input
    
    if [[ "$mcp_input" =~ ^[Yy]$ ]]; then
        DEPLOY_MCP=true
    else
        DEPLOY_MCP=false
    fi
}

prompt_existing_project() {
    echo ""
    echo -e "${BOLD}📦 Connect to Existing Infrastructure${NC}"
    echo -e "${DIM}Enter the details of your existing deployment${NC}"
    echo ""
    
    # Project name
    while true; do
        echo -ne "${BOLD}Existing project name: ${NC}"
        read -r PROJECT_NAME
        
        if [ -z "$PROJECT_NAME" ]; then
            log_error "Project name is required"
            continue
        fi
        break
    done
    
    # Resource suffix
    echo -ne "${BOLD}Resource suffix (4 chars used during deployment): ${NC}"
    read -r RESOURCE_SUFFIX
    
    if [ -z "$RESOURCE_SUFFIX" ]; then
        log_error "Resource suffix is required to find existing resources"
        exit 1
    fi
    
    # Resource group
    local default_rg="RG-${PROJECT_NAME^}-${RESOURCE_SUFFIX}"
    echo -e "Expected Resource Group: ${YELLOW}$default_rg${NC}"
    echo -ne "${BOLD}Use this Resource Group? [Y/n] or type different: ${NC}"
    read -r rg_input
    
    if [ -z "$rg_input" ] || [[ "$rg_input" =~ ^[Yy]$ ]]; then
        RESOURCE_GROUP="$default_rg"
    else
        RESOURCE_GROUP="$rg_input"
    fi
    
    # Verify ACR exists
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    local acr_name="${full_project_name//[^a-zA-Z0-9]/}acr"
    
    echo ""
    log_info "Verifying infrastructure exists..."
    
    if ! az acr show --name "$acr_name" &>/dev/null; then
        log_error "ACR '$acr_name' not found. Please check project name and suffix."
        exit 1
    fi
    
    log_success "Found ACR: $acr_name"
}

show_mcp_only_summary() {
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    # Container App names must be lowercase
    local container_app_name=$(echo "${full_project_name}-mcp" | tr '[:upper:]' '[:lower:]')
    local acr_name=$(echo "${full_project_name//[^a-zA-Z0-9]/}acr" | tr '[:upper:]' '[:lower:]')
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📋 MCP Server Deployment${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Project:${NC}         $PROJECT_NAME"
    echo -e "  ${BOLD}Suffix:${NC}          $RESOURCE_SUFFIX"
    echo -e "  ${BOLD}Resource Group:${NC}  $RESOURCE_GROUP"
    echo -e "  ${BOLD}Image Tag:${NC}       $IMAGE_TAG"
    echo -e "  ${BOLD}Read-Only Mode:${NC}  $([ "$MCP_READ_ONLY" = true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")"
    echo ""
    echo -e "${BOLD}Actions to perform:${NC}"
    echo -e "  1. Build .NET project (AzureMCPServer)"
    echo -e "  2. Create Docker image"
    echo -e "  3. Push to ACR: ${acr_name}"
    echo -e "  4. Deploy/Update Container App: ${container_app_name}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "${BOLD}Confirm and proceed? [Y/n]: ${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warning "Deployment cancelled"
        exit 0
    fi
}

show_deployment_summary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📋 Configuration Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Project:${NC}         $PROJECT_NAME"
    echo -e "  ${BOLD}Suffix:${NC}          $RESOURCE_SUFFIX"
    echo -e "  ${BOLD}Resource Group:${NC}  $RESOURCE_GROUP"
    echo -e "  ${BOLD}Location:${NC}        $LOCATION"
    echo -e "  ${BOLD}Deploy MCP:${NC}      $([ "$DEPLOY_MCP" = true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")"
    if [ "$DEPLOY_MCP" = true ]; then
        echo -e "  ${BOLD}MCP Read-Only:${NC}   $([ "$MCP_READ_ONLY" = true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")"
        echo -e "  ${BOLD}Image Tag:${NC}       $IMAGE_TAG"
    fi
    echo -e "  ${BOLD}What-If Mode:${NC}    $([ "$WHAT_IF" = true ] && echo "${YELLOW}Yes (preview only)${NC}" || echo "No")"
    echo ""
    echo -e "${BOLD}Resources to be created:${NC}"
    echo -e "  • ${PROJECT_NAME}${RESOURCE_SUFFIX}storage    ${DIM}(Storage Account)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-cosmos   ${DIM}(CosmosDB)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-search   ${DIM}(AI Search)${NC}"
    echo -e "  • ${PROJECT_NAME}${RESOURCE_SUFFIX}acr        ${DIM}(Container Registry)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-kv       ${DIM}(Key Vault)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-logs     ${DIM}(Log Analytics)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-appins   ${DIM}(Application Insights)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-comm     ${DIM}(Communication Service)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-aifdry   ${DIM}(AI Foundry Hub)${NC}"
    echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-aiproj   ${DIM}(AI Foundry Project)${NC}"
    if [ "$DEPLOY_MCP" = true ]; then
        echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-aca-env ${DIM}(Container Apps Environment)${NC}"
        echo -e "  • ${PROJECT_NAME}-${RESOURCE_SUFFIX}-mcp  ${DIM}(MCP Container App)${NC}"
    fi
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "${BOLD}Confirm and proceed? [Y/n]: ${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warning "Deployment cancelled"
        exit 0
    fi
}

run_interactive_mode() {
    print_banner
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)  # New infrastructure
                MCP_ONLY=false
                WHAT_IF=false
                prompt_project_name
                prompt_resource_suffix
                prompt_resource_group
                prompt_deploy_mcp
                show_deployment_summary
                break
                ;;
            2)  # Infrastructure + MCP (shortcut)
                DEPLOY_MCP=true
                MCP_ONLY=false
                WHAT_IF=false
                prompt_project_name
                prompt_resource_suffix
                prompt_resource_group
                show_deployment_summary
                break
                ;;
            3)  # MCP only (existing infrastructure)
                DEPLOY_MCP=true
                MCP_ONLY=true
                WHAT_IF=false
                prompt_existing_project
                show_mcp_only_summary
                break
                ;;
            4)  # What-If
                WHAT_IF=true
                MCP_ONLY=false
                prompt_project_name
                prompt_resource_suffix
                prompt_resource_group
                prompt_deploy_mcp
                show_deployment_summary
                break
                ;;
            5)  # Advanced
                while true; do
                    show_advanced_menu
                    read -r adv_choice
                    case $adv_choice in
                        1)
                            echo -ne "${BOLD}New location: ${NC}"
                            read -r LOCATION
                            ;;
                        2)
                            MCP_READ_ONLY=$([ "$MCP_READ_ONLY" = true ] && echo false || echo true)
                            log_info "MCP Read-Only: $MCP_READ_ONLY"
                            ;;
                        3)
                            echo -ne "${BOLD}Image tag: ${NC}"
                            read -r IMAGE_TAG
                            ;;
                        4)
                            break
                            ;;
                        *)
                            log_error "Invalid option"
                            ;;
                    esac
                done
                ;;
            6)  # Exit
                echo ""
                log_info "Goodbye! 👋"
                exit 0
                ;;
            *)
                log_error "Invalid option. Select 1-6"
                ;;
        esac
    done
}

# ============================================================================
# Azure Authentication Check
# ============================================================================

check_azure_auth() {
    log_step "Checking Azure Authentication"
    
    if ! az account show &>/dev/null; then
        log_warning "Not logged in to Azure CLI"
        az login
    fi
    
    local subscription
    subscription=$(az account show --query name -o tsv)
    log_success "Connected to: $subscription"
}

# ============================================================================
# Validate Prerequisites
# ============================================================================

validate_prerequisites() {
    log_step "Validating Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    log_success "Azure CLI installed"
    
    # Check Docker if MCP deployment
    if [ "$DEPLOY_MCP" = true ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker is required to deploy MCP"
            exit 1
        fi
        log_success "Docker installed"
    fi
    
    # Check Bicep
    if ! az bicep version &>/dev/null; then
        log_warning "Installing Bicep..."
        az bicep install
    fi
    log_success "Bicep available"
}

# ============================================================================
# Infrastructure Deployment
# ============================================================================

deploy_infrastructure() {
    log_step "Deploying Infrastructure"
    
    log_info "Project: $PROJECT_NAME"
    log_info "Suffix: $RESOURCE_SUFFIX"
    log_info "Resource Group: $RESOURCE_GROUP"
    log_info "Location: $LOCATION"
    echo ""
    
    # Get deployer principal ID for RBAC
    local deployer_id
    deployer_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
    
    # Build the full project name with suffix for resources
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    
    # Build deployment command
    local deploy_cmd="az deployment sub create \
        --name \"deploy-${PROJECT_NAME}-$(date +%Y%m%d%H%M%S)\" \
        --location \"$LOCATION\" \
        --template-file \"$INFRA_DIR/main.bicep\" \
        --parameters projectName=\"$full_project_name\" \
        --parameters resourceGroupName=\"$RESOURCE_GROUP\" \
        --parameters location=\"$LOCATION\" \
        --parameters deployMcpServer=false"
    
    # Add deployer principal if available
    if [ -n "$deployer_id" ]; then
        deploy_cmd+=" --parameters deployerPrincipalId=\"$deployer_id\""
    fi
    
    # Add what-if flag if needed
    if [ "$WHAT_IF" = true ]; then
        deploy_cmd+=" --what-if"
    fi
    
    log_info "Running Bicep deployment..."
    eval "$deploy_cmd"
    
    if [ "$WHAT_IF" = false ]; then
        log_success "Infrastructure deployed successfully!"
        
        # Get outputs
        export ACR_NAME="${full_project_name//[^a-zA-Z0-9]/}acr"
        export ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv 2>/dev/null || echo "")
        
        log_info "ACR: $ACR_SERVER"
    fi
}

# ============================================================================
# MCP Server Build & Push
# ============================================================================

build_and_push_mcp() {
    log_step "Building MCP Server"
    
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    
    # The MCP Server is in AzureMCPServer/servers/Azure.Mcp.Server/src/
    local mcp_root="$REPO_ROOT/AzureMCPServer"
    local mcp_src_dir="$mcp_root/servers/Azure.Mcp.Server/src"
    local publish_dir="$mcp_src_dir/bin/Release/net9.0/linux-x64/publish"
    local executable_name="azmcp"
    local dockerfile_path="$mcp_root/Dockerfile"
    
    # Verify MCP project exists
    if [ ! -d "$mcp_src_dir" ]; then
        log_error "MCP Server project not found at: $mcp_src_dir"
        exit 1
    fi
    
    # Step 1: Build and publish the .NET project
    log_info "Step 1/4: Building .NET project..."
    cd "$mcp_src_dir"
    
    dotnet publish \
        -c Release \
        -r linux-x64 \
        --self-contained true \
        -p:PublishSingleFile=true \
        -p:PublishTrimmed=false \
        -o "$publish_dir"
    
    if [ ! -f "$publish_dir/$executable_name" ]; then
        log_error "Build failed: executable not found at $publish_dir/$executable_name"
        exit 1
    fi
    
    log_success ".NET build completed"
    
    # Step 2: Ensure ACR credentials
    log_info "Step 2/4: Connecting to ACR..."
    if [ -z "$ACR_SERVER" ]; then
        ACR_NAME="${full_project_name//[^a-zA-Z0-9]/}acr"
        ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
    fi
    
    if [ -z "$ACR_SERVER" ]; then
        log_error "Could not determine ACR server. Deploy infrastructure first."
        exit 1
    fi
    
    # Login to ACR
    az acr login --name "$ACR_NAME"
    log_success "Connected to ACR: $ACR_SERVER"
    
    # Step 3: Build Docker image
    log_info "Step 3/4: Building Docker image..."
    local full_image="${ACR_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ ! -f "$dockerfile_path" ]; then
        log_error "Dockerfile not found at: $dockerfile_path"
        exit 1
    fi
    
    # PUBLISH_DIR must be relative to Docker context (mcp_root)
    local publish_dir_relative="servers/Azure.Mcp.Server/src/bin/Release/net9.0/linux-x64/publish"
    
    docker build \
        -t "$full_image" \
        -f "$dockerfile_path" \
        --build-arg PUBLISH_DIR="$publish_dir_relative" \
        --build-arg EXECUTABLE_NAME="$executable_name" \
        "$mcp_root"
    
    log_success "Docker image built: $full_image"
    
    # Step 4: Push to ACR
    log_info "Step 4/4: Pushing image to ACR..."
    docker push "$full_image"
    
    log_success "Image pushed to ACR: $full_image"
    
    export FULL_IMAGE_NAME="$full_image"
    cd "$REPO_ROOT"
}

# ============================================================================
# MCP Server Deployment
# ============================================================================

deploy_mcp_server() {
    log_step "Deploying MCP Server"
    
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    # Container App names must be lowercase
    local container_app_name=$(echo "${full_project_name}-mcp" | tr '[:upper:]' '[:lower:]')
    local aca_env_name=$(echo "${full_project_name}-aca-env" | tr '[:upper:]' '[:lower:]')
    
    # Get ACR credentials
    ACR_NAME="${full_project_name//[^a-zA-Z0-9]/}acr"
    ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
    ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
    ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)
    
    local full_image="${ACR_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ "$MCP_ONLY" = true ]; then
        # MCP Only mode: Create or Update Container App directly
        
        # Check if Container App exists
        if az containerapp show --name "$container_app_name" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
            log_info "Updating existing Container App: $container_app_name"
            
            az containerapp update \
                --name "$container_app_name" \
                --resource-group "$RESOURCE_GROUP" \
                --image "$full_image"
            
            log_success "MCP Server updated successfully!"
        else
            log_info "Container App not found. Creating new one..."
            
            # Check if ACA Environment exists
            if ! az containerapp env show --name "$aca_env_name" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
                log_info "Creating Container Apps Environment: $aca_env_name"
                
                az containerapp env create \
                    --name "$aca_env_name" \
                    --resource-group "$RESOURCE_GROUP" \
                    --location "$LOCATION"
                
                log_success "Container Apps Environment created"
            fi
            
            log_info "Creating Container App: $container_app_name"
            
            az containerapp create \
                --name "$container_app_name" \
                --resource-group "$RESOURCE_GROUP" \
                --environment "$aca_env_name" \
                --image "$full_image" \
                --registry-server "$ACR_SERVER" \
                --registry-username "$ACR_USER" \
                --registry-password "$ACR_PASS" \
                --target-port 8080 \
                --ingress external \
                --min-replicas 0 \
                --max-replicas 3 \
                --cpu 0.5 \
                --memory 1Gi \
                --env-vars "ASPNETCORE_ENVIRONMENT=Production" "MCP_READ_ONLY=$MCP_READ_ONLY"
            
            log_success "MCP Server created successfully!"
        fi
    else
        # Full deployment mode: Use Bicep
        log_info "Deploying MCP via Bicep..."
        
        local deploy_cmd="az deployment sub create \
            --name \"deploy-mcp-${PROJECT_NAME}-$(date +%Y%m%d%H%M%S)\" \
            --location \"$LOCATION\" \
            --template-file \"$INFRA_DIR/main.bicep\" \
            --parameters projectName=\"$full_project_name\" \
            --parameters resourceGroupName=\"$RESOURCE_GROUP\" \
            --parameters location=\"$LOCATION\" \
            --parameters deployMcpServer=true \
            --parameters mcpContainerImage=\"${IMAGE_NAME}:${IMAGE_TAG}\" \
            --parameters mcpReadOnlyMode=$MCP_READ_ONLY \
            --parameters containerRegistryUsername=\"$ACR_USER\" \
            --parameters containerRegistryPassword=\"$ACR_PASS\""
        
        if [ "$WHAT_IF" = true ]; then
            deploy_cmd+=" --what-if"
        fi
        
        eval "$deploy_cmd"
        
        log_success "MCP Server deployed successfully!"
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_final_summary() {
    local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     🎉 Deployment Completed!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Deployed resources:${NC}"
    echo -e "  📁 Resource Group:     $RESOURCE_GROUP"
    echo -e "  💾 Storage:            ${full_project_name//[^a-zA-Z0-9]/}storage"
    echo -e "  🗄️  CosmosDB:           ${full_project_name}-cosmos"
    echo -e "  🔍 AI Search:          ${full_project_name}-search"
    echo -e "  📦 Container Registry: ${full_project_name//[^a-zA-Z0-9]/}acr"
    echo -e "  🔐 Key Vault:          ${full_project_name//[^a-zA-Z0-9]/}kv"
    echo -e "  📊 Log Analytics:      ${full_project_name}-logs"
    echo -e "  📈 App Insights:       ${full_project_name}-appins"
    echo -e "  📧 Communication:      ${full_project_name}-comm"
    echo -e "  🧠 AI Foundry Hub:     ${full_project_name}-aifdry"
    echo -e "  📊 AI Foundry Project: ${full_project_name}-aiproj"
    
    if [ "$DEPLOY_MCP" = true ]; then
        echo -e "  🌐 ACA Environment:   ${full_project_name}-aca-env"
        echo -e "  🖥️  MCP Server:        ${full_project_name}-mcp"
        
        # Try to get MCP URL
        local mcp_url
        mcp_url=$(az containerapp show \
            --name "${full_project_name}-mcp" \
            --resource-group "$RESOURCE_GROUP" \
            --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null || echo "")
        
        if [ -n "$mcp_url" ]; then
            echo ""
            echo -e "${BOLD}🔗 MCP Server URL:${NC} ${CYAN}https://${mcp_url}${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  1. Configure models in AI Foundry from the Azure Portal"
    echo -e "  2. Connect your MCP client to the deployed server"
    if [ "$DEPLOY_MCP" = true ]; then
        echo -e "  3. Test the connection: ${DIM}curl https://\${MCP_URL}/health${NC}"
    fi
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    # If in interactive mode and no project specified, show menu
    if [ "$INTERACTIVE_MODE" = true ] && [ -z "$PROJECT_NAME" ]; then
        run_interactive_mode
    else
        # Non-interactive: validate we have required params
        if [ -z "$PROJECT_NAME" ]; then
            log_error "--project NAME is required in non-interactive mode"
            exit 1
        fi
        
        # Generate suffix if not provided
        if [ -z "$RESOURCE_SUFFIX" ]; then
            RESOURCE_SUFFIX=$(generate_suffix)
            log_info "Generated suffix: $RESOURCE_SUFFIX"
        fi
        
        # Generate resource group if not provided
        if [ -z "$RESOURCE_GROUP" ]; then
            RESOURCE_GROUP="RG-${PROJECT_NAME^}-${RESOURCE_SUFFIX}"
        fi
        
        print_banner
    fi
    
    # Validate
    check_azure_auth
    validate_prerequisites
    
    # Deploy
    if [ "$MCP_ONLY" = false ]; then
        deploy_infrastructure
    else
        # Ensure we have ACR info for MCP-only deploy
        local full_project_name="${PROJECT_NAME}-${RESOURCE_SUFFIX}"
        ACR_NAME="${full_project_name//[^a-zA-Z0-9]/}acr"
        ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv 2>/dev/null)
        
        if [ -z "$ACR_SERVER" ]; then
            log_error "ACR not found. Run full deployment first (without --mcp-only)"
            exit 1
        fi
    fi
    
    if [ "$DEPLOY_MCP" = true ] && [ "$WHAT_IF" = false ]; then
        build_and_push_mcp
        deploy_mcp_server
    fi
    
    # Summary
    if [ "$WHAT_IF" = false ]; then
        print_final_summary
    else
        echo ""
        log_info "What-If analysis completed. No changes were made."
    fi
}

main "$@"
