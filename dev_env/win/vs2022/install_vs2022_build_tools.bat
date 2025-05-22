@echo off
REM Install Visual Studio 2019 Build Tools for C/C++ development

REM Download Visual Studio 2019 Build Tools Installer
curl -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe

REM Install Visual Studio 2019 Build Tools with C++ and Windows SDK
vs_buildtools.exe ^
  --quiet --wait --norestart --nocache ^
  --installPath "C:\BuildTools" ^
  --add Microsoft.VisualStudio.Workload.VCTools ^
  --add Microsoft.VisualStudio.Component.CoreBuildTools ^
  --add Microsoft.VisualStudio.Component.VC.CoreBuildTools ^
  --add Microsoft.VisualStudio.Component.TestTools.BuildTools ^
  --add Microsoft.VisualStudio.Component.VC.ASAN ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.18362 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.19041 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.20348 ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22000 ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.26100 ^
  --add Microsoft.VisualStudio.Component.VC.TestAdapterForBoostTest ^
  --add Microsoft.VisualStudio.Component.VC.TestAdapterForGoogleTest ^
  --add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64 ^
  --add Microsoft.VisualStudio.ComponentGroup.UWP.VC.BuildTools

REM Wait for the installation to complete
echo Installation complete. You can now use Visual Studio 2022 Build Tools.
pause
