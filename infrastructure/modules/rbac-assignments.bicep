// ============================================================================
// RBAC Role Assignments for DistriAgent Platform
// ============================================================================
// This module creates all necessary role assignments between components
// using System Assigned Managed Identities
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Principal ID of the AI Hub managed identity')
param aiHubPrincipalId string = ''

@description('Principal ID of the AI Project managed identity')
param aiProjectPrincipalId string = ''

@description('Principal ID of the AI Search managed identity')
param aiSearchPrincipalId string = ''

@description('Principal ID of the deployer (user running the deployment)')
param deployerPrincipalId string = ''

@description('Storage Account ID')
param storageAccountId string

@description('Container Registry ID')
param containerRegistryId string = ''

@description('Cosmos DB Account ID')
param cosmosDbAccountId string = ''

@description('AI Search Service ID')
param aiSearchServiceId string = ''

@description('Key Vault ID')
param keyVaultId string = ''

@description('Communication Service ID')
param communicationServiceId string = ''

// ============================================================================
// Built-in Role Definition IDs
// https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
// ============================================================================

var roles = {
  // Storage roles
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  storageFileDataPrivilegedContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  storageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  
  // Container Registry roles
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  
  // Cosmos DB roles
  cosmosDbAccountReader: 'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'
  documentDbAccountContributor: '5bd9cd88-fe45-4216-938b-f97437e15450'
  
  // AI Search roles
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  
  // Key Vault roles
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  keyVaultCryptoUser: '12338af0-0e69-4776-bea7-57ae8d297424'
  keyVaultAdministrator: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  
  // Cognitive Services / AI roles
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  cognitiveServicesContributor: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  
  // General
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// ============================================================================
// Existing Resource References
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (!empty(storageAccountId)) {
  name: last(split(storageAccountId, '/'))
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(containerRegistryId)) {
  name: last(split(containerRegistryId, '/'))
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(keyVaultId)) {
  name: last(split(keyVaultId, '/'))
}

resource aiSearchService 'Microsoft.Search/searchServices@2023-11-01' existing = if (!empty(aiSearchServiceId)) {
  name: last(split(aiSearchServiceId, '/'))
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = if (!empty(cosmosDbAccountId)) {
  name: last(split(cosmosDbAccountId, '/'))
}

resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' existing = if (!empty(communicationServiceId)) {
  name: last(split(communicationServiceId, '/'))
}

// ============================================================================
// AI Hub -> Storage Account
// AI Hub needs to read/write blobs for model artifacts, datasets, etc.
// ============================================================================

resource aiHubStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(storageAccountId)) {
  name: guid(storageAccountId, aiHubPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalType: 'ServicePrincipal'
  }
}

resource aiHubStorageFileContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(storageAccountId)) {
  name: guid(storageAccountId, aiHubPrincipalId, roles.storageFileDataPrivilegedContributor)
  scope: storageAccount
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageFileDataPrivilegedContributor)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Project -> Storage Account
// ============================================================================

resource aiProjectStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(storageAccountId)) {
  name: guid(storageAccountId, aiProjectPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Hub -> Container Registry
// ============================================================================

resource aiHubAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, aiHubPrincipalId, roles.acrPush)
  scope: containerRegistry
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
    principalType: 'ServicePrincipal'
  }
}

// AI Hub also needs Reader to list repos/tags
resource aiHubAcrReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, aiHubPrincipalId, roles.reader)
  scope: containerRegistry
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.reader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Project -> Container Registry
// ============================================================================

resource aiProjectAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, aiProjectPrincipalId, roles.acrPull)
  scope: containerRegistry
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalType: 'ServicePrincipal'
  }
}

// AI Project also needs Reader to list repos/tags
resource aiProjectAcrReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, aiProjectPrincipalId, roles.reader)
  scope: containerRegistry
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.reader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Hub -> Key Vault
// ============================================================================

resource aiHubKeyVaultSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(keyVaultId)) {
  name: guid(keyVaultId, aiHubPrincipalId, roles.keyVaultSecretsOfficer)
  scope: keyVault
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsOfficer)
    principalType: 'ServicePrincipal'
  }
}

