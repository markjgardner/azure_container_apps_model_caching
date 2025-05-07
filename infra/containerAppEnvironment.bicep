@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the storage account')
param storageAccountName string = '${containerAppEnvName}sa'

@description('Name of the Container Apps environment')
param containerAppEnvName string

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string = '${containerAppEnvName}-law'

@description('SKU of the Log Analytics workspace')
param logAnalyticsSku string = 'PerGB2018'

@description('Name of the Azure Container Registry')
param acrName string = '${containerAppEnvName}acr'

// Create a storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Create a file services resource
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
}

// Create a file share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileServices
  name: 'models'
  properties: {}
}

// Create a Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: 30
  }
}

// Create a Container Apps environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'gpu-a100'
        workloadProfileType: 'Consumption-GPU-NC24-A100'
      }
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// Create an Azure Container Registry with artifact streaming enabled
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    policies: {}
  }
}

// Create a storage account
resource volume 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: 'models'
  parent: containerAppEnv
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: listKeys(storageAccount.id, '2022-09-01').keys[0].value
      shareName: fileShare.name
      accessMode: 'ReadWrite'
    }
  }
}

// Create a user-assigned managed identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${containerAppEnvName}-identity'
  location: location
}

// Assign AcrPull role to the managed identity on the ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, userAssignedIdentity.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: userAssignedIdentity.properties.principalId
  }
}
