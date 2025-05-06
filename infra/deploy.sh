#!/bin/bash

# Generate a random 8-character string
random_string=$(openssl rand -hex 4)
echo "Naming suffix: $random_string"

# Define the resource name by appending the random string to "acamodelstore"
resource_name="acamodelstore"

# Deploy the Bicep file
az deployment group create \
  --resource-group "$1" \
  --template-file container-app-with-files.bicep \
  --parameters containerAppName="${resource_name}app" storageAccountName="$resource_name$random_string" containerAppEnvName="${resource_name}env${random_string}" logAnalyticsWorkspaceName="${resource_name}logs"