resource aiProjectKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(keyVaultId)) {
  name: guid(keyVaultId, aiProjectPrincipalId, roles.keyVaultSecretsUser)
  scope: keyVault
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Hub -> AI Search
// ============================================================================

resource aiHubSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(aiSearchServiceId)) {
  name: guid(aiSearchServiceId, aiHubPrincipalId, roles.searchIndexDataContributor)
  scope: aiSearchService
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataContributor)
    principalType: 'ServicePrincipal'
  }
}

resource aiProjectSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(aiSearchServiceId)) {
  name: guid(aiSearchServiceId, aiProjectPrincipalId, roles.searchIndexDataReader)
  scope: aiSearchService
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataReader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Hub -> Cosmos DB
// ============================================================================

resource aiHubCosmosContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(cosmosDbAccountId)) {
  name: guid(cosmosDbAccountId, aiHubPrincipalId, roles.documentDbAccountContributor)
  scope: cosmosDbAccount
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.documentDbAccountContributor)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Hub -> Communication Service
// AI Hub needs to send emails/SMS
// ============================================================================

resource aiHubCommunicationContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubPrincipalId) && !empty(communicationServiceId)) {
  name: guid(communicationServiceId, aiHubPrincipalId, roles.contributor)
  scope: communicationService
  properties: {
    principalId: aiHubPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalType: 'ServicePrincipal'
  }
}

resource aiProjectCommunicationContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiProjectPrincipalId) && !empty(communicationServiceId)) {
  name: guid(communicationServiceId, aiProjectPrincipalId, roles.contributor)
  scope: communicationService
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// AI Search -> Storage Account (for RAG indexing)
// AI Search needs to read blobs to index documents
// ============================================================================

resource aiSearchStorageBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiSearchPrincipalId) && !empty(storageAccountId)) {
  name: guid(storageAccountId, aiSearchPrincipalId, roles.storageBlobDataReader)
  scope: storageAccount
  properties: {
    principalId: aiSearchPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataReader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Deployer -> Container Registry
// User running the deployment needs to push images and list repos
// ============================================================================

resource deployerAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, deployerPrincipalId, roles.acrPush)
  scope: containerRegistry
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
    principalType: 'User'
  }
}

resource deployerAcrReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(containerRegistryId)) {
  name: guid(containerRegistryId, deployerPrincipalId, roles.reader)
  scope: containerRegistry
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.reader)
    principalType: 'User'
  }
}

// ============================================================================
// Deployer -> Key Vault
// User running deployment may need to create secrets
// ============================================================================

resource deployerKeyVaultAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(keyVaultId)) {
  name: guid(keyVaultId, deployerPrincipalId, roles.keyVaultAdministrator)
  scope: keyVault
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultAdministrator)
    principalType: 'User'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Summary of role assignments created')
output roleAssignmentsSummary object = {
  aiHubToStorage: !empty(aiHubPrincipalId) && !empty(storageAccountId)
  aiHubToAcr: !empty(aiHubPrincipalId) && !empty(containerRegistryId)
  aiHubToKeyVault: !empty(aiHubPrincipalId) && !empty(keyVaultId)
  aiHubToSearch: !empty(aiHubPrincipalId) && !empty(aiSearchServiceId)
  aiHubToCosmos: !empty(aiHubPrincipalId) && !empty(cosmosDbAccountId)
  aiHubToCommunication: !empty(aiHubPrincipalId) && !empty(communicationServiceId)
  aiProjectToStorage: !empty(aiProjectPrincipalId) && !empty(storageAccountId)
  aiProjectToAcr: !empty(aiProjectPrincipalId) && !empty(containerRegistryId)
  aiProjectToKeyVault: !empty(aiProjectPrincipalId) && !empty(keyVaultId)
  aiProjectToSearch: !empty(aiProjectPrincipalId) && !empty(aiSearchServiceId)
  aiProjectToCommunication: !empty(aiProjectPrincipalId) && !empty(communicationServiceId)
  aiSearchToStorage: !empty(aiSearchPrincipalId) && !empty(storageAccountId)
  deployerToAcr: !empty(deployerPrincipalId) && !empty(containerRegistryId)
  deployerToKeyVault: !empty(deployerPrincipalId) && !empty(keyVaultId)
}
