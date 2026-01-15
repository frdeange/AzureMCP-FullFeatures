// ============================================================================
// DistriAgent Platform - Main Infrastructure Deployment
// ============================================================================
// This template deploys all infrastructure resources for the DistriAgent Platform
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for all resources')
param projectName string = 'distriplatform'

@description('Suffix for AI Foundry naming (optional, uses projectName pattern if empty)')
param aiFoundrySuffix string = ''

@description('Location for all resources')
param location string = 'swedencentral'

@description('Resource Group name')
param resourceGroupName string = 'RG-DistriAgentPlatform'

@description('Tags to apply to all resources')
param tags object = {
  project: 'DistriAgentPlatform'
  environment: 'dev'
  managedBy: 'bicep'
}

// Storage Account
@description('Storage Account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param storageAccountSku string = 'Standard_LRS'

// CosmosDB
@description('CosmosDB consistency level')
@allowed(['Eventual', 'ConsistentPrefix', 'Session', 'BoundedStaleness', 'Strong'])
param cosmosDbConsistencyLevel string = 'Session'

// Azure AI Search
@description('Azure AI Search SKU')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3'])
param searchServiceSku string = 'basic'

// Container Apps Environment
@description('Whether to create Container Apps Environment')
param createContainerAppsEnvironment bool = true

// Container Registry
@description('Azure Container Registry SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param containerRegistrySku string = 'Basic'

// AI Foundry
@description('Whether to create AI Foundry (Azure AI Hub)')
param createAIFoundry bool = true

// Communication Service
@description('Whether to create Azure Communication Service with Email')
param createCommunicationService bool = true

// Deployer Principal ID (for RBAC - obtained via: az ad signed-in-user show --query id -o tsv)
@description('Principal ID of the user/service principal running the deployment (for ACR push access)')
param deployerPrincipalId string = ''

// ============================================================================
// MCP Server Parameters
// ============================================================================

@description('Whether to deploy the MCP Server (Container App)')
param deployMcpServer bool = false

@description('Name for the MCP Server Container App')
param mcpServerName string = '${projectName}-mcp'

@description('Display name for the MCP Entra App')
param mcpEntraAppDisplayName string = 'Azure MCP Server - ${projectName}'

@description('Container image name for MCP Server (e.g., azure-mcp-custom:latest)')
param mcpContainerImage string = 'azure-mcp-custom:latest'

@description('Container Registry username (leave empty to auto-detect from ACR admin)')
@secure()
param containerRegistryUsername string = ''

@description('Container Registry password (leave empty to auto-detect from ACR admin)')
@secure()
param containerRegistryPassword string = ''

@description('Enable read-only mode for MCP Server (recommended for production)')
param mcpReadOnlyMode bool = false

@description('MCP Server namespaces to enable (empty = ALL)')
param mcpNamespaces array = []

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ============================================================================
// Log Analytics Workspace (needed by other resources)
// ============================================================================

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  scope: rg
  params: {
    name: '${projectName}-loganalytics'
    location: location
    tags: tags
  }
}

// ============================================================================
// Application Insights
// ============================================================================

module appInsights 'modules/application-insights.bicep' = {
  name: 'deploy-app-insights'
  scope: rg
  params: {
    name: '${projectName}-appinsight'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// ============================================================================
// Storage Account
// ============================================================================

module storageAccount 'modules/storage-account.bicep' = {
  name: 'deploy-storage-account'
  scope: rg
  params: {
    name: replace('${projectName}storage', '-', '')
    location: location
    tags: tags
    sku: storageAccountSku
  }
}

// ============================================================================
// CosmosDB
// ============================================================================

module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  scope: rg
  params: {
    name: '${projectName}-cosmos'
    location: location
    tags: tags
    consistencyLevel: cosmosDbConsistencyLevel
  }
}

// ============================================================================
// Azure AI Search
// ============================================================================

module searchService 'modules/ai-search.bicep' = {
  name: 'deploy-ai-search'
  scope: rg
  params: {
    name: '${projectName}-search'
    location: location
    tags: tags
    sku: searchServiceSku
  }
}

// ============================================================================
// Container Apps Environment
// ============================================================================

module containerAppsEnv 'modules/container-apps-environment.bicep' = if (createContainerAppsEnvironment) {
  name: 'deploy-container-apps-env'
  scope: rg
  params: {
    name: '${projectName}-aca-env'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsWorkspaceCustomerId: logAnalytics.outputs.workspaceCustomerId
  }
}

// ============================================================================
// Key Vault (used by AI Foundry)
// ============================================================================

module keyVault 'modules/key-vault.bicep' = if (createAIFoundry) {
  name: 'deploy-key-vault'
  scope: rg
  params: {
    name: '${replace(projectName, '-', '')}kv'
    location: location
    tags: tags
  }
}

// ============================================================================
// Azure Container Registry
// ============================================================================

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'deploy-container-registry'
  scope: rg
  params: {
    name: '${replace(projectName, '-', '')}acr'
    location: location
    tags: tags
    sku: containerRegistrySku
    adminUserEnabled: true
  }
}

// ============================================================================
// AI Foundry (Azure AI Cognitive Services Account + Project)
// NEW MODEL: Uses Microsoft.CognitiveServices/accounts (kind: AIServices)
// ============================================================================

module aiFoundry 'modules/ai-foundry.bicep' = if (createAIFoundry) {
  name: 'deploy-ai-foundry'
  scope: rg
  params: {
    hubName: empty(aiFoundrySuffix) ? '${projectName}-aifdry' : '${projectName}-aifdry-${aiFoundrySuffix}'
    projectName: empty(aiFoundrySuffix) ? '${projectName}-aiproj' : '${projectName}-aiproj-${aiFoundrySuffix}'
    location: location
    tags: tags
    storageAccountId: storageAccount.outputs.storageAccountId
  }
}

// ============================================================================
// RBAC Role Assignments
// Configure permissions between components using Managed Identities
// ============================================================================

module rbacAssignments 'modules/rbac-assignments.bicep' = if (createAIFoundry) {
  name: 'deploy-rbac-assignments'
  scope: rg
  params: {
    aiHubPrincipalId: aiFoundry!.outputs.aiHubPrincipalId
    aiProjectPrincipalId: aiFoundry!.outputs.aiProjectPrincipalId
    storageAccountId: storageAccount.outputs.storageAccountId
    containerRegistryId: containerRegistry.outputs.registryId
    cosmosDbAccountId: cosmosDb.outputs.accountId
    aiSearchServiceId: searchService.outputs.searchServiceId
    aiSearchPrincipalId: searchService.outputs.principalId
    keyVaultId: keyVault!.outputs.keyVaultId
    communicationServiceId: createCommunicationService ? communicationService!.outputs.communicationServiceId : ''
    deployerPrincipalId: deployerPrincipalId
  }
}

// ============================================================================
// AI Foundry Connections (AFTER RBAC is set up)
// This ensures AI Foundry has permissions to Key Vault before creating connections
// ============================================================================

module aiFoundryConnections 'modules/ai-foundry-connections.bicep' = if (createAIFoundry) {
  name: 'deploy-ai-foundry-connections'
  scope: rg
  params: {
    aiFoundryAccountName: aiFoundry!.outputs.aiHubName
    location: location
    storageAccountId: storageAccount.outputs.storageAccountId
    storageAccountName: storageAccount.outputs.storageAccountName
    keyVaultId: keyVault!.outputs.keyVaultId
    applicationInsightsId: appInsights.outputs.applicationInsightsId
    applicationInsightsName: appInsights.outputs.applicationInsightsName
    applicationInsightsKey: appInsights.outputs.instrumentationKey
    aiSearchId: searchService.outputs.searchServiceId
    aiSearchName: searchService.outputs.searchServiceName
    cosmosDbId: cosmosDb.outputs.accountId
    cosmosDbName: cosmosDb.outputs.accountName
  }
  dependsOn: [
    rbacAssignments
  ]
}

// ============================================================================
// Azure Communication Service with Email
// ============================================================================

module communicationService 'modules/communication-service.bicep' = if (createCommunicationService) {
  name: 'deploy-communication-service'
  scope: rg
  params: {
    name: '${projectName}-comm'
    location: 'global'
    tags: tags
    dataLocation: 'Europe'
    createEmailService: true
  }
}

// ============================================================================
// MCP Server Deployment (Optional)
// Deploys Container App + Entra App + RBAC for remote MCP access
// ============================================================================

// Entra App for MCP Server authentication
module mcpEntraApp 'modules/mcp-server/entra-app.bicep' = if (deployMcpServer) {
  name: 'deploy-mcp-entra-app'
  scope: rg
  params: {
    entraAppDisplayName: mcpEntraAppDisplayName
    entraAppUniqueName: '${replace(toLower(mcpEntraAppDisplayName), ' ', '-')}-${uniqueString(rg.id)}'
  }
}

// MCP Server Container App
module mcpContainerApp 'modules/mcp-server/container-app.bicep' = if (deployMcpServer) {
  name: 'deploy-mcp-container-app'
  scope: rg
  params: {
    name: mcpServerName
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
    azureMcpCollectTelemetry: 'true'
    azureAdTenantId: tenant().tenantId
    azureAdClientId: mcpEntraApp!.outputs.entraAppClientId
    namespaces: mcpNamespaces
    readOnly: mcpReadOnlyMode
    // Use existing Container Apps Environment
    useExistingEnvironment: createContainerAppsEnvironment
    existingEnvironmentName: createContainerAppsEnvironment ? containerAppsEnv!.outputs.environmentName : ''
    existingEnvironmentResourceGroup: resourceGroupName
    // Container Registry configuration
    containerRegistryServer: containerRegistry.outputs.loginServer
    containerImageName: mcpContainerImage
    containerRegistryUsername: containerRegistryUsername
    containerRegistryPassword: containerRegistryPassword
  }
}

// =============================================================================
// MCP Server RBAC - Subscription Level Roles
// =============================================================================
// These roles are assigned at the subscription level to allow the MCP server
// to access ALL Azure services. For a more restrictive setup, modify these.
// =============================================================================

// Role definitions
var mcpRoles = {
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  storageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  keyVaultCertificatesOfficer: 'a4417e6f-fecd-4de8-b567-7b0420556985'
  keyVaultCryptoOfficer: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  cosmosDbAccountContributor: '5bd9cd88-fe45-4216-938b-f97437e15450'
  serviceBusDataOwner: '090c5cfd-751d-490a-894a-3ce6f1109419'
  eventGridContributor: '1e241071-0855-49ea-94dc-649edcd759de'
  eventHubsDataOwner: 'f526a384-b230-433a-b45c-95f59c4a2dec'
  redisCacheContributor: 'e0f68234-74aa-48ed-b826-c38b57376e17'
  appConfigurationDataOwner: '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
  logAnalyticsContributor: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  monitoringContributor: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  cognitiveServicesContributor: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
}

// Contributor role (primary)
module mcpRoleContributor 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-contributor'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.contributor
    roleDescription: 'MCP Server - Contributor access'
  }
}

