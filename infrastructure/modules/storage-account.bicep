// ============================================================================
// Storage Account
// ============================================================================

@description('Name for the Storage Account (must be globally unique, lowercase, no hyphens)')
@minLength(3)
@maxLength(24)
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Storage Account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS', 'Premium_ZRS'])
param sku string = 'Standard_LRS'

@description('Storage Account kind')
@allowed(['StorageV2', 'Storage', 'BlobStorage', 'BlockBlobStorage', 'FileStorage'])
param kind string = 'StorageV2'

@description('Access tier for blob storage')
@allowed(['Hot', 'Cool'])
param accessTier string = 'Hot'

@description('Allow public blob access')
param allowBlobPublicAccess bool = false

@description('Minimum TLS version')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Create default blob container for AI Foundry
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

@description('The resource ID of the Storage Account')
output storageAccountId string = storageAccount.id

@description('The name of the Storage Account')
output storageAccountName string = storageAccount.name

@description('The primary endpoint for blob storage')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('The primary endpoint for file storage')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
