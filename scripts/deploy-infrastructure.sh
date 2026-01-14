#!/bin/bash
#===============================================================================
# deploy-infrastructure.sh
#
# Interactive script to deploy DistriAgent Platform infrastructure
#
# Features:
#   - Interactive wizard to configure parameters
#   - Preview mode (what-if)
#   - Validates inputs
#   - Shows cost estimation hints
#   - Supports both interactive and non-interactive modes
#
# Usage:
#   ./deploy-infrastructure.sh              # Interactive mode
#   ./deploy-infrastructure.sh --auto       # Use defaults from parameters.json
#   ./deploy-infrastructure.sh --what-if    # Preview only
#   ./deploy-infrastructure.sh --destroy    # Delete all resources
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
INFRA_DIR="$ROOT_DIR/infrastructure"
PARAMETERS_FILE="$INFRA_DIR/parameters.json"
TEMP_PARAMS_FILE="$INFRA_DIR/.parameters.generated.json"

# Default values
DEFAULT_PROJECT_NAME="distriplatform"
DEFAULT_LOCATION="swedencentral"
DEFAULT_RG_NAME="RG-DistriAgentPlatform"

# Flags
INTERACTIVE=true
WHAT_IF=false
DESTROY=false
AUTO_APPROVE=false

#===============================================================================
# Helper Functions
#===============================================================================

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_banner() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║   🏗️  DistriAgent Platform - Infrastructure Deployment                        ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Read input with default value
read_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local value
    
    if [ -n "$default" ]; then
        echo -en "${BOLD}$prompt${NC} [${CYAN}$default${NC}]: "
    else
        echo -en "${BOLD}$prompt${NC}: "
    fi
    
    read -r value
    value="${value:-$default}"
    eval "$var_name='$value'"
}

# Read yes/no input
read_yes_no() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local value
    
    local default_display="y/n"
    [ "$default" = "true" ] && default_display="Y/n"
    [ "$default" = "false" ] && default_display="y/N"
    
    echo -en "${BOLD}$prompt${NC} [$default_display]: "
    read -r value
    
    case "${value,,}" in
        y|yes|si|sí) eval "$var_name=true" ;;
        n|no) eval "$var_name=false" ;;
        "") eval "$var_name=$default" ;;
        *) eval "$var_name=$default" ;;
    esac
}

# Select from list
select_option() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    shift 3
    local options=("$@")
    
    echo -e "\n${BOLD}$prompt${NC}"
    local i=1
    for opt in "${options[@]}"; do
        if [ "$opt" = "$default" ]; then
            echo -e "  ${CYAN}$i)${NC} $opt ${GREEN}(default)${NC}"
        else
            echo -e "  ${CYAN}$i)${NC} $opt"
        fi
        ((i++))
    done
    
    echo -en "Select [1-${#options[@]}]: "
    read -r selection
    
    if [ -z "$selection" ]; then
        eval "$var_name='$default'"
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
        eval "$var_name='${options[$((selection-1))]}'"
    else
        eval "$var_name='$default'"
    fi
}

#===============================================================================
# Validation Functions
#===============================================================================

validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]{2,20}$ ]]; then
        log_error "Project name must be 3-21 chars, lowercase, start with letter, only letters/numbers/hyphens"
        return 1
    fi
    return 0
}

validate_rg_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]{1,90}$ ]]; then
        log_error "Resource group name invalid (1-90 chars, alphanumeric, dots, underscores, hyphens)"
        return 1
    fi
    return 0
}

#===============================================================================
# Azure Functions
#===============================================================================

check_azure_login() {
    if ! az account show &>/dev/null; then
        log_warning "Not logged in to Azure"
        echo -en "Do you want to login now? [Y/n]: "
        read -r response
        if [[ "${response,,}" != "n" ]]; then
            az login
        else
            log_error "Azure login required"
            exit 1
        fi
    fi
}

get_azure_locations() {
    az account list-locations --query "[?metadata.regionType=='Physical'].name" -o tsv 2>/dev/null | sort
}

show_subscription_info() {
    local sub_info
    sub_info=$(az account show --query "{name:name, id:id, tenant:tenantId}" -o tsv)
    local sub_name sub_id tenant_id
    read -r sub_name sub_id tenant_id <<< "$sub_info"
    
    echo -e "  ${BOLD}Subscription:${NC} $sub_name"
    echo -e "  ${BOLD}ID:${NC}           $sub_id"
    echo -e "  ${BOLD}Tenant:${NC}       $tenant_id"
}

#===============================================================================
# Interactive Configuration
#===============================================================================

