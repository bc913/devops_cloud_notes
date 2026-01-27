# Packaging

## Nuget
- [https://docs.microsoft.com/en-us/dotnet/standard/library-guidance/nuget](https://docs.microsoft.com/en-us/dotnet/standard/library-guidance/nuget)

### Best practices and good to knows
- Consider enabling [`Deterministic Builds`](https://github.com/clairernovotny/DeterministicBuilds).

- Consider using `Source Link`:
    - [Source Link Documentation](https://docs.microsoft.com/en-us/dotnet/standard/library-guidance/sourcelink)
    - [Producing Packages with Source Link by Claire Novotny](https://devblogs.microsoft.com/dotnet/producing-packages-with-source-link/)
    - [Publish Source Link NuGet Packages with Azure Pipelines](https://christianfindlay.com/2020/12/25/source-link-nuget-azure-pipelines/)
    - [Newtonsofy json](https://github.com/JamesNK/Newtonsoft.Json/pull/1746)


### Nuget packaging with dependencies
1. Using `.csproj` file with additional metadata
- If you want to pack a library with its project dependencies, you can utilize the approach described [here](https://github.com/NuGet/Home/issues/3891#issuecomment-377319939). This will pack the project references assemblies under the `lib` directory of nuget package.
> However, if the corresponding project references has package dependencies, they are not transitively referred within the nuspec file. Therefore, those PackageReferences should be specified again in the csproj file.

- Another issue with this approach is that if you have a test or console app project refer to this packaged library, due to ` PrivateAssets="all"` metadata, the compilation will fail.
> Solution: Explicitly restate to be packaged project's `ProjectReference`s within the consumers csproj file.

- References:
    - [https://github.com/NuGet/Home/issues/14259](https://github.com/NuGet/Home/issues/14259)
    - [Advanced extension points to create customized package](https://github.com/NuGet/docs.microsoft.com-nuget/blob/main/docs/reference/msbuild-targets.md#advanced-extension-points-to-create-customized-package)
    - [Controlling dependency assets](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#controlling-dependency-assets)

2. Utilizing `.nuspec` file within the same directory of the csproj file.

- References:
    - [Github/dasMulli/nuget-include-p2p-example](https://github.com/dasMulli/nuget-include-p2p-example)

3. Mimic `.nuspec` with another and additional `.csproj` file to be used for `dotnet pack` cli