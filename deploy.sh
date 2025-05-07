#!/bin/bash

# Check if the resource group name is provided
if [ -z "$1" ]; then
  echo "Error: Resource group name is required."
  echo "Usage: $0 <resource-group-name>"
  exit 1
fi

# Assign the resource group name
resource_group_name="$1"

# Define the resource name by appending the naming suffix to "acamodelstore"
resource_name="acamodelstore"

# Get the location of the parent resource group
location=$(az group show --name "$resource_group_name" --query "location" -o tsv)

# Deploy the Bicep file
az deployment group create \
  --resource-group "$resource_group_name" \
  --template-file ./infra/containerAppEnvironment.bicep \
  --parameters containerAppEnvName="$resource_name"

# Build and push the Docker images
ACR_NAME="${resource_name}acr"
az acr build -r $ACR_NAME -t "modelinit:latest" apps/initJob
az acr build -r "${resource_name}acr" -t "inferenceapp:latest" apps/inferenceApp
az acr build -r "${resource_name}acr" -t "azcopy:latest" apps/azcopy

# Prompt user for their HuggingFace Token
read -p "Please provide a HuggingFace token to download the model: " HF_TOKEN

# Deploy the init job to download and store the model files
az deployment group create \
  --resource-group "$resource_group_name" \
  --template-file ./apps/initJob/modelInitJob.bicep \
  --parameters jobName="initjob" containerAppEnvName="$resource_name" huggingFaceToken="$HF_TOKEN" registry=$ACR_NAME userAssignedIdentityName="${resource_name}-identity"
az containerapp job start -n initjob -g $resource_group_name

# Deploy the inference application with azcopy as an init container
az deployment group create \
  --resource-group "$resource_group_name" \
  --template-file ./apps/inferenceApp/inferenceApp.bicep \
  --parameters appName="inferenceapp" containerAppEnvName="$resource_name" storageAccountName="${resource_name}sa" registry=$ACR_NAME userAssignedIdentityName="${resource_name}-identity"