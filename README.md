# Azure MCP Server - Custom Deployment Project

This repository combines a customized Azure MCP Server with infrastructure-as-code for deploying it to Azure Container Apps.

## Project Structure

```
├── AzureMCPServer/          # Customized Azure MCP Server source code
│   ├── core/                # Core MCP libraries and areas
│   ├── servers/             # MCP Server implementation
│   ├── tools/               # MCP Toolsets (Azure services)
│   ├── docs/                # Documentation
│   ├── Dockerfile           # Container image definition
│   └── ...
│
├── remoteAzureMCP/          # Azure infrastructure (azd template)
│   ├── infra/               # Bicep templates
│   │   ├── main.bicep
│   │   └── modules/
│   └── azure.yaml           # azd configuration
│
├── scripts/                 # Automation scripts
│   └── deploy-custom-mcp.sh # Full deployment automation
│
└── .devcontainer/           # Dev container configuration
```

## Custom Tools Added

This fork includes the following custom tools:

| Tool | Command | Description |
|------|---------|-------------|
| **Auth Context Get** | `azmcp auth context get` | Get current Azure authentication context (tenants, subscriptions, defaults) |
| **Auth Context Set** | `azmcp auth context set` | Set default subscription for Azure operations |
| **Resource Graph Query** | `azmcp resourcegraph query` | Execute KQL queries against Azure Resource Graph |

## Quick Start

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)

### Deploy to Azure Container Apps

1. **Using the automated script:**
   ```bash
   ./scripts/deploy-custom-mcp.sh
   ```

2. **Manual deployment:**
   ```bash
   # Build
   cd AzureMCPServer
   dotnet publish servers/Azure.Mcp.Server/src -c Release -r linux-musl-x64 --self-contained -o .work/build/Azure.Mcp.Server/linux-musl-x64

   # Build Docker image
   docker build -t myacr.azurecr.io/azure-mcp-custom:latest .

   # Push to ACR
   az acr login --name myacr
   docker push myacr.azurecr.io/azure-mcp-custom:latest

   # Deploy infrastructure
   cd ../remoteAzureMCP
   azd up
   ```

## Configuration

### Container Registry

The deployment requires an Azure Container Registry. Configure these parameters during `azd up`:

- `containerRegistryServer`: Your ACR server (e.g., `myacr.azurecr.io`)
- `containerRegistryUsername`: ACR admin username
- `containerRegistryPassword`: ACR admin password

### Security Notes

- The MCP Server uses Managed Identity for Azure operations
- Entra ID authentication is required for incoming requests
- Never disable HTTP incoming auth in production

## Development

### Building locally

```bash
cd AzureMCPServer
dotnet build
```

### Running tests

```bash
cd AzureMCPServer
dotnet test
```

## License

See [AzureMCPServer/LICENSE](AzureMCPServer/LICENSE) for the original Azure MCP Server license.
