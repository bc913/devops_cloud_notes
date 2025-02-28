# Azure Container Registry
## Features
- The Registry name must be unique within Azure, and contain 5-50 alphanumeric characters. No special characters are allowed (including "-", "_", and ".").

- The Location specified should match the location/region specified for other resources in your solution, such as virtual networks and other container resources.

- The availability zones option is a high-availability offering that provides resiliency and high availability to a container registry in a specific region.

- The Pricing plan can be used to select the performance level and capabilities required. The Basic, Standard, and Premium tiers all provide the same programmatic capabilities. They also all benefit from image storage managed entirely by Azure. Choosing a higher-level tier provides more performance and scale. You can get started with Basic, then convert to Standard and Premium as your registry usage increases. Premium registries provide the highest amount of included storage and concurrent operations, enabling high-volume scenarios. In addition to higher image throughput, Premium also adds features such as:

        - Geo-replication for managing a single registry across multiple regions.
        - Content trust for image tag signing.
        - Private link with private endpoints to restrict access to the registry.


## References
- [Configure Azure Container Registry for container app deployments](https://learn.microsoft.com/en-us/training/modules/configure-azure-container-registry-container-app-deployments/?source=recommendations)

- [Azure Container Apps image pull with managed identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull?tabs=bash&pivots=bicep)

- [Using Managed Identity and Bicep to pull images with Azure Container Apps](https://azureossd.github.io/2023/01/03/Using-Managed-Identity-and-Bicep-to-pull-images-with-Azure-Container-Apps/)

- [Authenticate with an Azure container registry](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli)

- [Azure Container Registry roles and permissions](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-roles?tabs=azure-cli)