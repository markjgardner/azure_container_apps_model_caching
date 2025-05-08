@description('Name of the Container App')
param appName string

@description('Name of the Container App Environment')
param containerAppEnvName string

@description('Resource Group Location')
param location string = resourceGroup().location

@description('Storage Account Name')
param storageAccountName string

@description('Registry name')
param registry string

@description('Name of the user-assigned identity')
param userAssignedIdentityName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' existing = {
  parent: fileService
  name: 'models'
}

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: appName
  location: location
  properties: {
    environmentId: resourceId('Microsoft.App/managedEnvironments', containerAppEnvName)
    configuration: {
      registries: [
        {
          identity: userAssignedIdentity.id
          server: '${registry}.azurecr.io'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'download-models'
          image: '${registry}.azurecr.io/azcopy:latest'
          command: [
            '/bin/bash', '-c'
          ]
          args: [
            'echo "Stopwatch-Start: $(date)" && azcopy copy "$SOURCE?$TOKEN" "/mnt/local" --recursive && echo "Stopwatch-Stop: $(date)" && tail -f /dev/null'
          ]
          resources: {
            cpu: 4
            memory: '8Gi'
          }
          env: [
            {
              name: 'SOURCE'
              value: 'https://${storageAccount.name}.file.core.windows.net/${fileShare.name}'
            }
            {
              name: 'TOKEN'
              value: storageAccount.listAccountSas('2024-01-01', {signedServices: 'f', signedResourceTypes: 'sco', signedPermission: 'rl', signedExpiry: '2025-12-31T23:59:59Z', signedProtocol: 'https'}).accountSasToken
              
            }
          ]
          volumeMounts: [
            {
              volumeName: 'localmodels'
              mountPath: '/mnt/local'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'localmodels'
          storageType: 'EmptyDir'
        }
      ]
      scale: {
        maxReplicas: 1
        minReplicas: 1
      }
    }
    workloadProfileName: 'gpu-a100'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
}
