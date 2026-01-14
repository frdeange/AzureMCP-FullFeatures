@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Azure Container App')
param acaName string

@description('Display name for the Entra App')
param entraAppDisplayName string

@description('Microsoft Foundry project resource ID for assigning Entra App role to Foundry project managed identity')
param foundryProjectResourceId string

@description('Application Insights connection string. Use "DISABLED" to disable telemetry, or provide existing connection string. If omitted, new App Insights will be created.')
param appInsightsConnectionString string = ''

@description('Whether to use an existing Container Apps Environment instead of creating a new one')
param useExistingAcaEnvironment bool = false

@description('Name of the existing Container Apps Environment (required if useExistingAcaEnvironment is true)')
param existingAcaEnvironmentName string = ''

@description('Resource group of the existing Container Apps Environment (leave empty if same as deployment resource group)')
param existingAcaEnvironmentResourceGroup string = ''

@description('Enable read-only mode for the MCP server. Set to false to allow write operations (create, modify, delete Azure resources).')
param readOnlyMode bool = false

@description('Container Registry server (e.g., myregistry.azurecr.io)')
param containerRegistryServer string

@description('Container image name (e.g., azure-mcp-custom:latest)')
param containerImageName string = 'azure-mcp-custom:latest'

@description('Container Registry username (for admin auth)')
@secure()
param containerRegistryUsername string

@description('Container Registry password (for admin auth)')
@secure()
param containerRegistryPassword string

// Deploy Application Insights if appInsightsConnectionString is empty and not DISABLED
var appInsightsName = '${acaName}-insights'
//
module appInsights 'modules/application-insights.bicep' = {
  name: 'application-insights-deployment'
  params: {
    appInsightsConnectionString: appInsightsConnectionString
    name: appInsightsName
    location: location
  }
}

// Deploy Entra App
var entraAppUniqueName = '${replace(toLower(entraAppDisplayName), ' ', '-')}-${uniqueString(resourceGroup().id)}'
//
module entraApp 'modules/entra-app.bicep' = {
  name: 'entra-app-deployment'
  params: {
    entraAppDisplayName: entraAppDisplayName
    entraAppUniqueName: entraAppUniqueName
  }
}

// Deploy ACA Infrastructure to host Azure MCP Server
module acaInfrastructure 'modules/aca-infrastructure.bicep' = {
  name: 'aca-infrastructure-deployment'
  params: {
    name: acaName
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
    azureMcpCollectTelemetry: string(!empty(appInsights.outputs.connectionString))
    azureAdTenantId: tenant().tenantId
    azureAdClientId: entraApp.outputs.entraAppClientId
    // Enable ALL namespaces/tools by passing empty array
    namespaces: []
    // Control read-only mode
    readOnly: readOnlyMode
    // Existing environment configuration
    useExistingEnvironment: useExistingAcaEnvironment
    existingEnvironmentName: existingAcaEnvironmentName
    existingEnvironmentResourceGroup: !empty(existingAcaEnvironmentResourceGroup) ? existingAcaEnvironmentResourceGroup : resourceGroup().name
    // Container Registry configuration
    containerRegistryServer: containerRegistryServer
    containerImageName: containerImageName
    containerRegistryUsername: containerRegistryUsername
    containerRegistryPassword: containerRegistryPassword
  }
}

// =============================================================================
// SUBSCRIPTION-LEVEL ROLE ASSIGNMENTS
// =============================================================================
// These roles are assigned at the subscription level to allow the MCP server
// to access ALL Azure services. For a more restrictive setup, you can modify
// these to target specific resource groups instead.
// =============================================================================

// Role definitions for comprehensive Azure access
// Reader role - allows read access to all Azure resources
// var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
// Contributor role - allows full management of Azure resources (except access management)
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Storage roles for blob and data operations
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

// Key Vault roles
var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var keyVaultCertificatesOfficerRoleId = 'a4417e6f-fecd-4de8-b567-7b0420556985'
var keyVaultCryptoOfficerRoleId = '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'

// Cosmos DB role
var cosmosDbAccountContributorRoleId = '5bd9cd88-fe45-4216-938b-f97437e15450'

// Service Bus role
var serviceBusDataOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'

// Event Grid role
var eventGridContributorRoleId = '1e241071-0855-49ea-94dc-649edcd759de'

// Event Hubs role
var eventHubsDataOwnerRoleId = 'f526a384-b230-433a-b45c-95f59c4a2dec'

// Redis Cache role
var redisCacheContributorRoleId = 'e0f68234-74aa-48ed-b826-c38b57376e17'

// App Configuration role
var appConfigurationDataOwnerRoleId = '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'

// Log Analytics role
var logAnalyticsContributorRoleId = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'

// Monitoring role
var monitoringContributorRoleId = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'

// AI Search roles
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'

// Azure AI/Foundry role
var cognitiveServicesContributorRoleId = '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'

// Deploy Contributor role at subscription level (primary role for write operations)
module subscriptionContributorRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-contributor-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: contributorRoleId
    roleDescription: 'Azure MCP Server - Contributor access for resource management'
  }
}

// Deploy Storage Blob Data Contributor role at subscription level
module subscriptionStorageBlobRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-storage-blob-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: storageBlobDataContributorRoleId
    roleDescription: 'Azure MCP Server - Storage Blob Data Contributor for blob operations'
  }
}

// Deploy Storage Table Data Contributor role at subscription level
module subscriptionStorageTableRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-storage-table-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: storageTableDataContributorRoleId
    roleDescription: 'Azure MCP Server - Storage Table Data Contributor for table operations'
  }
}

// Deploy Storage Queue Data Contributor role at subscription level
module subscriptionStorageQueueRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-storage-queue-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: storageQueueDataContributorRoleId
    roleDescription: 'Azure MCP Server - Storage Queue Data Contributor for queue operations'
  }
}

