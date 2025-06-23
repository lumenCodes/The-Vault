#!/bin/bash

# --- The vault Storage Account and Container Creation Script ---
# This script will handle creation of a resource group. For this project
# variables will not be used.

# To exit if there is an error.
set -e

# --- Configuration Variables ---

RESOURCE_GROUP_NAME="theVaultRG"      # Name of the Azure Resource Group
STORAGE_ACCOUNT_NAME="thevaultstorageaccount$(date +%s)" # Globally unique storage account name including date for uniquesness
CONTAINER_NAME="TheVault"                   # Name of the Blob Container
LOCATION="eastus"                          # Azure region for resources (e.g., eastus, westus2, westeurope)
SKU="Standard_LRS"                         # Storage account SKU (e.g., Standard_LRS, Standard_GRS)
KIND="StorageV2"                           # Storage account kind (StorageV2 is recommended)

echo "Starting Azure Storage deployment..."
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo "Location: $LOCATION"

LOG_FILE="theVaultLog.log" # File to store deployment logs

# --- Helper Function for Logging ---
# Function to log messages to console and file
log_action() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="$1"
    echo "[$timestamp] $message" | tee -a "$LOG_FILE" # the tee allows logging to the file and also on the terminal that is stdout
}

log_action "Starting Azure Storage deployment..."
log_action "Resource Group: $RESOURCE_GROUP_NAME"
log_action "Storage Account: $STORAGE_ACCOUNT_NAME"
log_action "Container: $CONTAINER_NAME"
log_action "Location: $LOCATION"

# Azure CLI is needed so first we confirm it is installed
log_action "Checking for Azure CLI..."
if ! command -v az &> /dev/null
then
    log_action "ERROR: Azure CLI is not installed. Please install it to continue." # errors are labelled as error to aid in debbugging
    exit 1
else
    log_action "Azure CLI found."
fi

# Since we are using github action we are going to use secure loigin using service principal to avoid human interaction during deployment.

log_action "Logging into Azure CLI..."

# Check for environment variables saved in GitHub Actions or Service Principal with client secret.

if [[ -n "$AZURE_CLIENT_ID" && -n "$AZURE_TENANT_ID" && (-n "$AZURE_CLIENT_SECRET" || -n "$AZURE_FEDERATED_TOKEN_FILE") ]]; then
    log_action "Attempting login with Service Principal (environment variables detected)..."
    if [[ -n "$AZURE_FEDERATED_TOKEN_FILE" ]]; then
        log_action "Using OIDC with federated token file for login."
        az login --service-principal -u "$AZURE_CLIENT_ID" --tenant "$AZURE_TENANT_ID" --federated-token "$(cat "$AZURE_FEDERATED_TOKEN_FILE")" --output none
    elif [[ -n "$AZURE_CLIENT_SECRET" ]]; then
        # This block is for Service Principal authentication using a client secret.
        # While functional, OIDC is generally more secure as it avoids long-lived secrets.
        log_action "Using Service Principal with client secret for login."
        az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID" --output none
    fi

    if [ $? -eq 0 ]; then
        log_action "Azure login with Service Principal successful."
    else
        log_action "ERROR: Failed to log into Azure CLI with Service Principal. Check credentials and permissions."
        exit 1
    fi
else
    # Fallback for local interactive login or if credentials are already cached
    log_action "No Service Principal environment variables found. Attempting interactive or cached login..."
    if ! az account show &> /dev/null; then
        if az login --output none; then
            log_action "Azure interactive/cached login successful."
        else
            log_action "ERROR: Failed to log into Azure CLI interactively. Please log in manually."
            exit 1
        fi
    else
        log_action "Already logged into Azure (interactive/cached session)."
    fi
fi

# 3. Create a Resource Group
# A resource group is a logical container for Azure resources.
log_action "Creating resource group '$RESOURCE_GROUP_NAME' in location '$LOCATION'..."
if az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --output none; then
    log_action "Resource group '$RESOURCE_GROUP_NAME' created or already exists."
else
    log_action "FAILURE: Failed to create or verify resource group '$RESOURCE_GROUP_NAME'."
    exit 1
fi

# 4. Create a Storage Account
# This is where your blobs (files) will be stored.
# --allow-blob-public-access true: Enables public access at the storage account level.
# --min-tls-version TLS1_2: Ensures secure communication.
log_action "Creating storage account '$STORAGE_ACCOUNT_NAME'..."
if az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --kind "$KIND" \
    --allow-blob-public-access true \
    --min-tls-version TLS1_2 \
    --output none; then
    log_action "Storage account '$STORAGE_ACCOUNT_NAME' created or already exists."
else
    log_action "FAILURE: Failed to create or verify storage account '$STORAGE_ACCOUNT_NAME'."
    exit 1
fi

# 5. We need to get the Storage Account Connection String
# This is needed for interacting with the storage account without specific keys.
log_action "Retrieving storage account connection string..."
CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query 'connectionString' \
    --output tsv)

if [ -z "$CONNECTION_STRING" ]; then
    log_action "ERROR: Failed to retrieve connection string. Exiting."
    exit 1
fi
log_action "Connection string retrieved."

# 6. Create a Blob Container
# This is like a folder within your storage account.
# --public-access blob: Allows public read access to blobs in this container.
#                     (Alternatively, 'container' for public read access to blobs and container metadata)
log_action "Creating blob container '$CONTAINER_NAME' in storage account '$STORAGE_ACCOUNT_NAME' with public access..."
if az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --public-access blob \
    --connection-string "$CONNECTION_STRING" \
    --output none; then
    log_action "Container '$CONTAINER_NAME' created or already exists with public access enabled."
else
    log_action "FAILURE: Failed to create or verify container '$CONTAINER_NAME'."
    exit 1
fi

log_action "Deployment complete! Your storage account and container are ready."
log_action "You can now use the connection string to manage files:"
log_action "Connection String: $CONNECTION_STRING"
log_action "Storage Account Name: $STORAGE_ACCOUNT_NAME"
log_action "Container Name: $CONTAINER_NAME"

# We are exporting variables for subsequent scripts like the github actions and file management script
export AZURE_STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME"
export AZURE_STORAGE_CONTAINER_NAME="$CONTAINER_NAME"
export AZURE_STORAGE_CONNECTION_STRING="$CONNECTION_STRING"
