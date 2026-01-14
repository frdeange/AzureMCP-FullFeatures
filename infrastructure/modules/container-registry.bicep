// ============================================================================
// Azure Container Registry
// ============================================================================

@description('Name for the Container Registry (must be globally unique, alphanumeric only)')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('SKU for the Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Enable admin user (needed for some scenarios like ACA without managed identity)')
param adminUserEnabled bool = true

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundancy bool = false

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    zoneRedundancy: sku == 'Premium' && zoneRedundancy ? 'Enabled' : 'Disabled'
    policies: {
      retentionPolicy: {
        status: sku == 'Premium' ? 'enabled' : 'disabled'
        days: 7
      }
    }
  }
}

@description('The resource ID of the Container Registry')
output registryId string = containerRegistry.id

@description('The name of the Container Registry')
output registryName string = containerRegistry.name

@description('The login server URL')
output loginServer string = containerRegistry.properties.loginServer
