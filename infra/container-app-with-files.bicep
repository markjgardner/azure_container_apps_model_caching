@description('Name of the Azure Container App')
param containerAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the storage account')
param storageAccountName string

@description('Name of the Container Apps environment')
param containerAppEnvName string

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string = '${containerAppEnvName}-law'

@description('SKU of the Log Analytics workspace')
param logAnalyticsSku string = 'PerGB2018'

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
      accessMode: 'ReadOnly'
    }
  }
}

// Create the Azure Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  dependsOn: [
    volume
  ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Multiple'
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: 'mcr.microsoft.com/azure-cli:latest'
          command: [
            '/bin/sh', '-c'
          ]
          args: [
            'ls /mnt/models && sleep infinity'
          ]
          volumeMounts: [
            {
              volumeName: 'models'
              mountPath: '/mnt/models'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'models'
          storageType: 'AzureFile'
          storageName: 'models'
        }
      ]
    }
  }
}
