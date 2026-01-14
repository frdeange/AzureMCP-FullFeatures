// ============================================================================
// Azure Key Vault
// ============================================================================

@description('Name for the Key Vault (must be globally unique)')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Enable RBAC authorization (recommended)')
param enableRbacAuthorization bool = true

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionDays int = 90

@description('Enable purge protection (prevents permanent deletion)')
param enablePurgeProtection bool = false

@description('SKU for the Key Vault')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Allow public network access')
param publicNetworkAccess bool = true

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: enableRbacAuthorization
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
