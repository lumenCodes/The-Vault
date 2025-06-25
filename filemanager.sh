#!/bin/bash

LOGFILE="filemanager.log"

echo "Usage: To use this storage you have to call the file and pass a command either upload, delete, list
  ./file_manager.sh upload <local-file> <blob-name>
  blob name is the name to use on cloud storage
      Upload a local file to Azure Blob Storage."

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"
}

# Hardcoded storage account and container
STORAGE_ACCOUNT_NAME="mainvaultstorage32091"
CONTAINER_NAME="publiccontainer"  

log "Script started with args: $*"

# Get storage key quietly, no key output to log
STORAGE_KEY=$(az storage account keys list --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv 2>>"$LOGFILE")
if [ -z "$STORAGE_KEY" ]; then
  log "ERROR: Failed to get storage account key. Check account name and login."
  exit 1
fi

upload_file() {
  local_file=$1
  blob_name=$2

  if [ ! -f "$local_file" ]; then
    log "ERROR: File $local_file not found."
    exit 1
  fi

  log "Uploading file '$local_file' as blob '$blob_name'..."
  if az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --name "$blob_name" \
    --file "$local_file" \
    --overwrite &>> "$LOGFILE"; then
    log "Upload successful."
  else
    log "ERROR: Upload failed."
    exit 1
  fi
}

download_file() {
  blob_name=$1
  local_file=$2

  log "Downloading blob '$blob_name' to file '$local_file'..."
  if az storage blob download \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --name "$blob_name" \
    --file "$local_file" \
    --no-progress &>> "$LOGFILE"; then
    log "Download successful."
  else
    log "ERROR: Download failed."
    exit 1
  fi
}

list_files() {
  log "Listing blobs in container '$CONTAINER_NAME'..."
  if ! az storage blob list \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --output table 2>&1 | tee -a "$LOGFILE"; then
    log "ERROR: Listing blobs failed."
    exit 1
  fi
}

delete_file() {
  blob_name=$1

  log "Deleting blob '$blob_name'..."
  if az storage blob delete \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --name "$blob_name" &>> "$LOGFILE"; then
    log "Deletion successful."
  else
    log "ERROR: Deletion failed."
    exit 1
  fi
}

COMMAND="$1"

case "$COMMAND" in
  upload)
    if [ $# -ne 3 ]; then
      log "ERROR: Invalid usage for upload."
      echo "Usage: $0 upload <local-file> <blob-name>"
      exit 1
    fi
    upload_file "$2" "$3"
    ;;
  download)
    if [ $# -ne 3 ]; then
      log "ERROR: Invalid usage for download."
      echo "Usage: $0 download <blob-name> <local-file>"
      exit 1
    fi
    download_file "$2" "$3"
    ;;  list)
    if [ $# -ne 1 ]; then
      log "ERROR: Invalid usage for list."
      echo "Usage: $0 list"
      exit 1
    fi
    list_files
    ;;
  delete)
    if [ $# -ne 2 ]; then
      log "ERROR: Invalid usage for delete."
      echo "Usage: $0 delete <blob-name>"
      exit 1
    fi
    delete_file "$2"
    ;;
  *)
    log "ERROR: Unknown command '$COMMAND'"
    echo "Available commands: upload, download, list, delete"
    exit 1
    ;;
esac

log "Script completed."
