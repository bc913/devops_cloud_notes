# Azure Container Apps (using Azure CLI)
## Minimal Configuration

1. Sign in to Azure from the CLI with the following command. To complete the authentication process, make sure to follow all the prompts.

    ```azurecli
    az login
    ```

    ```azurecli
    az upgrade
    ```

2. Install or update the Azure Container Apps extension for the Azure CLI.

    ```azurecli
    az extension add --name containerapp --upgrade
    az extension add --upgrade --name application-insights
    ```

    > [!NOTE]
    > If you receive errors about missing parameters when you run `az containerapp` commands, be sure you have the latest version of the Azure Container Apps extension installed.

Register some namespaces
    ```azurecli
    az provider register --namespace Microsoft.App
    az provider register --namespace Microsoft.OperationalInsights
    ```

3. Now that your Azure CLI setup is complete, you can define a set of environment variables. Before you run the following command, review the provided values.

    === "PowerShell"

        ```shell
        $APP_NAME="taskstracker"
        # Create a random, 6-digit, Azure safe string
        $RANDOM_STRING=-join ((97..122) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_})
        $RESOURCE_GROUP="rg-$APP_NAME-$RANDOM_STRING"
        $LOCATION="westus2"
        $ENVIRONMENT="cae-$APP_NAME"
        $WORKSPACE_NAME="log-$APP_NAME-$RANDOM_STRING"
        $APPINSIGHTS_NAME="appi-$APP_NAME-$RANDOM_STRING"
        $BACKEND_API_NAME="$APP_NAME-backend-api"
        $FRONTEND_WEBAPP_NAME="$APP_NAME-frontend-webapp"
        $MAN_IDENTITY_NAME="$APP_NAME-man-id"
        $AZURE_CONTAINER_REGISTRY_NAME="cr$APP_NAME$RANDOM_STRING"
        $VNET_NAME="vnet-$APP_NAME"
        $TARGET_PORT=8080
        ```
    === "Bash"

        ```shell
        export APP_NAME="taskstracker"
        # Create a random, 6-digit, Azure safe string
        export RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
        export RESOURCE_GROUP="rg-$APP_NAME-$RANDOM_STRING"
        export LOCATION="westus2"
        export ENVIRONMENT="cae-$APP_NAME"
        export WORKSPACE_NAME="log-$APP_NAME-$RANDOM_STRING"
        export APPINSIGHTS_NAME="appi-$APP_NAME-$RANDOM_STRING"
        export BACKEND_API_NAME="$APP_NAME-backend-api"
        export FRONTEND_WEBAPP_NAME="$APP_NAME-frontend-webapp"
        export MAN_IDENTITY_NAME="$APP_NAME-man-id"
        export AZURE_CONTAINER_REGISTRY_NAME="cr$APP_NAME$RANDOM_STRING"
        export VNET_NAME="vnet-$APP_NAME"
        export TARGET_PORT=8080
        ```

> `REGISTRY_NAME="mydemoregistry$(openssl rand -hex 4)" ` command generates a random string to use as your container registry name. Registry names must be globally unique, so this string helps ensure your commands run successfully.

4. Create a resource group to organize the services related to your container app deployment.

    === "PowerShell"

        ```shell
        az group create `
        --name $RESOURCE_GROUP `
        --location $LOCATION `
        --output none
        ```
    === "Bash"

        ```shell
        az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
        ```

5. Create a [user-assigned managed identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) and get its ID with the following commands.

    First, create the managed identity.

    === "PowerShell"

        ```shell
        az identity create `
        --name $MAN_IDENTITY_NAME `
        --resource-group $RESOURCE_GROUP `
        --output none
        ```
    === "Bash"

        ```shell
        az identity create \
        --name "$MAN_IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output none
        ```

    Now set the identity identifier into a variable for later use.

    === "PowerShell"

        ```shell
       $MAN_IDENTITY_ID=az identity show `
        --name $MAN_IDENTITY_NAME `
        --resource-group $RESOURCE_GROUP `
        --query id `
        --output tsv
        ```
    === "Bash"

        ```shell
        export MAN_IDENTITY_ID=$(az identity show \
        --name "$MAN_IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)
        ```

    [OPTIONAL] Get service principal ID of the user-assigned identity

    === "PowerShell"

        ```shell
       $MAN_IDENTITY_SP_ID=az identity show `
        --name $MAN_IDENTITY_NAME `
        --resource-group $RESOURCE_GROUP `
        --query principalId `
        --output tsv
        ```
    === "Bash"

        ```shell
        export MAN_IDENTITY_SP_ID=$(az identity show \
        --name "$MAN_IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query principalId \
        --output tsv)
        ```
    ```bash
    ```


