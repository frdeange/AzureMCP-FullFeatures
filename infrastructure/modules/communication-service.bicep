// ============================================================================
// Azure Communication Service with Email
// ============================================================================
// Based on Azure Verified Modules (AVM) patterns
// API Version: 2023-04-01
// ============================================================================

@description('Name for the Communication Service')
param name string

@description('Location for the resource (Communication Services is global)')
param location string = 'global'

@description('Tags to apply')
param tags object = {}

@description('Data location for the Communication Service')
@allowed(['United States', 'Europe', 'UK', 'Japan', 'Australia', 'Brazil', 'Canada', 'France', 'Germany', 'India', 'Korea', 'Norway', 'Switzerland', 'UAE'])
param dataLocation string = 'Europe'

@description('Whether to create Email Communication Service')
param createEmailService bool = true

// ============================================================================
// Email Service (must be created first)
// ============================================================================

resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = if (createEmailService) {
  name: '${name}-email'
  location: location
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Azure Managed Email Domain (child of Email Service)
resource emailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = if (createEmailService) {
  parent: emailService
  name: 'AzureManagedDomain'
  location: location
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

// ============================================================================
// Communication Service (linked to Email Domain)
// ============================================================================

resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    dataLocation: dataLocation
    linkedDomains: createEmailService ? [
      emailDomain.id
    ] : []
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the Communication Service')
output communicationServiceId string = communicationService.id

@description('The name of the Communication Service')
output communicationServiceName string = communicationService.name

@description('The hostname of the Communication Service')
output hostname string = communicationService.properties.hostName

@description('The Email Service ID')
output emailServiceId string = createEmailService ? emailService.id : ''

@description('The Email Service name')
output emailServiceName string = createEmailService ? emailService.name : ''

@description('The Email Domain ID')
output emailDomainId string = createEmailService ? emailDomain.id : ''

@description('The Azure Managed Domain sender address (available after deployment)')
output azureManagedDomainMailFrom string = createEmailService ? emailDomain!.properties.mailFromSenderDomain : ''
