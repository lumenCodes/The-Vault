#!/bin/bash

# --- The vault operation Script ---
# This script provides functions to upload, download, list, and delete
# files from the vault. I have also included logging

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Variables ---

# Referencing exported values from the vault Script
source ./theVaultScript.sh
AZURE_STORAGE_ACCOUNT_NAME=${AZURE_STORAGE_ACCOUNT_NAME:-""}
AZURE_STORAGE_CONTAINER_NAME=${AZURE_STORAGE_CONTAINER_NAME:-"TheVault"}
AZURE_STORAGE_CONNECTION_STRING=${AZURE_STORAGE_CONNECTION_STRING:-"DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;EndpointSuffix=core.windows.net"}


LOG_FILE="vaultOperations.log" # File to store operation logs


# Function to log messages
log_action() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="$1"
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to check for Azure CLI and ensure authentication
check_azure_cli() {
    log_action "Checking for Azure CLI..."
    if ! command -v az &> /dev/null; then
        log_action "ERROR: Azure CLI is not installed. Please install it to continue."
        exit 1
    fi
    log_action "Azure CLI found."

    log_action "Checking Azure login status..."
    if ! az account show &> /dev/null; then
        log_action "WARNING: Not logged into Azure. Attempting login..."
        if ! az login --output none; then
            log_action "ERROR: Failed to log into Azure CLI. Please log in manually."
            exit 1
        fi
        log_action "Azure login successful."
    else
        log_action "Already logged into Azure."
    fi

    # Ensure required variables are set
    if [ -z "$AZURE_STORAGE_ACCOUNT_NAME" ] || [ -z "$AZURE_STORAGE_CONTAINER_NAME" ]; then
        log_action "ERROR: AZURE_STORAGE_ACCOUNT_NAME or AZURE_STORAGE_CONTAINER_NAME is not set."
        log_action "Please set these variables in the script or as environment variables."
        exit 1
    fi
    log_action "Azure configuration variables detected."
}

# ---  File operations Functions ---

# Function to upload a file
# Usage: upload_file <local_file_path> [blob_name_in_storage]
upload_file() {
    local local_file="$1"
    local blob_name="${2:-$(basename "$local_file")}" # Use default name that is basename if blob_name is not provided

    if [ ! -f "$local_file" ]; then
        log_action "ERROR: Local file not found: '$local_file'"
        return 1
    fi

    log_action "Attempting to upload '$local_file' to '$blob_name' in container '$AZURE_STORAGE_CONTAINER_NAME'..."
    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
        --file "$local_file" \
        --name "$blob_name" \
        --overwrite true \
        --output none

    if [ $? -eq 0 ]; then
        log_action "SUCCESS: Uploaded '$local_file' as '$blob_name'."
    else
        log_action "FAILURE: Failed to upload '$local_file'."
        return 1
    fi
}

# Function to download a file
# Usage: download_file <blob_name_in_storage> [local_destination_path]
download_file() {
    local blob_name="$1"
    local local_dest="${2:-$(basename "$blob_name")}" # Use blob_name basename if local_dest is not provided

    log_action "Attempting to download '$blob_name' from container '$AZURE_STORAGE_CONTAINER_NAME' to '$local_dest'..."
    az storage blob download \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
        --name "$blob_name" \
        --file "$local_dest" \
        --output none

    if [ $? -eq 0 ]; then
        log_action "SUCCESS: Downloaded '$blob_name' to '$local_dest'."
    else
        log_action "FAILURE: Failed to download '$blob_name'."
        return 1
    fi
}

# Function to list files
# Usage: list_files

list_files() {
    log_action "Listing files in container '$AZURE_STORAGE_CONTAINER_NAME' (raw table output)..."
    echo "--- Files in $AZURE_STORAGE_CONTAINER_NAME ---" | tee -a "$LOG_FILE"
    az storage blob list \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
        --output table >> "$LOG_FILE" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Check if the output contains actual data or just headers
        # This is a used to check empty output from command failure.
        if ! grep -q -e "Name" -e "Length" -e "---" "$LOG_FILE"; then
            log_action "SUCCESS: No files found in container '$AZURE_STORAGE_CONTAINER_NAME'."
            echo "No files found." | tee -a "$LOG_FILE"
        else
            log_action "SUCCESS: Files listed."
        fi
    else
        log_action "FAILURE: Failed to list files. Check account/container names or permissions."
        # If the command failed, the error output would have been redirected to the log
    fi
    echo "-----------------------------------" | tee -a "$LOG_FILE"
}


# Function to delete a file
# Usage: delete_file <blob_name_in_storage>
delete_file() {
    local blob_name="$1"

    log_action "Attempting to delete '$blob_name' from container '$AZURE_STORAGE_CONTAINER_NAME'..."
    az storage blob delete \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
        --name "$blob_name" \
        --output none \
        --fail-on-error false # Don't fail script if blob doesn't exist

    if [ $? -eq 0 ]; then
        log_action "SUCCESS: Deleted '$blob_name'."
    else
        log_action "FAILURE: Failed to delete '$blob_name'. It might not exist."
        return 1
    fi
}


# this part calls the function alredy listed above
check_azure_cli

# Parse command line arguments
case "$1" in
    upload)
        if [ -z "$2" ]; then
            echo "Usage: $0 upload <local_file_path> [blob_name_in_storage]"
            exit 1
        fi
        upload_file "$2" "$3"
        ;;
    download)
        if [ -z "$2" ]; then
            echo "Usage: $0 download <blob_name_in_storage> [local_destination_path]"
            exit 1
        fi
        download_file "$2" "$3"
        ;;
    list)
        list_files
        ;;
    delete)
        if [ -z "$2" ]; then
            echo "Usage: $0 delete <blob_name_in_storage>"
            exit 1
        fi
        delete_file "$2"
        ;;
    *)
        echo "Usage: $0 {upload|download|list|delete} [arguments]"
        echo "Commands:"
        echo "  upload <local_file_path> [blob_name_in_storage] - Uploads a file."
        echo "  download <blob_name_in_storage> [local_destination_path] - Downloads a file."
        echo "  list                                            - Lists all files in the container."
        echo "  delete <blob_name_in_storage>                 - Deletes a file."
        exit 1
        ;;
esac

echo "Operation completed. Check '$LOG_FILE' for details."