run_wizard() {
    print_header "📝 Configuration Wizard"
    
    echo -e "Let's configure your infrastructure. Press ${CYAN}Enter${NC} to accept defaults.\n"
    
    # Project Name
    while true; do
        read_input "Project name (prefix for all resources)" "$DEFAULT_PROJECT_NAME" "PROJECT_NAME"
        validate_project_name "$PROJECT_NAME" && break
    done
    
    # Resource Group Name
    while true; do
        read_input "Resource Group name" "$DEFAULT_RG_NAME" "RG_NAME"
        validate_rg_name "$RG_NAME" && break
    done
    
    # Location
    echo ""
    select_option "Select Azure region" "$DEFAULT_LOCATION" "LOCATION" \
        "swedencentral" "westeurope" "northeurope" "eastus" "eastus2" "westus2"
    
    # Optional Resources
    print_header "🔧 Optional Resources"
    echo -e "Select which optional resources to create:\n"
    
    read_yes_no "Create Container Apps Environment?" "true" "CREATE_ACA"
    read_yes_no "Create AI Foundry (Hub + Project + Key Vault)?" "true" "CREATE_AI_FOUNDRY"
    read_yes_no "Create Communication Service with Email?" "true" "CREATE_COMM"
    
    # SKU Selection
    print_header "💰 Resource Tiers"
    echo -e "Select resource tiers (affects cost):\n"
    
    select_option "Storage Account SKU" "Standard_LRS" "STORAGE_SKU" \
        "Standard_LRS" "Standard_GRS" "Standard_ZRS"
    
    select_option "Azure Container Registry SKU" "Basic" "ACR_SKU" \
        "Basic" "Standard" "Premium"
    
    select_option "Azure AI Search SKU" "basic" "SEARCH_SKU" \
        "free" "basic" "standard"
    
    select_option "CosmosDB consistency level" "Session" "COSMOS_CONSISTENCY" \
        "Session" "Eventual" "Strong"
}

show_summary() {
    print_header "📋 Configuration Summary"
    
    echo -e "${BOLD}General:${NC}"
    echo -e "  Project Name:      ${CYAN}$PROJECT_NAME${NC}"
    echo -e "  Resource Group:    ${CYAN}$RG_NAME${NC}"
    echo -e "  Location:          ${CYAN}$LOCATION${NC}"
    echo ""
    
    echo -e "${BOLD}Core Resources:${NC}"
    echo -e "  • Log Analytics Workspace:     ${GREEN}${PROJECT_NAME}-loganalytics${NC}"
    echo -e "  • Application Insights:        ${GREEN}${PROJECT_NAME}-appinsight${NC}"
    echo -e "  • Storage Account:             ${GREEN}${PROJECT_NAME//[^a-zA-Z0-9]/}storage${NC} ($STORAGE_SKU)"
    echo -e "  • CosmosDB (Serverless):       ${GREEN}${PROJECT_NAME}-cosmos${NC} ($COSMOS_CONSISTENCY)"
    echo -e "  • Azure AI Search:             ${GREEN}${PROJECT_NAME}-search${NC} ($SEARCH_SKU)"
    echo -e "  • Container Registry:          ${GREEN}${PROJECT_NAME//[^a-zA-Z0-9]/}acr${NC} ($ACR_SKU)"
    echo ""
    
    echo -e "${BOLD}Optional Resources:${NC}"
    if [ "$CREATE_ACA" = "true" ]; then
        echo -e "  • Container Apps Environment:  ${GREEN}${PROJECT_NAME}-aca-env${NC}"
    else
        echo -e "  • Container Apps Environment:  ${YELLOW}Skipped${NC}"
    fi
    
    if [ "$CREATE_AI_FOUNDRY" = "true" ]; then
        echo -e "  • Key Vault:                   ${GREEN}${PROJECT_NAME//[^a-zA-Z0-9]/}kv${NC}"
        echo -e "  • AI Foundry Hub:              ${GREEN}${PROJECT_NAME}-ai-hub${NC}"
        echo -e "  • AI Foundry Project:          ${GREEN}${PROJECT_NAME}-ai-project${NC}"
    else
        echo -e "  • AI Foundry + Key Vault:      ${YELLOW}Skipped${NC}"
    fi
    
    if [ "$CREATE_COMM" = "true" ]; then
        echo -e "  • Communication Service:       ${GREEN}${PROJECT_NAME}-comm${NC}"
        echo -e "  • Email Service:               ${GREEN}${PROJECT_NAME}-comm-email${NC}"
    else
        echo -e "  • Communication Service:       ${YELLOW}Skipped${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}Estimated deployment time:${NC} 5-15 minutes"
    echo ""
}

generate_parameters_file() {
    cat > "$TEMP_PARAMS_FILE" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "projectName": { "value": "$PROJECT_NAME" },
    "location": { "value": "$LOCATION" },
    "resourceGroupName": { "value": "$RG_NAME" },
    "tags": {
      "value": {
        "project": "DistriAgentPlatform",
        "environment": "dev",
        "managedBy": "bicep",
        "createdBy": "$(whoami)",
        "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      }
    },
    "storageAccountSku": { "value": "$STORAGE_SKU" },
    "containerRegistrySku": { "value": "$ACR_SKU" },
    "cosmosDbConsistencyLevel": { "value": "$COSMOS_CONSISTENCY" },
    "searchServiceSku": { "value": "$SEARCH_SKU" },
    "createContainerAppsEnvironment": { "value": $CREATE_ACA },
    "createAIFoundry": { "value": $CREATE_AI_FOUNDRY },
    "createCommunicationService": { "value": $CREATE_COMM }
  }
}
EOF
    log_success "Generated parameters file"
}

