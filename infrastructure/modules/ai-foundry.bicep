// ============================================================================
// Azure AI Foundry (NEW Model - Cognitive Services Account + Project)
// Based on Azure Portal export template (2025-06-01)
// ============================================================================

@description('Name for the AI Foundry Account')
param hubName string

@description('Name for the AI Project')
param projectName string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Storage Account ID for user-owned storage')
param storageAccountId string

@description('Storage Account Name')
param storageAccountName string

@description('Key Vault ID to connect')
param keyVaultId string

@description('Application Insights ID (optional)')
param applicationInsightsId string = ''

@description('Application Insights Name')
param applicationInsightsName string = ''

@description('AI Search ID to connect (optional)')
param aiSearchId string = ''

@description('AI Search Name')
param aiSearchName string = ''

@description('CosmosDB Account ID to connect (optional)')
param cosmosDbId string = ''

@description('CosmosDB Account Name')
param cosmosDbName string = ''

@description('Allow project management on the AI Foundry account')
param allowProjectManagement bool = true

@description('Disable local authentication (recommended for security)')
param disableLocalAuth bool = true

// ============================================================================
// AI Foundry Account (Microsoft.CognitiveServices/accounts - kind: AIServices)
// ============================================================================

resource aiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: hubName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiProperties: {}
    customSubDomainName: toLower(hubName)
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    userOwnedStorage: [
      {
        resourceId: storageAccountId
      }
    ]
    allowProjectManagement: allowProjectManagement
    defaultProject: projectName
    associatedProjects: [
      projectName
    ]
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: disableLocalAuth
  }
}

// ============================================================================
// AI Foundry Project (Microsoft.CognitiveServices/accounts/projects)
// ============================================================================

resource aiFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: aiFoundryAccount
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Default project created with the resource'
    displayName: projectName
  }
}

// ============================================================================
// Defender for AI Settings (disabled by default)
// ============================================================================

resource defenderSettings 'Microsoft.CognitiveServices/accounts/defenderForAISettings@2025-06-01' = {
  parent: aiFoundryAccount
  name: 'Default'
  properties: {
    state: 'Disabled'
  }
}

// ============================================================================
// Connections on AI Foundry Account
// ============================================================================

// Key Vault Connection
resource keyVaultConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: aiFoundryAccount
  name: '${hubName}-keyvault'
  properties: {
    authType: 'AAD'
    category: 'AzureKeyVault'
    target: keyVaultId
    useWorkspaceManagedIdentity: false
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
  name: '${hubName}-storage'
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
  name: '${hubName}-aisearch'
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
  name: '${hubName}-cosmosdb'
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
  name: '${hubName}-appinsights'
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: applicationInsightsId
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
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
// Connections on Project (inherited from account via isSharedToAll)
// The portal creates these on the project too for explicit access
// ============================================================================

resource projectKeyVaultConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: aiFoundryProject
  name: '${hubName}-keyvault'
  properties: {
    authType: 'AAD'
    category: 'AzureKeyVault'
    target: keyVaultId
    useWorkspaceManagedIdentity: false
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
  dependsOn: [
    keyVaultConnection
  ]
}

resource projectStorageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (!empty(storageAccountId)) {
  parent: aiFoundryProject
  name: '${hubName}-storage'
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
    storageConnection
  ]
}

resource projectAiSearchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (!empty(aiSearchId)) {
  parent: aiFoundryProject
  name: '${hubName}-aisearch'
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
    aiSearchConnection
  ]
}

resource projectCosmosDbConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (!empty(cosmosDbId)) {
  parent: aiFoundryProject
  name: '${hubName}-cosmosdb'
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
    cosmosDbConnection
  ]
}

// Application Insights Connection on Project (uses ApiKey, not AAD)
resource projectAppInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (!empty(applicationInsightsId)) {
  parent: aiFoundryProject
  name: '${hubName}-appinsights'
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: applicationInsightsId
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
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
    appInsightsConnection
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the AI Foundry Account')
output aiHubId string = aiFoundryAccount.id

@description('The name of the AI Foundry Account')
output aiHubName string = aiFoundryAccount.name

@description('The resource ID of the AI Foundry Project')
output aiProjectId string = aiFoundryProject.id

@description('The name of the AI Foundry Project')
output aiProjectName string = aiFoundryProject.name

@description('The principal ID of the AI Foundry Account managed identity')
output aiHubPrincipalId string = aiFoundryAccount.identity.principalId

@description('The principal ID of the AI Foundry Project managed identity')
output aiProjectPrincipalId string = aiFoundryProject.identity.principalId

@description('The endpoint of the AI Foundry Account')
output aiFoundryEndpoint string = aiFoundryAccount.properties.endpoint
