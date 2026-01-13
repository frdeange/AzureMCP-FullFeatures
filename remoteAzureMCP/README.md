# Azure MCP Server - ACA with Managed Identity (Full Access)

This document explains how to deploy the [Azure MCP Server 2.0-beta](https://mcr.microsoft.com/product/azure-sdk/azure-mcp) as a remote MCP server accessible over HTTPS. This enables AI agents from [Microsoft Foundry](https://azure.microsoft.com/products/ai-foundry) and [Microsoft Copilot Studio](https://www.microsoft.com/microsoft-copilot/microsoft-copilot-studio) to securely invoke MCP tool calls that perform Azure operations on your behalf.

This reference Azure Developer CLI (azd) template shows how to host the server on Azure Container Apps with **ALL Azure services enabled** (~40+ tools), using managed identity authentication and subscription-level RBAC roles for comprehensive Azure access.

## Prerequisites

- Azure subscription with **Owner** or **User Access Administrator** permissions
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)

## Quick Start

This reference template deploys the Azure MCP Server with **ALL Azure tools enabled**, accessible over HTTPS transport. 

```bash
azd up
```

You'll be prompted for:
- **Use existing Container Apps Environment** - Choose whether to create a new environment or use an existing one
- **Existing Environment Name** - (If using existing) The name of your Container Apps Environment
- **Existing Environment Resource Group** - (If using existing and in different RG) The resource group name
- **Read-only mode** - Whether to restrict the MCP server to read-only operations
- **Microsoft Foundry Project Resource ID** - The Azure resource ID of the Microsoft Foundry project for agent integration

## What Gets Deployed

- **Container App** - Runs Azure MCP Server with ALL namespaces/tools enabled
- **Subscription-level Role Assignments** - Container App managed identity granted comprehensive roles:
  - Contributor (full resource management)
  - Storage Blob/Table/Queue Data Contributor
  - Key Vault Secrets/Certificates/Crypto Officer
  - Cosmos DB Account Contributor
  - Service Bus Data Owner
  - Event Grid Contributor
  - Event Hubs Data Owner
  - Redis Cache Contributor
  - App Configuration Data Owner
  - Log Analytics Contributor
  - Monitoring Contributor
  - Search Service Contributor
  - Cognitive Services Contributor
- **Entra App Registration** - For incoming OAuth 2.0 authentication from clients (e.g., agents) with `Mcp.Tools.ReadWrite.All` role
- **Application Insights** - Telemetry and monitoring (optional)

### Deployment Outputs

After deployment, retrieve `azd` outputs:

```bash
azd env get-values
```

Among the output there are useful values for the subsequent steps. Here is an example of these values.

```
CONTAINER_APP_URL="https://azure-mcp-storage-server.wonderfulazmcp-a9561afd.eastus2.azurecontainerapps.io"
ENTRA_APP_CLIENT_ID="c3248eaf-3bdd-4ca7-9483-4fcf213e4d4d"
ENTRA_APP_IDENTIFIER_URI="api://c3248eaf-3bdd-4ca7-9483-4fcf213e4d4d"
ENTRA_APP_OBJECT_ID="a89055df-ccfc-4aef-a7c6-9561bc4c5386"
ENTRA_APP_ROLE_ID="3e60879b-a1bd-5faf-bb8c-cb55e3bfeeb8"
ENTRA_APP_SERVICE_PRINCIPAL_ID="31b42369-583b-40b7-a535-ad343f75e463"
```

## Using Azure MCP Server from Microsoft Foundry Agent

Once deployed, connect your Microsoft Foundry agent to the Azure MCP Server running on Azure Container Apps. The agent will authenticate using its managed identity and gain access to **all Azure MCP tools**.

1. Get your Container App URL from `azd` output: `CONTAINER_APP_URL`
2. Get Entra App Client ID from `azd` output: `ENTRA_APP_CLIENT_ID`
2. Navigate to your Foundry project: https://ai.azure.com/nextgen
3. Go to **Build** → **Create agent**  
4. Select the **+ Add** in the tools section
5. Select the **Custom** tab 
6. Choose **Model Context Protocol** as the tool and click **Create** ![Find MCP](images/azure__create-aif-agent-mcp-tool.png)
7. Configure the MCP connection ![Create MCP Connection](images/azure__add_aif_mcp_connection.png)
   - Enter the `CONTAINER_APP_URL` value as the Remote MCP Server endpoint. 
   - Select **Microsoft Entra** → **Project Managed Identity**  as the authentication method
   - Enter your `ENTRA_APP_CLIENT_ID` as the audience.
   - Click **Connect** to associate this connection to the agent

Your agent is now ready to assist you! It can answer your questions and leverage **all 40+ tools** from the Azure MCP Server to perform Azure operations on your behalf.

## Clean Up

```bash
azd down
```

## Template Structure

The `azd` template consists of the following Bicep modules:

- **`main.bicep`** - Orchestrates the deployment of all resources and subscription-level role assignments
- **`aca-infrastructure.bicep`** - Deploys Container App hosting the Azure MCP Server (supports using existing environment)
- **`subscription-role-assignment.bicep`** - Assigns RBAC roles at subscription level for comprehensive Azure access
- **`entra-app.bicep`** - Creates Entra App registration with custom app role for OAuth 2.0 authentication
- **`foundry-role-assignment-entraapp.bicep`** - Assigns Entra App role to the managed identity of the Microsoft Foundry project
- **`application-insights.bicep`** - Deploys Application Insights for telemetry and monitoring (optional)

## Security Considerations

⚠️ **WARNING**: This template grants broad subscription-level permissions to the MCP server. For production environments, consider:

1. **Limiting scope**: Modify role assignments to target specific resource groups instead of the entire subscription
2. **Using read-only mode**: Set `READ_ONLY_MODE=true` to prevent write operations
3. **Removing unused roles**: Comment out role assignments for services you don't need
4. **Network isolation**: Consider adding VNet integration for additional security

## Supported Azure Services

With ALL namespaces enabled, the MCP server supports 40+ Azure services including:

- **Storage**: Blob, Table, Queue, File operations
- **Databases**: Cosmos DB, SQL, PostgreSQL, MySQL, Redis
- **Security**: Key Vault (secrets, keys, certificates)
- **Messaging**: Service Bus, Event Grid, Event Hubs
- **AI/ML**: AI Foundry, AI Search, Cognitive Services
- **Compute**: App Service, Functions, AKS, Container Apps
- **Monitoring**: Azure Monitor, Log Analytics, Application Insights
- **And many more...**

See the [complete list of supported services](https://github.com/microsoft/mcp/tree/main/servers/Azure.Mcp.Server#complete-list-of-supported-azure-services).

