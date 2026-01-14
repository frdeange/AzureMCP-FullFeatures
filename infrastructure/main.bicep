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
    hubName: '${projectName}-ai-foundry'
    projectName: '${projectName}-ai-project'
    location: location
    tags: tags
    // Storage
    storageAccountId: storageAccount.outputs.storageAccountId
    storageAccountName: storageAccount.outputs.storageAccountName
    // Key Vault
    keyVaultId: keyVault!.outputs.keyVaultId
    // Application Insights
    applicationInsightsId: appInsights.outputs.applicationInsightsId
    applicationInsightsName: appInsights.outputs.applicationInsightsName
    // AI Search
    aiSearchId: searchService.outputs.searchServiceId
    aiSearchName: searchService.outputs.searchServiceName
    // CosmosDB
    cosmosDbId: cosmosDb.outputs.accountId
    cosmosDbName: cosmosDb.outputs.accountName
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
    keyVaultId: keyVault!.outputs.keyVaultId
  }
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

