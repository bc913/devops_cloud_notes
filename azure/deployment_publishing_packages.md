# Deployment and Publishing Packages

## CD options
- YAML
    - Single staged - single job:
    - Single stage - multiple job:
    - Multi-stage:
        - [Publish](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/publish-build-artifacts?view=azure-devops) & [Download](https://docs.microsoft.com/en-us/azure/devops/pipelines/artifacts/pipeline-artifacts?view=azure-devops&tabs=yaml) artifacts and deploy with tasks
        - [Using deployment job](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/deployment-jobs?view=azure-devops)
        - Using Releases Pipeline (UI)
- Classic

## Deployment

## Publishing Packages
### Nuget
- [Nuget Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/package/nuget?view=azure-devops)
- [Package: NuGet Authenticate](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/package/nuget-authenticate?view=azure-devops)

Nuget packages can be published to public(i.e. Nuget.org) or private feeds (Azure Artifacts) using Azure Pipelines. Some adjustments are required.

#### Public feeds
I'll be covering Nuget.org feed in this section.
- A service connection has to be created.

## References:
- [Azure DevOps YAML release pipeline : Trigger when build pipeline completed ](https://dev.to/kenakamu/azure-devops-yaml-release-pipeline-trigger-when-build-pipeline-completed-54d5)