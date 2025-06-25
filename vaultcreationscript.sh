#!/bin/bash
# SUBSCRIPTION_ID="6d3e385a-7a1e-46b8-843c-09a31d69afca"

RESOURCE_GROUP="newvaultgroup"
LOCATION="eastus"
STORAGE_ACCOUNT_NAME="mainvaultstorage$RANDOM"  # must be globally unique, lowercase, no special chars, length 3-24
CONTAINER_NAME="publiccontainer"

set -e

# echo "Setting subscription to $SUBSCRIPTION_ID"
# az account set --subscription "$SUBSCRIPTION_ID"


echo "Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "Creating storage account..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2

echo "Creating blob container with public access..."
az storage container create \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --name "$CONTAINER_NAME" \
  --public-access blob

echo "Storage account and container created successfully."
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo "$STORAGE_ACCOUNT_NAME" > storage_name.txt
echo "$CONTAINER_NAME" >> storage_name.txt
echo "$RESOURCE_GROUP" >> storage_name.txt

