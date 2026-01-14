// ============================================================================
// Log Analytics Workspace
// ============================================================================

@description('Name for the Log Analytics workspace')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('SKU for Log Analytics')
@allowed(['Free', 'PerGB2018', 'PerNode', 'Premium', 'Standalone', 'Standard'])
param sku string = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) of the Log Analytics workspace')
output workspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

// Note: Primary key is accessed directly in container-apps-environment.bicep via listKeys()
// to avoid passing secrets between modules
