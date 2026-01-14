// ============================================================================
// Azure AI Foundry (NEW Model - Cognitive Services Account + Project)
// Based on Azure Portal export template (2025-06-01)
// NOTE: Connections are created in separate module after RBAC
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
// NOTE: Connections are created in a separate module (ai-foundry-connections.bicep)
// This is done AFTER RBAC is set up so AI Foundry has permissions to Key Vault
// ============================================================================

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
