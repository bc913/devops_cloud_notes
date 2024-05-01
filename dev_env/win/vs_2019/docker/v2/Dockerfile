# escape=`

# Use the latest Windows Server Core 2019 image.
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

# If there is a storage issue, remove unused windows10sdk components from installing
# https://learn.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019#troubleshoot-build-tools-containers
RUN `
    # Download the Build Tools bootstrapper.
    curl -SL --output vs_buildtools.exe https://aka.ms/vs/16/release/vs_buildtools.exe `
    && (start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
        --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools" `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.CoreBuildTools `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.VC.14.28.x86.x64 `
        --add Microsoft.VisualStudio.ComponentGroup.UWP.VC.BuildTools `
        --add Microsoft.VisualStudio.Component.Windows10SDK.16299 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.17134 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.17763 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.18362 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.19041 `
        || IF "%ERRORLEVEL%"=="3010" EXIT 0) `
    `
    # Optional Cleanup
    && (for /D %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do rmdir /S /Q "%i") `
    && (for %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do if not "%~nxi" == "vswhere.exe" del "%~i") `
    && powershell Remove-Item -Force -Recurse "%TEMP%\*" `
    && rmdir /S /Q "%ProgramData%\Package Cache" `
    # Cleanup
    && del /q vs_buildtools.exe


SHELL ["powershell", "-command"]
ENV chocolateyVersion="1.4.0"

RUN Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco install conan --version=1.55.0 --confirm; `
    choco install cmake --version=3.25.3 --installargs 'ADD_CMAKE_TO_PATH=System' --confirm; `
    choco install git.portable --version=2.31.1 --confirm;

# Conan
ENV CONAN_SYSREQUIRES_MODE=enabled
ENV CONAN_REVISIONS_ENABLED=1
ENV CONAN_NON_INTERACTIVE=1

# WORKDIR "C:\src"
    
# Define the entry point for the docker container.
# This entry point starts the developer command prompt and launches the PowerShell shell.
ENTRYPOINT ["C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]