// Storage roles
module mcpRoleStorageBlob 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-storage-blob'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.storageBlobDataContributor
    roleDescription: 'MCP Server - Storage Blob Data Contributor'
  }
}

module mcpRoleStorageTable 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-storage-table'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.storageTableDataContributor
    roleDescription: 'MCP Server - Storage Table Data Contributor'
  }
}

module mcpRoleStorageQueue 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-storage-queue'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.storageQueueDataContributor
    roleDescription: 'MCP Server - Storage Queue Data Contributor'
  }
}

// Key Vault roles
module mcpRoleKeyVaultSecrets 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-keyvault-secrets'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.keyVaultSecretsOfficer
    roleDescription: 'MCP Server - Key Vault Secrets Officer'
  }
}

module mcpRoleKeyVaultCerts 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-keyvault-certs'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.keyVaultCertificatesOfficer
    roleDescription: 'MCP Server - Key Vault Certificates Officer'
  }
}

module mcpRoleKeyVaultCrypto 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-keyvault-crypto'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.keyVaultCryptoOfficer
    roleDescription: 'MCP Server - Key Vault Crypto Officer'
  }
}

// CosmosDB control plane role
module mcpRoleCosmosDb 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-cosmosdb'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.cosmosDbAccountContributor
    roleDescription: 'MCP Server - Cosmos DB Account Contributor'
  }
}

