// ============================================================================
// Azure Container Apps Environment
// ============================================================================

@description('Name for the Container Apps Environment')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics Workspace Customer ID')
param logAnalyticsWorkspaceCustomerId string

@description('Enable zone redundancy')
param zoneRedundant bool = false

@description('Workload profile type')
@allowed(['Consumption', 'D4', 'D8', 'D16', 'D32', 'E4', 'E8', 'E16', 'E32'])
param workloadProfileType string = 'Consumption'

// Get the Log Analytics shared key
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: zoneRedundant
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: workloadProfileType
      }
    ]
  }
}

@description('The resource ID of the Container Apps Environment')
output environmentId string = containerAppsEnvironment.id

@description('The name of the Container Apps Environment')
output environmentName string = containerAppsEnvironment.name

@description('The default domain for the Container Apps Environment')
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain

@description('The static IP of the Container Apps Environment')
output staticIp string = containerAppsEnvironment.properties.staticIp
