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

## Nerdbank Git-Versioning Usage
```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.4-alpha",
  "assemblyVersion": {
    "precision": "revision"
  },
  "publicReleaseRefSpec": [
    "^refs/heads/master$",
    "^refs/heads/develop$",
    "^refs/heads/release/v\\d+(?:\\.\\d+)?$",
    "^refs/tags/v\\d+\\.\\d+"
  ],
  "cloudBuild": {
    "buildNumber": {
      "enabled": true
    }
  },
  "release": {
    "branchName": "release/v{version}",
    "tagName" : "v{version}",
    "versionIncrement" : "minor",
    "firstUnstableTag": "alpha"
  }
}
```

- Policies:
    - Use `feature` or `hotfix` branches for regular development. If a package required on these branches, just run to get `nbgv get-version` to see the version.
    ```cmd
    Version:                      0.5.2.8457
    AssemblyVersion:              0.5.2.8457
    AssemblyInformationalVersion: 0.5.2-alpha+21092ec5b5
    NpmPackageVersion:            0.5.2-alpha.g21092ec5b5
    ```

    - After the corresponding `feature` or `hotfix` branches merged into `develop`, you can still create packages and version on develop. `nbgv get-version` will generate the following.
    ```cmd
    AssemblyVersion:              0.5.3.21671
    AssemblyInformationalVersion: 0.5.3-alpha+54a7a0c483
    NuGetPackageVersion:          0.5.3-alpha
    NpmPackageVersion:            0.5.3-alpha
    ```
    - To generate a public release, run `nbgv prepare-release` on `develop` branch. This will generate `release/v{version}` branch and increase the version accordingly based on `versionIncrement` value and merge it to back to develop. `nbgv get-version` will generate the following on `release/v{version}` branch.
    ```cmd
    AssemblyVersion:              0.5.8.16502
    AssemblyInformationalVersion: 0.5.8+40760002e6
    NuGetPackageVersion:          0.5.8
    NpmPackageVersion:            0.5.8
    ```
    - For next release, start working on updated `develop` branch. For the current release, start working on `release/v{version}` branch by branching off **ONLY** for bug fixes. No further feature development on current release.
    - Bug fixes from rel. branch may be continously merged back into `develop`.


## Tools
There are several tools to combine good branching and versioning practices.
- [GitVersion]
    - [Doc](https://gitversion.net/docs/)
    - [Github](https://github.com/GitTools/GitVersion)
- [Nerdbank.GitVersioning](https://github.com/dotnet/Nerdbank.GitVersioning)

## Useful links
- [Azure DevOps Labs](https://azuredevopslabs.com/)