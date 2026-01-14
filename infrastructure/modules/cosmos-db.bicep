// ============================================================================
// Azure Cosmos DB Account (NoSQL API)
// ============================================================================

@description('Name for the Cosmos DB account')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Consistency level for the Cosmos DB account')
@allowed(['Eventual', 'ConsistentPrefix', 'Session', 'BoundedStaleness', 'Strong'])
param consistencyLevel string = 'Session'

@description('Enable free tier (only one per subscription)')
param enableFreeTier bool = false

@description('Enable automatic failover')
param enableAutomaticFailover bool = false

@description('Enable multiple write locations')
param enableMultipleWriteLocations bool = false

@description('Max staleness prefix for BoundedStaleness consistency')
param maxStalenessPrefix int = 100000

@description('Max interval in seconds for BoundedStaleness consistency')
param maxIntervalInSeconds int = 300

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: enableFreeTier
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableMultipleWriteLocations
    consistencyPolicy: consistencyLevel == 'BoundedStaleness' ? {
      defaultConsistencyLevel: consistencyLevel
      maxStalenessPrefix: maxStalenessPrefix
      maxIntervalInSeconds: maxIntervalInSeconds
    } : {
      defaultConsistencyLevel: consistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    publicNetworkAccess: 'Enabled'
  }
}

@description('The resource ID of the Cosmos DB account')
output accountId string = cosmosDbAccount.id

@description('The name of the Cosmos DB account')
output accountName string = cosmosDbAccount.name

@description('The endpoint for the Cosmos DB account')
output endpoint string = cosmosDbAccount.properties.documentEndpoint

// Note: Keys should be retrieved via Azure CLI or managed identity in production
// az cosmosdb keys list --name <name> --resource-group <rg>