// CosmosDB data plane role (separate RBAC system)
module mcpCosmosDbDataPlane 'modules/mcp-server/cosmosdb-data-plane-role.bicep' = if (deployMcpServer) {
  name: 'mcp-cosmosdb-data-plane'
  scope: rg
  params: {
    cosmosDbAccountName: cosmosDb.outputs.accountName
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleType: 'contributor'
  }
}

// Service Bus role
module mcpRoleServiceBus 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-servicebus'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.serviceBusDataOwner
    roleDescription: 'MCP Server - Service Bus Data Owner'
  }
}

// Event Grid role
module mcpRoleEventGrid 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-eventgrid'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.eventGridContributor
    roleDescription: 'MCP Server - Event Grid Contributor'
  }
}

// Event Hubs role
module mcpRoleEventHubs 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-eventhubs'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.eventHubsDataOwner
    roleDescription: 'MCP Server - Event Hubs Data Owner'
  }
}

// Redis Cache role
module mcpRoleRedis 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-redis'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.redisCacheContributor
    roleDescription: 'MCP Server - Redis Cache Contributor'
  }
}

// App Configuration role
module mcpRoleAppConfig 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-appconfig'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.appConfigurationDataOwner
    roleDescription: 'MCP Server - App Configuration Data Owner'
  }
}

