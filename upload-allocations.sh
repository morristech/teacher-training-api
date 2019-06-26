#!/bin/sh

files=$(ls public/*.xlsx)

echo "Getting access key"
access_key=`az storage account keys list --account-name sadfebatallocations --subscription "DFE BAT Development" --query "[?keyName == 'key1'].value | [0]"`;


az storage blob upload-batch --destination find-allocations --source ./public --pattern "*.xlsx"  --connection-string "DefaultEndpointsProtocol=https;AccountName=sadfebatallocations;AccountKey=$access_key;EndpointSuffix=core.windows.net" --verbose

echo "Link is: https://sadfebatallocations.blob.core.windows.net/find-allocations/filename"
