# Versioning & Branching
`Version` can be considered as a part of an identity of the released software product (i.e. library, framework, Web API or a desktop application) so `Versioning` is one of the most critical stages in the software development process.

## Semantic Versioning
In order to talk the same language between the developer side (individual or company) and consumer/client side (developer as API/library/framework client or end user of a Web/desktop app), a common contract for versioning should be available. `Semantic Versioning` can represent this contract.

In short, `Semantic Versioning` consists of three version numbers separated from each other by dot (.) notation, `MAJOR.MINOR.PATCH`. Changing/updating one or more of them carries a meaning relative to their previous values.

- **MAJOR** version when you make incompatible API changes,
- **MINOR** version when you add functionality in a backwards compatible manner, and
- **PATCH** version when you make backwards compatible bug fixes.

Check [https://semver.org/](https://semver.org/) for detailed information.

## Versioning in .NET
The knowledge is so scattered throughout the Microsoft documentation.
- [Versioning under Library Guidance section](https://docs.microsoft.com/en-us/dotnet/standard/library-guidance/versioning)
- [Assembly Versioning under Assemblies in .NET section](https://docs.microsoft.com/en-us/dotnet/standard/assembly/versioning)
- [Versioning in C# under C# Guide](https://docs.microsoft.com/en-us/dotnet/csharp/versioning)
- [Version Class documentation](https://docs.microsoft.com/en-us/dotnet/api/system.version?view=net-5.0)

This is a huge topic and I try to compile some of the benefical resources as follows:
1. [Version vs VersionSuffix vs PackageVersion: What do they all mean? by Andrew Lock](https://andrewlock.net/version-vs-versionsuffix-vs-packageversion-what-do-they-all-mean/)
2. [Best practices/guidance for maintaining assembly version numbers](https://stackoverflow.com/questions/3768261/best-practices-guidance-for-maintaining-assembly-version-numbers)
3. [Making Sense of AssemblyVersion Numbers](https://intellitect.com/making-sense-of-assemblyversion-numbers/)
4. [Setting assembly and nuget package metadata in .NET Core](https://cezarypiatek.github.io/post/setting-assembly-and-package-metadata/)
5. [Assembly Versioning and DLL Hell in C# .NET Framework: Problems and Solutions](https://michaelscodingspot.com/dotnet-dll-hell/)

### Good practices and good to knows
- `Assembly Version` number plays a distinguihing role ONLY for strong-named assemblies and strong-name assemblies is only good practice for .NET Framework. It is not necessary for .NET Core/5.0 assemblies.
- Do NOT set `Assembly informational version` manually.
- pass `--no-build` argument to `dotnet build` and `dotnet publish` commands not to reset the versions. 

## Semantic versioning and CI/CD
- [https://blog.ploeh.dk/2013/12/10/semantic-versioning-with-continuous-deployment/](https://blog.ploeh.dk/2013/12/10/semantic-versioning-with-continuous-deployment/)

- Versioning NuGet packages in a continuous delivery world
    - [Part 1](https://devblogs.microsoft.com/devops/versioning-nuget-packages-cd-1/)
    - [Part 2](https://devblogs.microsoft.com/devops/versioning-nuget-packages-cd-2/)
    - [Part 3](https://devblogs.microsoft.com/devops/versioning-nuget-packages-cd-3/)

- [Versioning .NET Core Assemblies in Azure DevOps isn’t Straightforward (and Probably Won’t be in Other CI/CD Tools Either)](https://pleasereleaseme.net/versioning-net-core-assemblies-in-azure-devops-isnt-straightforward-and-probably-wont-be-in-other-ci-cd-tools-either/)

## Branching
- [Understanding the GitHub flow](https://guides.github.com/introduction/flow/)
- [A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/)

## Tools
There are several tools to combine good branching and versioning practices.
- [GitVersion]
    - [Doc](https://gitversion.net/docs/)
    - [Github](https://github.com/GitTools/GitVersion)
- [Nerdbank.GitVersioning](https://github.com/dotnet/Nerdbank.GitVersioning)

## Useful links
- [Azure DevOps Labs](https://azuredevopslabs.com/)