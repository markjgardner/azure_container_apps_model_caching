@description('Name of the Container App Job')
param jobName string

@description('Name of the Container App Environment')
param containerAppEnvName string

@description('Resource Group Location')
param location string = resourceGroup().location

@description('HuggingFace Token')
param huggingFaceToken string

@description('Registry name')
param registry string

@description('Name of the user-assigned identity')
param userAssignedIdentityName string

@description('Storage Account Name')
param storageAccountName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  name: 'models'
  parent: blobService 
}

resource containerAppJob 'Microsoft.App/jobs@2025-01-01' = {
  name: jobName
  location: location
  properties: {
    environmentId: resourceId('Microsoft.App/managedEnvironments', containerAppEnvName)
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 1800
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
          name: 'modelinit'
          image: '${registry}.azurecr.io/modelinit:latest'
          command: [
            '/bin/bash', '-c'
          ]
          args: [
            'huggingface-cli download --local-dir /mnt/models mistralai/Mistral-7B-Instruct-v0.1 && azcopy copy "/mnt/models" "$DEST?$SASTOKEN" --recursive'
          ]
          env: [
            {
              name: 'HF_TOKEN'
              value: huggingFaceToken
            }
            {
              name: 'DEST'
              value: 'https://${storageAccount.name}.blob.core.windows.net/models'
            }
            {
              name: 'SASTOKEN'
              value: storageAccount.listAccountSas('2024-01-01', {signedServices: 'b', signedResourceTypes: 'sco', signedPermission: 'rwdl', signedExpiry: '2025-12-31T23:59:59Z', signedProtocol: 'https'}).accountSasToken
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
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
          storageType: 'EmptyDir'
        }
      ]
    }
    workloadProfileName: 'Consumption'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
}