6. Create an Azure Container Registry (ACR) instance in your resource group. The registry stores your container image.

- First, create the Azure Container Registry

    === "PowerShell"

        ```shell
        az acr create `
        --name $AZURE_CONTAINER_REGISTRY_NAME `
        --resource-group $RESOURCE_GROUP `
        --sku Basic `
        --output none
        ```
    === "Bash"

        ```shell
        az acr create \
        --name "$AZURE_CONTAINER_REGISTRY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Basic \
        --output none
        ```
!!! note
    Notice that we create the registry with admin rights `--admin-enabled` flag set to `true` which is not suited for real production, but good for our workshop.

- Assign your user-assigned managed identity to your container registry instance with the following command.

    === "PowerShell"

        ```shell
        az acr identity assign `
        --identities $MAN_IDENTITY_ID `
        --name $AZURE_CONTAINER_REGISTRY_NAME `
        --resource-group $RESOURCE_GROUP `
        --output none
        ```
    === "Bash"

        ```shell
        az acr identity assign \
        --identities "$MAN_IDENTITY_ID" \
        --name "$AZURE_CONTAINER_REGISTRY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output none
        ```
This command adds the `acrPull` role to your user-assigned managed identity, so it can pull images from your container registry.

7. Build and push your container image to your container registry instance with the following command.

