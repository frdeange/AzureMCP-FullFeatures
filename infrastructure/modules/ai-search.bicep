// ============================================================================
// Azure AI Search
// ============================================================================

@description('Name for the Azure AI Search service')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('SKU for the Search service')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param sku string = 'basic'

@description('Number of replicas')
@minValue(1)
@maxValue(12)
param replicaCount int = 1

@description('Number of partitions')
@allowed([1, 2, 3, 4, 6, 12])
param partitionCount int = 1

@description('Hosting mode')
@allowed(['default', 'highDensity'])
param hostingMode string = 'default'

@description('Public network access')
@allowed(['enabled', 'disabled'])
param publicNetworkAccess string = 'enabled'

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: sku
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: hostingMode
    publicNetworkAccess: publicNetworkAccess
    semanticSearch: sku != 'free' ? 'standard' : 'disabled'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

@description('The resource ID of the Search service')
output searchServiceId string = searchService.id

@description('The name of the Search service')
output searchServiceName string = searchService.name

@description('The endpoint for the Search service')
output endpoint string = 'https://${searchService.name}.search.windows.net'

@description('The principal ID of the Search service managed identity')
output principalId string = searchService.identity.principalId

// Note: Keys should be retrieved via Azure CLI or Key Vault reference in production
// These outputs are commented out to avoid security warnings
// @description('The admin key for the Search service')
// output adminKey string = searchService.listAdminKeys().primaryKey
