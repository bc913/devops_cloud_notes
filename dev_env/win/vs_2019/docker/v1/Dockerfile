FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019

COPY ./.vsconfig ./VisualStudio.config ./


SHELL ["powershell", "-command"]
ENV chocolateyVersion="1.4.0"

RUN Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco install .\VisualStudio.config -y \
    choco install conan --version=1.55.0 --confirm; \
    choco install cmake --version=3.25.3 --installargs 'ADD_CMAKE_TO_PATH=System' --confirm; \
    choco install git.portable --version=2.31.1 --confirm;
    # choco install visualstudio2019professional --version=16.10.1.0 --package-parameters "--config C:\.vsconfig" --confirm;

# Conan
ENV CONAN_SYSREQUIRES_MODE=enabled
ENV CONAN_REVISIONS_ENABLED=1
ENV CONAN_NON_INTERACTIVE=1

# WORKDIR "C:\src"