// =============================================================================
// Subscription-Level RBAC Role Assignment
// =============================================================================
// This module assigns RBAC roles at the subscription level.
// Used to grant the MCP Server's managed identity broad access to Azure resources.
//
// IMPORTANT: Must be deployed with scope: subscription()
// =============================================================================

targetScope = 'subscription'

@description('Azure Container App Managed Identity principal/object ID (GUID)')
param principalId string

@description('Azure RBAC role definition ID (GUID) to grant')
param roleDefinitionId string

@description('Description of the role assignment for documentation purposes')
param roleDescription string = ''

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
    description: roleDescription
  }
}

output roleAssignmentId string = roleAssignment.id
output roleAssignmentName string = roleAssignment.name
