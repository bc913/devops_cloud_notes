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