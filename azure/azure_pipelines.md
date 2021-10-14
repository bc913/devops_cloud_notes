# Azure Pipelines

## Script tasks
### Powershell
- [PowerShell task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/powershell?view=azure-devops)
- [Another one](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/powershell?view=azure-devops&tabs=yaml)

You can run Powershell tasks in various ways:
```yaml
# Option 1:
# Run a PowerShell script on Linux, macOS, or Windows
- task: PowerShell@2
  inputs:
    #targetType: 'filePath' # Optional. Options: filePath, inline
    #filePath: # Required when targetType == FilePath
    #arguments: # Optional
    #script: '# Write your PowerShell commands here.Write-Host Hello World' # Required when targetType == Inline
    #errorActionPreference: 'stop' # Optional. Options: stop, continue, silentlyContinue
    #failOnStderr: false # Optional
    #ignoreLASTEXITCODE: false # Optional
    #pwsh: false # Optional
    #workingDirectory: # Optional

# Shortcuts
# Option 2:
# for Windows PowerShell
- powershell:  # inline script or file path (.\my-script.ps1)
  workingDirectory:  #
  displayName:  #
  failOnStderr:  #
  errorActionPreference:  #
  ignoreLASTEXITCODE:  #
  env:  # mapping of environment variables to add

# Option 3:
# for PowerShell Core
- pwsh:  # inline script of file path (i.e. ./my-script.ps1)
  workingDirectory:  #
  displayName:  #
  failOnStderr:  #
  errorActionPreference:  #
  ignoreLASTEXITCODE:  #
  env:  # mapping of environment variables to add

```
> Both of these (Options 2 & 3) resolve to the `PowerShell@2` task. `powershell` (Option 2) runs Windows PowerShell and will only work on a Windows agent. `pwsh` (Option 3) runs PowerShell Core, which must be installed on the agent or container.

### Bash
- [Bash task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/bash?view=azure-devops)
- [Cross-platform scripts](https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/cross-platform-scripting?view=azure-devops&tabs=yaml#consider-bash-or-pwsh)

```yaml
# Option 1:
# Run a Bash script on macOS, Linux, or Windows
- task: Bash@3
  inputs:
    #targetType: 'filePath' # Optional. Options: filePath, inline
    #filePath: # Required when targetType == FilePath
    #arguments: # Optional
    #script: '# echo Hello world' # Required when targetType == inline
    #workingDirectory: # Optional
    #failOnStderr: false # Optional
    #noProfile: true # Optional
    #noRc: true # Optional

# Option 2 (Shortcut for the Option 1)
- bash: # inline or file path
  workingDirectory: #
  displayName: #
  failOnStderr: #
  env:  # mapping of environment variables to add
```

Inline bash script also yields to:
```yaml
# Single line
steps:
- script: echo $MYSECRET
  env:
    MYSECRET: $(Foo)
# Multiple line
steps:
- script: |
    echo $MYSECRET
    echo "Hello Azure"
  env:
    MYSECRET: $(Foo)
```

### Misc
- One can use `|` to run multiple lined inline script.

## Variables
- [Predefined variables](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml)
- [User defined variables](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch)

### Scope
User-defined variables can be defined and used at the same job, stage or pipeline(global) [scope](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#variable-scopes).

In order to share variable between different tasks, jobs or stages, the variables should be marked as `output` variable using `isoutput` syntax. Please refer to [this](#Define/Use/Share-output-variables-between-tasks/jobs/steps/stages) section for details.

### Access variables from script tasks
Let's assume the following user-defined variables are available:

```yaml
variables:
  isDevelopBranch: $[eq(variables['Build.SourceBranch'], 'refs/heads/develop')]
  isMasterBranch: $[eq(variables['Build.SourceBranch'], 'refs/heads/master')]
  commitIdVar: $[variables['Build.SourceVersion']]
```
> NOTE: Boolean type Azure Pipeline variables are interpreted as `True` instead of `true` in Bash. I'm not sure if this behavior is consistent but please be aware and put some logging to diagnose if you encounter any error.

#### Inline
- Powershell
```yaml
# 1
# You can also use the same syntax for the shortcut versions
- task: PowerShell@2
  displayName: 'Inline Powershell'
  inputs:
    targetType: 'inline'
    script: |
      [string] $build_reason = "$(Build.Reason)"
      [string] $commitId = "$(commitIdVar)"
      $commitIdShort = $commitIdShort.substring(0, 7)
      Write-Host "commitId: $commitIdShort"
      [string] $version_suffix = ""
      if ( $env:isDevelopBranch -eq $true )
      {
          Write-Host 'This is develop branch.'
          $version_suffix = "dev"
      }
```
- Bash
```yaml
- task: Bash@3
    displayName: 'Inline Bash'
    inputs:
      targetType: 'inline'
      script: |
        echo "Hello world from $AGENT_NAME running on $AGENT_OS"
        myBuildReason=$BUILD_REASON
        commitId=$(commitIdVar)
        commitIdShort=$(echo $commitId | cut -c1-7)
        echo "commitId: $commitIdShort"
        version_suffix=""
        if [[ $(isDevelopBranch) == True ]] || [[ $(isDevelopBranch) == true ]]; then
            echo "This is develop branch"
            version_suffix+="dev"
        fi
```

#### File
- Powershell
```powershell
[CmdletBinding()]
param()

[string] $build_reason = "$env:Build_Reason"
[string] $commitIdShort = "$env:Build_SourceVersion"
$commitIdShort = $commitIdShort.substring(0, 7)
[string] $version_suffix = ""
if ( $env:isDevelopBranch -eq $true )
{
    Write-Host 'This is develop branch.'
    $version_suffix = "dev"
}
```
- Bash
```bash
#!/bin/bash
echo "Hello world from $AGENT_NAME running on $AGENT_OS"

myBuildReason=$BUILD_REASON
commitId=$BUILD_SOURCEVERSION
commitIdShort=$(echo $commitId | cut -c1-7)
version_suffix=""
if [[ $ISDEVELOPBRANCH == True ]]; then
    echo "This is develop branch"
    version_suffix+="dev"
fi
```

### Set Variables in scripts or script tasks
https://docs.microsoft.com/en-us/azure/devops/pipelines/process/set-variables-scripts?view=azure-devops&tabs=bash

### Define/Use/Share output variables between tasks/jobs/steps/stages
https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#use-output-variables-from-tasks

### Logging and Setting extra variables
https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=bash

https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=bash#setvariable-initialize-or-modify-the-value-of-a-variable


## Multi-staging
- https://www.mercuryworks.com/blog/creating-a-multi-stage-pipeline-in-azure-devops/
## References
https://adamtheautomator.com/powershell-pipeline/