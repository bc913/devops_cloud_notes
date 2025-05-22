Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));
choco install cmake --version=3.25.3 --installargs 'ADD_CMAKE_TO_PATH=System' --confirm;
choco install git.portable --version=2.49.0 --confirm;
#choco install conan --version=1.55.0 --confirm;