[https://learn.microsoft.com/en-us/azure/container-registry/container-registry-best-practices#repository-namespaces](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-best-practices#repository-namespaces)

=== "PowerShell"
```shell
    # Build and push container image to image repository for the backend api
    az acr build `
        --registry $AZURE_CONTAINER_REGISTRY_NAME `
        --image "$APP_NAME/$BACKEND_API_NAME" `
        --file "src/album_api/Dockerfile" .


    # Build and push container image to image repository for the frontend app
    az acr build `
        --registry $AZURE_CONTAINER_REGISTRY_NAME `
        --image "$APP_NAME/$FRONTEND_WEBAPP_NAME" `
        --file "src/album_ui/Dockerfile" .

    # Alternative
    #az acr build -t $AZURE_CONTAINER_REGISTRY_NAME".azurecr.io/"$BACKEND_API_NAME":helloworld" -r $AZURE_CONTAINER_REGISTRY_NAME .
```
=== "Bash"
```shell
    # Build and push container image to image repository for the backend api
    az acr build \
        --registry "$AZURE_CONTAINER_REGISTRY_NAME" \
        --image "$APP_NAME/$BACKEND_API_NAME" \
        --file "src/album_api/Dockerfile" .


    # Build and push container image to image repository for the frontend app
    az acr build \
        --registry "$AZURE_CONTAINER_REGISTRY_NAME" \
        --image "$APP_NAME/$FRONTEND_WEBAPP_NAME" \
        --file "src/album_ui/Dockerfile" .

    # Alternative
    #az acr build -t $AZURE_CONTAINER_REGISTRY_NAME".azurecr.io/"$BACKEND_API_NAME":helloworld" -r $AZURE_CONTAINER_REGISTRY_NAME .
```
> Make sure this command is run through the root directory to make sure Docker's build context is correct.


6. Create a Container Apps environment to host your app using the following command. It encapsulates the container apps.

    ```azurecli
    az containerapp env create \
        --name $ENVIRONMENT \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --mi-user-assigned $MAN_IDENTITY_ID \
        --output none
    ```

    === "PowerShell"

        ```shell
        # Create the ACA environment
        az containerapp env create `
        --name $ENVIRONMENT `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --mi-user-assigned $MAN_IDENTITY_ID `
        --logs-workspace-id $WORKSPACE_ID `
        --logs-workspace-key $WORKSPACE_SECRET `
        --dapr-instrumentation-key $APPINSIGHTS_INSTRUMENTATIONKEY `
        --enable-workload-profiles `
        --infrastructure-subnet-resource-id $ACA_ENVIRONMENT_SUBNET_ID
        ```
    === "Bash"

        ```shell
        # Create the ACA environment
        az containerapp env create \
        --name "$ENVIRONMENT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --mi-user-assigned $MAN_IDENTITY_ID \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_SECRET" \
        --dapr-instrumentation-key "$APPINSIGHTS_INSTRUMENTATIONKEY" \
        --enable-workload-profiles \
        --infrastructure-subnet-resource-id "$ACA_ENVIRONMENT_SUBNET_ID"

7. Create your container app with the following command.

- Create container app for backend service

    === "PowerShell"

        ```shell
        $fqdn=(az containerapp create `
        --name $BACKEND_API_NAME `
        --resource-group $RESOURCE_GROUP `
        --environment $ENVIRONMENT `
        --image "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/$APP_NAME/$BACKEND_API_NAME" `
        --registry-server "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io" `
        --target-port $TARGET_PORT `
        --ingress 'external' `
        --user-assigned $MAN_IDENTITY_ID `
        --registry-identity $MAN_IDENTITY_ID `
        --query properties.configuration.ingress.fqdn `
        --min-replicas 1 `
        --max-replicas 1 `
        --cpu 0.25 `
        --memory 0.5Gi `
        --output tsv)

        $BACKEND_API_EXTERNAL_BASE_URL="https://$fqdn"

        echo "See a listing of tasks created by the author at this URL:"
        echo "https://$fqdn/api/tasks/?createdby=tjoudeh@bitoftech.net"
        ```
    === "Bash"

        ```shell
        fqdn=$(az containerapp create \
        --name "$BACKEND_API_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$ENVIRONMENT" \
        --image "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/$APP_NAME/$BACKEND_API_NAME" \
        --registry-server "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io" \
        --target-port "$TARGET_PORT" \
        --ingress external \
        --user-assigned "$MAN_IDENTITY_ID" \
        --registry-identity "$MAN_IDENTITY_ID" \
        --query properties.configuration.ingress.fqdn \
        --min-replicas 1 \
        --max-replicas 1 \
        --cpu 0.25 \
        --memory 0.5Gi \
        --output tsv)

        export BACKEND_API_EXTERNAL_BASE_URL="https://$fqdn"

        echo "See a listing of tasks created by the author at this URL:"
        echo "https://$fqdn/api/tasks/?createdby=tjoudeh@bitoftech.net"
        ```
- Create container app for frontend app

    === "PowerShell"

        ```shell
        $frontend_fqdn=(az containerapp create `
        --name "$FRONTEND_WEBAPP_NAME"  `
        --resource-group $RESOURCE_GROUP `
        --environment $ENVIRONMENT `
        --image "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/APP_NAME/$FRONTEND_WEBAPP_NAME" `
        --registry-server "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io" `
        --env-vars "BackendApiConfig__BaseUrlExternalHttp=$BACKEND_API_EXTERNAL_BASE_URL/" `
        --target-port $TARGET_PORT `
        --ingress 'external' `
        --query properties.configuration.ingress.fqdn `
        --min-replicas 1 `
        --max-replicas 1 `
        --cpu 0.25 `
        --memory 0.5Gi `
        --output tsv)

        $FRONTEND_UI_BASE_URL="https://$frontend_fqdn"

        echo "See the frontend web app at this URL:"
        echo $FRONTEND_UI_BASE_URL
        ```
    === "Bash"

        ```shell
        frontend_fqdn=$(az containerapp create \
          --name "$FRONTEND_WEBAPP_NAME" \
          --resource-group "$RESOURCE_GROUP" \
          --environment "$ENVIRONMENT" \
          --image "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/tasksmanager/$FRONTEND_WEBAPP_NAME" \
          --registry-server "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io" \
          --env-vars "BackendApiConfig__BaseUrlExternalHttp=$BACKEND_API_EXTERNAL_BASE_URL/" \
          --target-port "$TARGET_PORT" \
          --ingress external \
          --query properties.configuration.ingress.fqdn \
          --min-replicas 1 \
          --max-replicas 1 \
          --cpu 0.25 \
          --memory 0.5Gi \
          --output tsv)

        export FRONTEND_UI_BASE_URL="https://$frontend_fqdn"

        echo "See the frontend web app at this URL:"
        echo "$FRONTEND_UI_BASE_URL"
        ```

!!! tip
    Notice how we used the property `env-vars` to set the value of the environment variable named `BackendApiConfig:BaseUrlExternalHttp` which we added in the AppSettings.json file, using the double underscore delimiter for the indented property. You can set multiple environment variables at the same time by using a space between each variable.
    The `ingress` property is set to `external` as the Web frontend App will be exposed to the public internet for users.

After you run the command, copy the FQDN (Application URL) of the Azure container app named `tasksmanager-frontend-webapp` and open it in your browser, and you should be able to browse the frontend web app and manage your tasks.

## Updating Configuration
So far the Frontend App is sending HTTP requests to the publicly exposed Web API. This means that any REST client can invoke the Web API. We need to change the Web API ingress settings and make it accessible only by applications deployed within our Azure Container Environment. Any application outside the Azure Container Environment should not be able to access the Web API.

- To change the settings of the Backend API, execute the following command:

    === "PowerShell"

        ```shell
        $fqdn=(az containerapp ingress enable `
        --name $BACKEND_API_NAME  `
        --resource-group $RESOURCE_GROUP `
        --target-port $TARGET_PORT `
        --type "internal" `
        --query fqdn `
        --output tsv)

        $BACKEND_API_INTERNAL_BASE_URL="https://$fqdn"

        echo "The internal backend API URL:"
        echo $BACKEND_API_INTERNAL_BASE_URL
        ```
    === "Bash"

        ```shell
        fqdn=$(az containerapp ingress enable \
          --name "$BACKEND_API_NAME" \
          --resource-group "$RESOURCE_GROUP" \
          --target-port "$TARGET_PORT" \
          --type internal \
          --query fqdn \
          --output tsv)

        export BACKEND_API_INTERNAL_BASE_URL="https://$fqdn"

        echo "The internal backend API URL:"
        echo "$BACKEND_API_INTERNAL_BASE_URL"
        ```

 - Now we will need to update the Frontend Web App environment variable to point to the **internal** backend Web API FQDN. The last thing we need to do here is to update the Frontend WebApp environment variable named `BackendApiConfig:BaseUrlExternalHttp` with the new value of the *internal* Backend Web API base URL, to do so we need to update the Web App container app and it will create a new revision implicitly (more about revisions in the upcoming modules). We need to use the double underscore format to set the variable. The following command will update the container app with the changes:

    === "PowerShell"

        ```shell
        az containerapp update `
        --name "$FRONTEND_WEBAPP_NAME" `
        --resource-group $RESOURCE_GROUP `
        --set-env-vars "BackendApiConfig__BaseUrlExternalHttp=$BACKEND_API_INTERNAL_BASE_URL/"
        ```
    === "Bash"

        ```shell
        az containerapp update \
        --name "$FRONTEND_WEBAPP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --set-env-vars "BackendApiConfig__BaseUrlExternalHttp=$BACKEND_API_INTERNAL_BASE_URL/"
        ```

