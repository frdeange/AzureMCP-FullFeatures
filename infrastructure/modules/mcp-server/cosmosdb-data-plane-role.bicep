// =============================================================================
// CosmosDB Data Plane Role Assignment
// =============================================================================
// CosmosDB uses a separate RBAC system for data plane access.
// This module assigns the built-in data plane roles that allow
// reading/writing data in CosmosDB containers.
//
// NOTE: This is different from Azure RBAC roles like "DocumentDB Account Contributor"
// which only control management plane operations (creating/deleting accounts).
// =============================================================================

@description('CosmosDB Account name')
param cosmosDbAccountName string

@description('Principal ID to grant access to (e.g., Container App Managed Identity)')
param principalId string

@description('Role to assign: "reader" or "contributor"')
@allowed(['reader', 'contributor'])
param roleType string = 'contributor'

// Built-in CosmosDB data plane role definition IDs
// These are fixed GUIDs defined by Azure
var builtInRoles = {
  // Cosmos DB Built-in Data Reader - read-only access to data
  reader: '00000000-0000-0000-0000-000000000001'
  // Cosmos DB Built-in Data Contributor - read/write access to data
  contributor: '00000000-0000-0000-0000-000000000002'
}

// Reference existing CosmosDB account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosDbAccountName
}

// Assign the data plane role
// Scope "/" means full account access (all databases and containers)
resource cosmosDbDataPlaneRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, principalId, builtInRoles[roleType])
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${builtInRoles[roleType]}'
    principalId: principalId
    scope: cosmosDbAccount.id
  }
}

@description('The ID of the role assignment')
output roleAssignmentId string = cosmosDbDataPlaneRole.id
