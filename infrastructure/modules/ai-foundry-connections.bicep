// ============================================================================
// Azure AI Foundry - Connections Module
// ============================================================================
// This module creates connections AFTER RBAC is set up
// Separated to ensure AI Foundry has Key Vault permissions before creating connections
// ============================================================================

@description('AI Foundry Account name')
param aiFoundryAccountName string

@description('Location for the resource')
param location string

@description('Storage Account ID')
param storageAccountId string

@description('Storage Account Name')
param storageAccountName string

@description('Key Vault ID')
param keyVaultId string

@description('Application Insights ID (optional)')
param applicationInsightsId string = ''

@description('Application Insights Name')
param applicationInsightsName string = ''

@description('Application Insights Instrumentation Key')
@secure()
param applicationInsightsKey string = ''

@description('AI Search ID (optional)')
param aiSearchId string = ''

@description('AI Search Name')
param aiSearchName string = ''

@description('CosmosDB Account ID (optional)')
param cosmosDbId string = ''

@description('CosmosDB Account Name')
param cosmosDbName string = ''

// ============================================================================
// Reference to existing AI Foundry Account
// ============================================================================

resource aiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: aiFoundryAccountName
}

// ============================================================================
// Connections on AI Foundry Account
// ============================================================================

// Key Vault Connection
resource keyVaultConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: aiFoundryAccount
  name: '${aiFoundryAccountName}-keyvault'
  properties: {
    authType: 'AccountManagedIdentity'
    category: 'AzureKeyVault'
    target: keyVaultId
    useWorkspaceManagedIdentity: true
    isSharedToAll: true
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      ApiType: 'Azure'
      ResourceId: keyVaultId
      location: location
    }
  }
}

// Storage Account Connection
resource storageConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(storageAccountId)) {
  parent: aiFoundryAccount
  name: '${aiFoundryAccountName}-storage'
  properties: {
    authType: 'AAD'
    category: 'AzureStorageAccount'
    target: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      ApiType: 'Azure'
      ResourceId: storageAccountId
    }
  }
  dependsOn: [
    keyVaultConnection
  ]
}

// AI Search Connection
resource aiSearchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(aiSearchId)) {
  parent: aiFoundryAccount
  name: '${aiFoundryAccountName}-aisearch'
  properties: {
    authType: 'AAD'
    category: 'CognitiveSearch'
    target: 'https://${aiSearchName}.search.windows.net'
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      ResourceId: aiSearchId
      location: location
      ApiVersion: '2024-05-01-preview'
      DeploymentApiVersion: '2023-11-01'
    }
  }
  dependsOn: [
    storageConnection
  ]
}

// CosmosDB Connection
resource cosmosDbConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(cosmosDbId)) {
  parent: aiFoundryAccount
  name: '${aiFoundryAccountName}-cosmosdb'
  properties: {
    authType: 'AAD'
    category: 'CosmosDb'
    target: 'https://${cosmosDbName}.documents.azure.com:443/'
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmosDbId
      location: location
    }
  }
  dependsOn: [
    aiSearchConnection
  ]
}

// Application Insights Connection (uses ApiKey, not AAD)
resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(applicationInsightsId)) {
  parent: aiFoundryAccount
  name: '${aiFoundryAccountName}-appinsights'
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: applicationInsightsId
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
    credentials: {
      key: applicationInsightsKey
    }
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      displayName: applicationInsightsName
      ApiType: 'Azure'
      ResourceId: applicationInsightsId
    }
  }
  dependsOn: [
    cosmosDbConnection
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('Number of connections created')
output connectionsCreated int = 5