#===============================================================================
# Deployment Functions
#===============================================================================

run_deployment() {
    local params_file="$1"
    local what_if="$2"
    
    local deployment_name="distriplatform-$(date +%Y%m%d-%H%M%S)"
    
    if [ "$what_if" = "true" ]; then
        print_header "🔍 What-If Analysis (Preview)"
        log_info "Analyzing changes without deploying..."
        
        az deployment sub what-if \
            --location "$LOCATION" \
            --template-file "$INFRA_DIR/main.bicep" \
            --parameters "@$params_file" \
            --name "$deployment_name"
    else
        print_header "🚀 Deploying Infrastructure"
        
        az deployment sub create \
            --location "$LOCATION" \
            --template-file "$INFRA_DIR/main.bicep" \
            --parameters "@$params_file" \
            --name "$deployment_name" \
            --output table
        
        log_success "Deployment completed!"
        
        # Show outputs
        print_header "📤 Deployment Outputs"
        az deployment sub show \
            --name "$deployment_name" \
            --query "properties.outputs" \
            -o json 2>/dev/null | jq -r 'to_entries[] | "  \(.key): \(.value.value)"' 2>/dev/null || true
    fi
}

run_destroy() {
    print_header "🗑️  Destroy Infrastructure"
    
    log_warning "This will DELETE the resource group and ALL resources inside!"
    echo ""
    
    read_input "Enter Resource Group name to delete" "" "RG_TO_DELETE"
    
    if [ -z "$RG_TO_DELETE" ]; then
        log_error "Resource group name required"
        exit 1
    fi
    
    echo ""
    log_warning "You are about to delete: $RG_TO_DELETE"
    read_input "Type the resource group name again to confirm" "" "CONFIRM_RG"
    
    if [ "$RG_TO_DELETE" != "$CONFIRM_RG" ]; then
        log_error "Names don't match. Aborting."
        exit 1
    fi
    
    log_info "Deleting resource group $RG_TO_DELETE..."
    az group delete --name "$RG_TO_DELETE" --yes --no-wait
    log_success "Deletion initiated (running in background)"
}

#===============================================================================
# Parse Arguments
#===============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto) INTERACTIVE=false; shift ;;
        --what-if) WHAT_IF=true; shift ;;
        --destroy) DESTROY=true; shift ;;
        --yes|-y) AUTO_APPROVE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --auto        Use parameters.json without prompts"
            echo "  --what-if     Preview changes without deploying"
            echo "  --destroy     Delete resource group"
            echo "  --yes, -y     Skip confirmation prompts"
            echo "  --help, -h    Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#===============================================================================
# Main
#===============================================================================

print_banner

# Check prerequisites
print_header "🔐 Azure Authentication"
check_azure_login
show_subscription_info
echo ""

# Handle destroy
if [ "$DESTROY" = "true" ]; then
    run_destroy
    exit 0
fi

# Configure parameters
if [ "$INTERACTIVE" = "true" ]; then
    run_wizard
    show_summary
    generate_parameters_file
    PARAMS_FILE="$TEMP_PARAMS_FILE"
    
    if [ "$AUTO_APPROVE" != "true" ]; then
        echo ""
        read_yes_no "Proceed with deployment?" "true" "PROCEED"
        if [ "$PROCEED" != "true" ]; then
            log_warning "Deployment cancelled"
            # Save parameters for later
            cp "$TEMP_PARAMS_FILE" "$PARAMETERS_FILE"
            log_info "Parameters saved to parameters.json"
            exit 0
        fi
    fi
else
    # Use existing parameters file
    if [ ! -f "$PARAMETERS_FILE" ]; then
        log_error "parameters.json not found. Run without --auto for interactive mode."
        exit 1
    fi
    PARAMS_FILE="$PARAMETERS_FILE"
    LOCATION=$(jq -r '.parameters.location.value' "$PARAMS_FILE")
    log_info "Using parameters from: $PARAMETERS_FILE"
fi

# Validate Bicep
print_header "✅ Validating Bicep Template"
if az bicep build --file "$INFRA_DIR/main.bicep" --stdout > /dev/null 2>&1; then
    log_success "Template is valid"
else
    log_error "Template validation failed"
    az bicep build --file "$INFRA_DIR/main.bicep"
    exit 1
fi

# Run deployment
run_deployment "$PARAMS_FILE" "$WHAT_IF"

# Cleanup
[ -f "$TEMP_PARAMS_FILE" ] && rm -f "$TEMP_PARAMS_FILE"

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Done!                                                                    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