// Log Analytics role
module mcpRoleLogAnalytics 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-loganalytics'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.logAnalyticsContributor
    roleDescription: 'MCP Server - Log Analytics Contributor'
  }
}

// Monitoring role
module mcpRoleMonitoring 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-monitoring'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.monitoringContributor
    roleDescription: 'MCP Server - Monitoring Contributor'
  }
}

// AI Search roles
module mcpRoleSearchService 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-search-service'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.searchServiceContributor
    roleDescription: 'MCP Server - Search Service Contributor'
  }
}

module mcpRoleSearchData 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-search-data'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.searchIndexDataContributor
    roleDescription: 'MCP Server - Search Index Data Contributor'
  }
}

// Cognitive Services role (for AI Foundry)
module mcpRoleCognitiveServices 'modules/mcp-server/subscription-role-assignment.bicep' = if (deployMcpServer) {
  name: 'mcp-role-cognitive-services'
  scope: subscription()
  params: {
    principalId: mcpContainerApp!.outputs.containerAppPrincipalId
    roleDefinitionId: mcpRoles.cognitiveServicesContributor
    roleDescription: 'MCP Server - Cognitive Services Contributor'
  }
}

// AI Foundry Project -> MCP Server role assignment
module mcpFoundryRoleAssignment 'modules/mcp-server/foundry-role-assignment.bicep' = if (deployMcpServer && createAIFoundry) {
  name: 'mcp-foundry-role-assignment'
  scope: rg
  params: {
    foundryProjectResourceId: aiFoundry!.outputs.aiProjectId
    entraAppServicePrincipalObjectId: mcpEntraApp!.outputs.entraAppServicePrincipalObjectId
    entraAppRoleId: mcpEntraApp!.outputs.entraAppRoleId
  }
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName

output applicationInsightsId string = appInsights.outputs.applicationInsightsId
output applicationInsightsName string = appInsights.outputs.applicationInsightsName
output applicationInsightsConnectionString string = appInsights.outputs.connectionString

output storageAccountId string = storageAccount.outputs.storageAccountId
output storageAccountName string = storageAccount.outputs.storageAccountName

output cosmosDbAccountId string = cosmosDb.outputs.accountId
output cosmosDbAccountName string = cosmosDb.outputs.accountName
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint

output searchServiceId string = searchService.outputs.searchServiceId
output searchServiceName string = searchService.outputs.searchServiceName
output searchServiceEndpoint string = searchService.outputs.endpoint

output containerAppsEnvironmentId string = createContainerAppsEnvironment ? containerAppsEnv!.outputs.environmentId : ''
output containerAppsEnvironmentName string = createContainerAppsEnvironment ? containerAppsEnv!.outputs.environmentName : ''

output aiHubId string = createAIFoundry ? aiFoundry!.outputs.aiHubId : ''
output aiHubName string = createAIFoundry ? aiFoundry!.outputs.aiHubName : ''
output aiProjectId string = createAIFoundry ? aiFoundry!.outputs.aiProjectId : ''
output aiProjectName string = createAIFoundry ? aiFoundry!.outputs.aiProjectName : ''
output aiFoundryEndpoint string = createAIFoundry ? aiFoundry!.outputs.aiFoundryEndpoint : ''

output keyVaultId string = createAIFoundry ? keyVault!.outputs.keyVaultId : ''
output keyVaultName string = createAIFoundry ? keyVault!.outputs.keyVaultName : ''

output containerRegistryId string = containerRegistry.outputs.registryId
output containerRegistryName string = containerRegistry.outputs.registryName
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

output communicationServiceId string = createCommunicationService ? communicationService!.outputs.communicationServiceId : ''
output communicationServiceName string = createCommunicationService ? communicationService!.outputs.communicationServiceName : ''
output communicationServiceHostname string = createCommunicationService ? communicationService!.outputs.hostname : ''
output emailServiceId string = createCommunicationService ? communicationService!.outputs.emailServiceId : ''

// MCP Server outputs
output mcpServerUrl string = deployMcpServer ? mcpContainerApp!.outputs.containerAppUrl : ''
output mcpServerName string = deployMcpServer ? mcpContainerApp!.outputs.containerAppName : ''
output mcpServerPrincipalId string = deployMcpServer ? mcpContainerApp!.outputs.containerAppPrincipalId : ''
output mcpEntraAppClientId string = deployMcpServer ? mcpEntraApp!.outputs.entraAppClientId : ''
output mcpEntraAppIdentifierUri string = deployMcpServer ? mcpEntraApp!.outputs.entraAppIdentifierUri : ''

