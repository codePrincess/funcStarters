#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation=""

# Initialize parameters specified from command line
while getopts ":i:g:n:l:" arg; do
    case "${arg}" in
        i)
            subscriptionId=${OPTARG}
            ;;
        g)
            resourceGroupName=${OPTARG}
            ;;
        n)
            deploymentName=${OPTARG}
            ;;
        l)
            resourceGroupLocation=${OPTARG}
            ;;
        esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
    subscriptionId='3d24ddd6-7960-4073-aa3b-45cb236e0159'
    echo -e "\n\nSubscription Id --> $subscriptionId"
fi

if [[ -z "$resourceGroupName" ]]; then
    echo -e "\n\nResourceGroupName:"
    read resourceGroupName
fi

if [[ -z "$resourceGroupLocation" ]]; then
    echo -e "\n\nEnter a location below to create a new resource group else skip this"
    echo -e "ResourceGroupLocation:"
    read resourceGroupLocation
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ]; then
    echo -e "Either one of subscriptionId, resourceGroupName, deploymentName is empty"
    usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
    az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

#Check for existing RG
if [ $(az group exists --name $resourceGroupName) == 'false' ]; then
    echo -e "\n\nResource group with name" $resourceGroupName "could not be found. Creating new resource group.."
    (
        set -x
        az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
    )
    else
    echo -e "\n\nUsing existing resource group..."
fi

set -u 
declare storagename=$resourceGroupName'storage'
declare functionname=$resourceGroupName'app'

#Create storage
echo -e "\n\nCreate storage for function app..."
(     
    set -x
    az storage account create --name $storagename --location $resourceGroupLocation --resource-group $resourceGroupName --sku Standard_LRS
)

if [ $?  == 0 ];
then
    echo "Storage has been successfully created"
fi

#Create function app
echo -e "\n\nCreate function app..."
(
    set -u
    az functionapp create --name $functionname --storage-account $storagename --resource-group $resourceGroupName --consumption-plan-location $resourceGroupLocation
)

if [ $?  == 0 ];
then
    echo "Function app has been successfully created"
fi

#Deploy function itself to function app
echo -e "\n\nDeploy function endpoints via GitHub to function app..."
(
    set -x
    az functionapp deployment source config --name $functionname --resource-group $resourceGroupName --branch master --repo-url https://github.com/codePrincess/funcStarters --manual-integration 
)

if [ $?  == 0 ];
then
    echo "Function app successfully setup with endpoints"
fi