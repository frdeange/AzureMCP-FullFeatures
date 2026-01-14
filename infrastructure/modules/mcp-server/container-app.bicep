// =============================================================================
// MCP Server Container App
// =============================================================================
// Deploys the Azure MCP Server as a Container App with:
// - System-assigned managed identity for Azure access
// - Configurable namespaces and read-only mode
// - Application Insights integration
// - Entra ID authentication support
// =============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Default name for Azure Container App, and name prefix for all other resources')
param name string

@description('Azure Container App name')
param containerAppName string = name

@description('Environment name for the Container Apps Environment (used when creating new environment)')
param environmentName string = '${name}-env'

@description('Whether to use an existing Container Apps Environment')
param useExistingEnvironment bool = false

@description('Name of the existing Container Apps Environment (required if useExistingEnvironment is true)')
param existingEnvironmentName string = ''

@description('Resource group of the existing Container Apps Environment (required if useExistingEnvironment is true and environment is in different RG)')
param existingEnvironmentResourceGroup string = resourceGroup().name

@description('Number of CPU cores allocated to the container')
param cpuCores string = '0.25'

@description('Amount of memory allocated to the container')
param memorySize string = '0.5Gi'

@description('Minimum number of replicas')
param minReplicas int = 1

@description('Maximum number of replicas')
param maxReplicas int = 3

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Whether to collect telemetry')
param azureMcpCollectTelemetry string

@description('Azure AD Tenant ID')
param azureAdTenantId string

@description('Azure AD Client ID')
param azureAdClientId string

@description('Azure MCP Server namespaces to enable. Leave empty to enable ALL namespaces/tools.')
param namespaces array = []

@description('Enable read-only mode. Set to false to allow write operations.')
param readOnly bool = true

@description('Container Registry server (e.g., myregistry.azurecr.io)')
param containerRegistryServer string

@description('Container image name (e.g., azure-mcp-custom:latest)')
param containerImageName string = 'azure-mcp-custom:latest'

@description('Container Registry username (for admin auth)')
@secure()
param containerRegistryUsername string

@description('Container Registry password (for admin auth)')
@secure()
param containerRegistryPassword string

var baseArgs = [
  '--transport'
  'http'
  '--outgoing-auth-strategy'
  'UseHostingEnvironmentIdentity'
  '--mode'
  'all'
  // SECURITY NOTE: When readOnly is true, the MCP server is deployed with only readonly tools ('--read-only') enabled.
  // Setting readOnly to false will remove this restriction and enable tools that can create, modify, or delete Azure resources.
  // Do so with caution, and ensure that access is granted only to trusted agents.
  // SECURITY NOTE: Never add '--dangerously-disable-http-incoming-auth'.
  // This flag disables Entra ID authentication for incoming requests, allowing unauthenticated access to the MCP server.
  // This would permit anyone to execute Azure operations using the Container App's managed identity, bypassing all access controls.
]
var readOnlyArgs = readOnly ? [['--read-only']] : []
var namespaceArgs = [for ns in namespaces: ['--namespace', ns]]
var serverArgs = flatten(concat([baseArgs], readOnlyArgs, namespaceArgs))

// Reference existing environment if specified, otherwise create new one
resource existingContainerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = if (useExistingEnvironment) {
  name: existingEnvironmentName
  scope: resourceGroup(existingEnvironmentResourceGroup)
}

resource newContainerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = if (!useExistingEnvironment) {
  name: environmentName
  location: location
  properties: {
  }
}

// Determine which environment ID to use
var containerAppsEnvironmentId = useExistingEnvironment ? existingContainerAppsEnvironment.id : newContainerAppsEnvironment.id

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: {
    product: 'azmcp'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: containerRegistryPassword
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        // SECURITY NOTE: allowInsecure is set to false to enforce HTTPS-only external access.
        // Never set this to true as that will allow plain HTTP traffic, exposing sensitive data such as access tokens to interception.
        allowInsecure: false
        transport: 'http'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: '${containerRegistryServer}/${containerImageName}'
          name: containerAppName
          command: []
          args: serverArgs
          resources: {
            cpu: json(cpuCores)
            memory: memorySize
          }
          env: concat([
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'AZURE_TOKEN_CREDENTIALS'
              value: 'managedidentitycredential'
            }
            {
              name: 'AZURE_MCP_INCLUDE_PRODUCTION_CREDENTIALS'
              value: 'true'
            }
            {
              name: 'AZURE_MCP_COLLECT_TELEMETRY'
              value: azureMcpCollectTelemetry
            }
            {
              name: 'AzureAd__Instance'
              value: environment().authentication.loginEndpoint
            }
            {
              name: 'AzureAd__TenantId'
              value: azureAdTenantId
            }
            {
              name: 'AzureAd__ClientId'
              value: azureAdClientId
            }
            {
              name: 'AZURE_TENANT_ID'
              value: azureAdTenantId
            }
            {
              name: 'AZURE_LOG_LEVEL'
              value: 'Verbose'
            }
            // SECURITY NOTE: AZURE_MCP_DANGEROUSLY_DISABLE_HTTPS_REDIRECTION is set to 'true' because the Azure MCP Server 
            // listens on HTTP 'internally' within the Container App pod (port 8080). 'External' traffic is HTTPS-only (allowInsecure=false),
            // and the Container Apps Envoy proxy terminates HTTPS at the ingress boundary, then routes to the container over HTTP 
            // within the secure pod namespace. This HTTP traffic never leaves the pod, ensuring end-to-end encryption for 
            // external communication while allowing efficient internal routing.
            {
              name: 'AZURE_MCP_DANGEROUSLY_DISABLE_HTTPS_REDIRECTION'
              value: 'true'
            }
          ], !empty(appInsightsConnectionString) ? [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ] : [])
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppResourceId string = containerApp.id
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output containerAppName string = containerApp.name
output containerAppPrincipalId string = containerApp.identity.principalId
output containerAppEnvironmentId string = containerAppsEnvironmentId