> BackendApiConfig:BaseUrlExternalHttp is defined as environment variable under appsettings.json file for the frontend or any application.

## Clean up resources

If you're not going to use the Azure resources created in this tutorial, you can remove them with a single command. Before you run the command, there's a next step in this tutorial series that shows you how to [make changes to your code and update your app in Azure](./tutorial-update-from-code.md).

If you're done and want to remove all Azure resources created in this tutorial, delete the resource group with the following command.

```azurecli
az group delete --name aca-demo
```
## References
- [Microsoft Learn - Tutorial: Build and deploy from source code to Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-deploy-from-code?tabs=csharp)
- [Azure Container Apps - Workshop]
    - [Azure Container Apps - Workshop](https://azure.github.io/aca-dotnet-workshop/)
    - [Github](https://github.com/Azure/aca-dotnet-workshop)
- Build and deploy your BACKEND app to Azure Container Apps
    - [Tutorial](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-code-to-cloud?tabs=bash%2Ccsharp&pivots=acr-remote)
    - [Github](https://github.com/Azure-Samples/containerapps-albumapi-csharp/tree/main)
- Build and deploy your FRONTEND app to Azure Container Apps
    - [Tutorial](https://learn.microsoft.com/en-us/azure/container-apps/communicate-between-microservices?tabs=bash&pivots=acr-remote)
    - [Github](https://github.com/Azure-Samples/containerapps-albumui/tree/main)
- [Deploy cloud-native apps using Azure Container Apps Microsoft Learn - Training Module](https://learn.microsoft.com/en-us/training/paths/deploy-cloud-native-applications-to-azure-container-apps/)
- [Azure Container Apps - QuickStart](https://hexmaster.nl/posts/azure-container-apps-quickstart/)
- [Java Dapr Workshop for Azure Kubernetes Service and Azure Container Apps](https://azure.github.io/java-aks-aca-dapr-workshop/)