// Deploy Key Vault Secrets Officer role at subscription level
module subscriptionKeyVaultSecretsRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-keyvault-secrets-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: keyVaultSecretsOfficerRoleId
    roleDescription: 'Azure MCP Server - Key Vault Secrets Officer for secrets management'
  }
}

// Deploy Key Vault Certificates Officer role at subscription level
module subscriptionKeyVaultCertsRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-keyvault-certs-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: keyVaultCertificatesOfficerRoleId
    roleDescription: 'Azure MCP Server - Key Vault Certificates Officer for certificate management'
  }
}

// Deploy Key Vault Crypto Officer role at subscription level
module subscriptionKeyVaultCryptoRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-keyvault-crypto-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: keyVaultCryptoOfficerRoleId
    roleDescription: 'Azure MCP Server - Key Vault Crypto Officer for key operations'
  }
}

// Deploy Cosmos DB Account Contributor role at subscription level
module subscriptionCosmosDbRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-cosmosdb-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: cosmosDbAccountContributorRoleId
    roleDescription: 'Azure MCP Server - Cosmos DB Account Contributor for database operations'
  }
}

// Deploy Service Bus Data Owner role at subscription level
module subscriptionServiceBusRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-servicebus-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: serviceBusDataOwnerRoleId
    roleDescription: 'Azure MCP Server - Service Bus Data Owner for messaging operations'
  }
}

// Deploy Event Grid Contributor role at subscription level
module subscriptionEventGridRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-eventgrid-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: eventGridContributorRoleId
    roleDescription: 'Azure MCP Server - Event Grid Contributor for event management'
  }
}

// Deploy Event Hubs Data Owner role at subscription level
module subscriptionEventHubsRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-eventhubs-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: eventHubsDataOwnerRoleId
    roleDescription: 'Azure MCP Server - Event Hubs Data Owner for event streaming'
  }
}

// Deploy Redis Cache Contributor role at subscription level
module subscriptionRedisRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-redis-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: redisCacheContributorRoleId
    roleDescription: 'Azure MCP Server - Redis Cache Contributor for cache operations'
  }
}

// Deploy App Configuration Data Owner role at subscription level
module subscriptionAppConfigRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-appconfig-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: appConfigurationDataOwnerRoleId
    roleDescription: 'Azure MCP Server - App Configuration Data Owner for config management'
  }
}

// Deploy Log Analytics Contributor role at subscription level
module subscriptionLogAnalyticsRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-loganalytics-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: logAnalyticsContributorRoleId
    roleDescription: 'Azure MCP Server - Log Analytics Contributor for monitoring operations'
  }
}

// Deploy Monitoring Contributor role at subscription level
module subscriptionMonitoringRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-monitoring-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: monitoringContributorRoleId
    roleDescription: 'Azure MCP Server - Monitoring Contributor for Azure Monitor'
  }
}

// Deploy Search Service Contributor role at subscription level
module subscriptionSearchServiceRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-search-service-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: searchServiceContributorRoleId
    roleDescription: 'Azure MCP Server - Search Service Contributor for AI Search'
  }
}

// Deploy Search Index Data Contributor role at subscription level
module subscriptionSearchDataRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-search-data-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: searchIndexDataContributorRoleId
    roleDescription: 'Azure MCP Server - Search Index Data Contributor for index operations'
  }
}

// Deploy Cognitive Services Contributor role at subscription level (for AI Foundry)
module subscriptionCognitiveServicesRole 'modules/subscription-role-assignment.bicep' = {
  name: 'subscription-cognitive-services-role'
  scope: subscription()
  params: {
    principalId: acaInfrastructure.outputs.containerAppPrincipalId
    roleDefinitionId: cognitiveServicesContributorRoleId
    roleDescription: 'Azure MCP Server - Cognitive Services Contributor for AI Foundry'
  }
}

// Deploy Entra App role assignment for Microsoft Foundry project MI to access ACA
module foundryRoleAssignment './modules/foundry-role-assignment-entraapp.bicep' = {
  name: 'foundry-role-assignment'
  params: {
    foundryProjectResourceId: foundryProjectResourceId
    entraAppServicePrincipalObjectId: entraApp.outputs.entraAppServicePrincipalObjectId
    entraAppRoleId: entraApp.outputs.entraAppRoleId
  }
}

// Outputs for azd and other consumers
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output AZURE_LOCATION string = location

// Entra App outputs
output ENTRA_APP_CLIENT_ID string = entraApp.outputs.entraAppClientId
output ENTRA_APP_OBJECT_ID string = entraApp.outputs.entraAppObjectId
output ENTRA_APP_SERVICE_PRINCIPAL_ID string = entraApp.outputs.entraAppServicePrincipalObjectId
output ENTRA_APP_ROLE_ID string = entraApp.outputs.entraAppRoleId
output ENTRA_APP_IDENTIFIER_URI string = entraApp.outputs.entraAppIdentifierUri

// ACA Infrastructure outputs
output CONTAINER_APP_URL string = acaInfrastructure.outputs.containerAppUrl
output CONTAINER_APP_NAME string = acaInfrastructure.outputs.containerAppName
output CONTAINER_APP_PRINCIPAL_ID string = acaInfrastructure.outputs.containerAppPrincipalId
output AZURE_CONTAINER_APP_ENVIRONMENT_ID string = acaInfrastructure.outputs.containerAppEnvironmentId

// Application Insights outputs
output APPLICATION_INSIGHTS_NAME string = appInsightsName
output APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output AZURE_MCP_COLLECT_TELEMETRY string = string(!empty(appInsights.outputs.connectionString))
