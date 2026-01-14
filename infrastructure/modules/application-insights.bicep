// ============================================================================
// Application Insights
// ============================================================================

@description('Name for Application Insights')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply')
param tags object = {}

@description('Log Analytics Workspace ID to link to')
param logAnalyticsWorkspaceId string

@description('Application type')
@allowed(['web', 'other'])
param applicationType string = 'web'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The resource ID of Application Insights')
output applicationInsightsId string = applicationInsights.id

@description('The name of Application Insights')
output applicationInsightsName string = applicationInsights.name

@description('The connection string for Application Insights')
output connectionString string = applicationInsights.properties.ConnectionString

@description('The instrumentation key for Application Insights')
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
