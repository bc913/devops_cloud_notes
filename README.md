# Devops & Cloud Computing Notes
This repo consists of my notes & code snippets for the topics of `Devops` and `Cloud Computing`.
## Devops Guidelines & Best Practices
- [Versioning & Branching](devops/versioning.md)
- [Packaging](devops/packaging.md)
- [Code Coverage](devops/code_coverage.md)

## Development Environment
### Windows
- [VS cmd line installation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019)
- [Installation](https://learn.microsoft.com/en-us/answers/questions/1185838/silent-install-of-vs-2019-community-and-vs-build-t)
- [](https://learn.microsoft.com/en-us/visualstudio/install/tools-for-managing-visual-studio-instances?view=vs-2022)
#### VS2019
- https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-professional?view=vs-2019
- https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2019
- [Install build tools to container](https://learn.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019)
- [Advanced example](https://learn.microsoft.com/en-us/visualstudio/install/advanced-build-tools-container?view=vs-2019)
### VS2022 [TODO]

#### Windows Container Images
- [Windows Base](https://hub.docker.com/_/microsoft-windows)
- [Windows Server](https://hub.docker.com/_/microsoft-windows-server)
- [Windows Server Core](https://hub.docker.com/_/microsoft-windows-servercore)
- [Dotnet framework Images](https://github.com/microsoft/dotnet-framework-docker/blob/main/src/runtime/4.8/windowsservercore-ltsc2019/Dockerfile)
- [](https://hub.docker.com/_/microsoft-dotnet-framework-sdk)
- [C++ Container Images](https://hub.docker.com/_/microsoft-devcontainers-cpp)
- [.net framework](https://hub.docker.com/_/microsoft-dotnet-framework/)

#### CMake
- VcToolsVersion
    - https://developercommunity.visualstudio.com/t/vctoolsversion-does-not-work-for-cmake/1157655
    - https://gitlab.kitware.com/cmake/cmake/-/issues/22420
    - https://discourse.cmake.org/t/how-do-i-set-the-compiler-version-for-visual-studio-generator-with-cmake-presets/8779
    - https://gitlab.kitware.com/cmake/cmake/-/issues/25192


## Azure
### Devops
- [Azure Pipelines](azure/devops/azure_pipelines.md)
- [Deployment & Publishing Packages](azure/devops/deployment_publishing_packages.md)

### Cloud
- [Web Application with Authentication using AAD B2C & App Services](azure/cloud/WebApp_AAD_B2C_and_AppService.md)
- [App Service](azure/cloud/AppService.md)