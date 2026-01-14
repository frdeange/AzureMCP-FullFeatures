# DistriAgent Platform - Infrastructure

Este directorio contiene los archivos Bicep para desplegar toda la infraestructura de la plataforma DistriAgent.

## Recursos que se despliegan

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| Resource Group | `RG-DistriAgentPlatform` | Grupo de recursos contenedor |
| Log Analytics | `distriplatform-loganalytics` | Workspace para logs y monitoreo |
| Application Insights | `distriplatform-appinsight` | Telemetría de aplicaciones |
| Storage Account | `distriplatformstorage` | Almacenamiento para AI Foundry |
| CosmosDB | `distriplatform-cosmos` | Base de datos NoSQL serverless |
| Azure AI Search | `distriplatform-search` | Servicio de búsqueda semántica |
| Container Apps Environment | `distriplatform-aca-env` | Entorno para Container Apps |
| AI Foundry Hub | `distriplatform-ai-hub` | Hub de Azure AI |
| AI Foundry Project | `distriplatform-ai-project` | Proyecto de Azure AI |
| Key Vault | `distriplatformaikv` | Almacén de secretos para AI |

## Estructura de archivos

```
infrastructure/
├── main.bicep                              # Orquestador principal (subscription scope)
├── parameters.json                         # Parámetros de despliegue
├── deploy-infrastructure.sh                # Script de despliegue
├── README.md                               # Este archivo
└── modules/
    ├── log-analytics.bicep                 # Log Analytics Workspace
    ├── application-insights.bicep          # Application Insights
    ├── storage-account.bicep               # Storage Account
    ├── cosmos-db.bicep                     # CosmosDB (NoSQL, Serverless)
    ├── ai-search.bicep                     # Azure AI Search
    ├── container-apps-environment.bicep    # Container Apps Environment
    └── ai-foundry.bicep                    # AI Hub + Project + Key Vault
```

## Uso

### Prerequisitos

- Azure CLI instalado (`az`)
- Sesión activa en Azure (`az login`)
- Permisos de Owner o Contributor en la subscription

### Desplegar infraestructura

```bash
# Desde el directorio infrastructure/
cd infrastructure

# Preview de cambios (sin ejecutar)
./deploy-infrastructure.sh --what-if

# Desplegar
./deploy-infrastructure.sh
```

### Opciones del script

```bash
./deploy-infrastructure.sh [options]

Options:
  --location <location>     Azure region (default: swedencentral)
  --parameters <file>       Parameters file (default: parameters.json)
  --what-if                 Run what-if deployment (preview changes)
  --help                    Show this help
```

### Desplegar con Azure CLI directamente

```bash
# What-if
az deployment sub what-if \
  --location swedencentral \
  --template-file main.bicep \
  --parameters @parameters.json

# Deploy
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters @parameters.json \
  --name "distriplatform-deploy"
```

## Personalización

Edita `parameters.json` para cambiar:

- `projectName`: Prefijo para nombres de recursos
- `location`: Región de Azure
- `resourceGroupName`: Nombre del Resource Group
- `storageAccountSku`: SKU del Storage Account
- `cosmosDbConsistencyLevel`: Nivel de consistencia de CosmosDB
- `searchServiceSku`: SKU de Azure AI Search
- `createContainerAppsEnvironment`: Crear o no el ACA Environment
- `createAIFoundry`: Crear o no AI Foundry

## Outputs

Después del despliegue, el script muestra los outputs importantes:

- Resource Group ID
- Log Analytics Workspace ID
- Application Insights Connection String
- CosmosDB Endpoint
- AI Search Endpoint
- Container Apps Environment ID
- AI Hub/Project IDs

## Notas

- **CosmosDB**: Se despliega en modo Serverless para optimizar costos
- **AI Search**: SKU `basic` por defecto (cambiar a `free` si es para desarrollo)
- **AI Foundry**: Requiere Storage Account y Key Vault (se crean automáticamente)
- **Container Apps Environment**: Conectado a Log Analytics para logs centralizados
