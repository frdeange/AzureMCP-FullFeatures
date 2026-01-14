# Azure MCP Server - DistriAgent Platform

A customized Azure MCP Server deployment with full infrastructure-as-code for Azure Container Apps, AI Foundry, and supporting services.

## 🚀 Quick Start

### Option 1: GitHub Codespaces (Recommended)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/frdeange/AzureMCP-FullFeatures)

1. Click the badge above or go to **Code** → **Codespaces** → **Create codespace on main**
2. Wait for the container to build (~2-3 minutes)
3. Login to Azure: `az login`
4. Deploy everything: `./scripts/deploy-all.sh`

### Option 2: VS Code Dev Container

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) and [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Clone the repository:
   ```bash
   git clone https://github.com/frdeange/AzureMCP-FullFeatures.git
   ```
4. Open in VS Code and click **"Reopen in Container"** when prompted
5. Login to Azure: `az login`
6. Deploy: `./scripts/deploy-all.sh`

### Option 3: Local Development

Prerequisites:
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Node.js 20+](https://nodejs.org/)

```bash
az login
./scripts/deploy-all.sh
```

---

## 📁 Project Structure

```
├── core/                           # Core MCP libraries
│   ├── Azure.Mcp.Core/            # Azure MCP core functionality
│   ├── Microsoft.Mcp.Core/        # Microsoft MCP core
│   └── ...
│
├── servers/
│   └── Azure.Mcp.Server/          # Main MCP Server implementation
│
├── tools/                          # MCP Toolsets (Azure services)
│   ├── Azure.Mcp.Tools.Acr/
│   ├── Azure.Mcp.Tools.Cosmos/
│   ├── Azure.Mcp.Tools.Foundry/
│   └── ... (30+ Azure service tools)
│
├── infrastructure/                 # Bicep infrastructure-as-code
│   ├── main.bicep                 # Main deployment orchestrator
│   ├── parameters.json            # Default parameters
│   └── modules/                   # Modular Bicep templates
│       ├── ai-foundry.bicep       # AI Foundry Account + Project
│       ├── ai-search.bicep        # Azure AI Search
│       ├── cosmos-db.bicep        # CosmosDB (Serverless)
│       ├── storage-account.bicep  # Storage Account
│       ├── key-vault.bicep        # Key Vault
│       ├── container-registry.bicep
│       ├── container-apps-environment.bicep
│       ├── communication-service.bicep
│       ├── rbac-assignments.bicep # Role assignments
│       └── ...
│
├── scripts/                        # Deployment automation
│   ├── deploy-all.sh              # Full deployment (infra + app)
│   ├── deploy-infrastructure.sh   # Infrastructure only
│   └── deploy-custom-mcp.sh       # MCP Server only
│
├── Dockerfile                      # Container image definition
└── .devcontainer/                  # Dev Container configuration
```

---

## 🛠️ Deployment Scripts

### `deploy-all.sh` - Full Deployment
Deploys infrastructure and MCP Server in one command.

```bash
./scripts/deploy-all.sh [OPTIONS]

Options:
  --auto          Skip confirmations
  --skip-infra    Skip infrastructure deployment
  --skip-app      Skip MCP Server deployment
  --help          Show help
```

### `deploy-infrastructure.sh` - Infrastructure Only
Deploys all Azure resources using Bicep.

```bash
./scripts/deploy-infrastructure.sh [OPTIONS]

Options:
  --resource-group, -g    Resource group name (default: RG-DistriAgentPlatform)
  --location, -l          Azure region (default: swedencentral)
  --project-name, -n      Project name prefix (default: distriplatform)
  --help                  Show help
```

### `deploy-custom-mcp.sh` - MCP Server Only
Builds and deploys the MCP Server to Container Apps.

```bash
./scripts/deploy-custom-mcp.sh [OPTIONS]

Options:
  --resource-group, -g    Resource group name
  --registry, -r          ACR name
  --help                  Show help
```

---

## 🏗️ Infrastructure Resources

The deployment creates the following Azure resources:

| Resource | Name | Description |
|----------|------|-------------|
| **Resource Group** | `RG-DistriAgentPlatform` | Container for all resources |
| **Log Analytics** | `distriplatform-loganalytics` | Centralized logging |
| **Application Insights** | `distriplatform-appinsight` | Application monitoring |
| **Storage Account** | `distriplatformstorage` | Blob storage for AI Foundry |
| **CosmosDB** | `distriplatform-cosmos` | Serverless NoSQL database |
| **AI Search** | `distriplatform-search` | Azure AI Search service |
| **Key Vault** | `distriplatformkv` | Secrets management |
| **Container Registry** | `distriplatformacr` | Docker image registry |
| **Container Apps Env** | `distriplatform-aca-env` | Container Apps environment |
| **AI Foundry Account** | `distriplatform-ai-foundry` | Azure AI Services hub |
| **AI Foundry Project** | `distriplatform-ai-project` | AI project workspace |
| **Communication Service** | `distriplatform-comm` | Email and SMS capabilities |

### AI Foundry Connections

The AI Foundry Account is automatically connected to:
- ✅ Storage Account (AAD auth)
- ✅ Key Vault (AAD auth)
- ✅ AI Search (AAD auth)
- ✅ CosmosDB (AAD auth)
- ✅ Application Insights (API Key)

### RBAC Role Assignments

Managed identities are configured with these roles:

| Identity | Resource | Role |
|----------|----------|------|
| AI Foundry Account | Storage | Blob Data Contributor |
| AI Foundry Account | Key Vault | Key Vault Secrets Officer |
| AI Foundry Account | AI Search | Search Index Data Contributor |
| AI Foundry Account | CosmosDB | DocumentDB Account Contributor |
| AI Foundry Account | ACR | AcrPush |
| AI Foundry Project | Storage | Blob Data Contributor |
| AI Foundry Project | Key Vault | Key Vault Secrets User |
| AI Foundry Project | AI Search | Search Index Data Reader |
| AI Foundry Project | ACR | AcrPull |

---

## 🔧 Custom MCP Tools

This fork includes custom tools in addition to the standard Azure MCP tools:

| Tool | Command | Description |
|------|---------|-------------|
| **Auth Context Get** | `azmcp auth context get` | Get current Azure authentication context |
| **Auth Context Set** | `azmcp auth context set` | Set default subscription |
| **Resource Graph Query** | `azmcp resourcegraph query` | Execute KQL queries against Azure Resource Graph |

---

## 🐳 Dev Container Features

The development container includes:

| Tool | Version | Description |
|------|---------|-------------|
| **.NET SDK** | 10.0 | Build and run .NET applications |
| **Node.js** | 20.x | JavaScript runtime |
| **Azure CLI** | Latest | Azure management |
| **Azure Developer CLI** | Latest | `azd` for deployments |
| **Docker-in-Docker** | Latest | Build containers inside container |
| **PowerShell** | Latest | Cross-platform scripting |

### VS Code Extensions (Auto-installed)

- C# Dev Kit
- PowerShell
- Azure CLI Tools
- GitHub Copilot & Copilot Chat
- Azure GitHub Copilot Extension
- ESLint
- Code Spell Checker

---

## 📝 Configuration

### Parameters

Edit `infrastructure/parameters.json` to customize:

```json
{
  "projectName": { "value": "distriplatform" },
  "location": { "value": "swedencentral" },
  "resourceGroupName": { "value": "RG-DistriAgentPlatform" },
  "storageAccountSku": { "value": "Standard_LRS" },
  "containerRegistrySku": { "value": "Basic" },
  "cosmosDbConsistencyLevel": { "value": "Session" },
  "searchServiceSku": { "value": "basic" }
}
```

### Environment Variables

The MCP Server supports these environment variables:

| Variable | Description |
|----------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Default Azure subscription |
| `AZURE_TENANT_ID` | Azure AD tenant |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection |

---

## 🔒 Security

- **Managed Identity**: All Azure operations use System Assigned Managed Identity
- **AAD Authentication**: AI Foundry connections use Azure AD (no API keys where possible)
- **RBAC**: Principle of least privilege with specific role assignments
- **Key Vault**: Secrets stored securely, not in code or config files
- **Local Auth Disabled**: AI Foundry has `disableLocalAuth: true`

---

## 🧪 Development

### Build locally

```bash
dotnet build
```

### Run tests

```bash
dotnet test
```

### Build Docker image

```bash
dotnet publish servers/Azure.Mcp.Server/src -c Release -r linux-musl-x64 --self-contained -o .work/build
docker build -t azure-mcp-custom:latest .
```

---

## 📚 Documentation

- [Authentication Guide](docs/Authentication.md)
- [AOT Compatibility](docs/aot-compatibility.md)
- [Recorded Tests](docs/recorded-tests.md)
- [Changelog](docs/changelog-entries.md)

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## 📄 License

See [LICENSE](LICENSE) for license information.

---

## 🆘 Support

- [SUPPORT.md](SUPPORT.md) - Support information
- [SECURITY.md](SECURITY.md) - Security policy
- [Issues](https://github.com/frdeange/AzureMCP-FullFeatures/issues) - Report bugs or request features
