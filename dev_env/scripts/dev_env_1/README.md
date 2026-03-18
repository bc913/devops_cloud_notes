# Developer Environment Setup

Cross-platform, configurable build environment for C/C++, .NET, CMake, Conan and NuGet.

| Platform | Script | Compiler |
|---|---|---|
| Ubuntu 20.04 / 22.04 / 24.04 | `setup.sh` | GCC / G++ |
| Rocky Linux 8 / 9 | `setup.sh` | GCC / G++ (via gcc-toolset) |
| macOS 13+ | `setup.sh` | Clang (Xcode CLT) + GCC (Homebrew) |
| Windows 10 / 11 / Server | `setup.ps1` | MSVC (VS Build Tools 2022) |

---

## Quick start

### Linux / macOS
```bash
# Clone / copy this repo, then:
sudo ./setup.sh

# Activate the environment (add to ~/.bashrc or CI pipeline)
source /opt/devenv/env.sh
```

### Windows (PowerShell as Administrator)
```powershell
.\setup.ps1

# Activate the environment (add to $PROFILE or CI pipeline step)
. C:\DevEnv\env.ps1
```

---

## File layout

```
devenv/
├── config.json     ← single source of truth for all versions
├── setup.sh        ← Linux + macOS installer
├── setup.ps1       ← Windows installer
└── README.md
```

After setup, the installation root looks like:

```
<prefix>/
├── dotnet/         ← .NET SDK (dotnet binary lives here)
├── cmake/          ← CMake installation
├── conan-venv/     ← Python venv containing Conan
├── nuget/          ← nuget.exe  (Windows) / nuget.exe + wrapper (Linux)
├── bin/            ← thin wrapper scripts
├── logs/           ← timestamped setup logs
├── env.sh          ← environment activation (Linux/macOS)
└── env.ps1         ← environment activation (Windows)
```

---

## Configuration

All versions live in `config.json` and are read at script startup.
You can also override any value with an environment variable — these take
highest precedence, useful in CI where you don't want to modify files.

```json
{
  "versions": {
    "git":        { "linux": "2.47.1", "windows": "2.47.1.2", "macos": "2.47.1" },
    "gcc":        { "version": "13", "rocky_toolset": "13" },
    "dotnet_sdk": "9.0.2",
    "cmake":      "3.25.3",
    "conan":      "2.10.2",
    "nuget":      "6.12.1",
    "python":     "3.12.8"
  },
  "install": {
    "prefix_linux":   "/opt/devenv",
    "prefix_macos":   "/usr/local/devenv",
    "prefix_windows": "C:\\DevEnv"
  },
  "components": {
    "git":    true,
    "gcc":    true,
    "dotnet": true,
    "cmake":  true,
    "conan":  true,
    "nuget":  true
  }
}
```

### Environment variable overrides

| Variable | Description |
|---|---|
| `DEVENV_PREFIX` | Override installation root |
| `GIT_VERSION` | Git version |
| `GCC_VERSION` | GCC major version (Linux) |
| `DOTNET_VERSION` | .NET SDK version |
| `CMAKE_VERSION` | CMake version |
| `CONAN_VERSION` | Conan version |
| `NUGET_VERSION` | NuGet CLI version |

---

## Options

### setup.sh
```
Usage: sudo ./setup.sh [OPTIONS]

  --prefix <dir>   Installation prefix (default: /opt/devenv)
  --skip-git       Skip Git
  --skip-gcc       Skip GCC/G++/GDB
  --skip-dotnet    Skip .NET SDK
  --skip-cmake     Skip CMake
  --skip-conan     Skip Conan
  --skip-nuget     Skip NuGet
  --dry-run        Print commands without executing
  -h, --help       Show help
```

### setup.ps1
```
Parameters:
  -Prefix <dir>    Installation prefix (default: C:\DevEnv)
  -SkipGit         Skip Git
  -SkipMsvc        Skip VS Build Tools / MSVC
  -SkipDotnet      Skip .NET SDK
  -SkipCMake       Skip CMake
  -SkipConan       Skip Conan
  -SkipNuget       Skip NuGet
  -DryRun          Print actions without executing
```

---

## Tool-specific notes

### .NET SDK
Only the **build SDK** (`--runtime dotnet`) is installed — no ASP.NET runtime or
web workloads. The `DOTNET_CLI_TELEMETRY_OPTOUT=1` and `DOTNET_NOLOGO=1` env
vars are set automatically, which is important for clean CI output.

### CMake
Downloaded directly from `cmake.org` as a pre-built binary archive so the exact
patch version (e.g. `3.25.3`) is guaranteed. The system package manager is not
used for CMake.

### Conan
Installed into an **isolated Python virtual environment** (`<prefix>/conan-venv`)
so it never conflicts with system Python packages.

### NuGet on Linux / macOS
`nuget.exe` is downloaded to `<prefix>/nuget/`. A shell wrapper at
`<prefix>/bin/nuget` runs it via **Mono** if available, or delegates to
`dotnet nuget` commands otherwise. For most CI scenarios `dotnet nuget` is
the recommended approach on non-Windows platforms.

### GCC on Rocky Linux
Rocky Linux 8/9 ships GCC via **gcc-toolset-N** packages (formerly
`devtoolset`). The script installs `gcc-toolset-${ROCKY_TOOLSET}` and writes
`/etc/profile.d/gcc-toolset.sh` to activate it for all login shells.  
In non-login shells (typical in CI), source the toolset manually:
```bash
source /opt/rh/gcc-toolset-13/enable
# or just source the devenv activation script:
source /opt/devenv/env.sh
```

### MSVC on Windows
The script installs **Visual Studio Build Tools 2022** with the
`VCTools` workload. No IDE is installed. The `env.ps1` activation script
uses `vswhere.exe` to locate the installation and calls
`Enter-VsDevShell` to configure the compiler environment (sets `CL`, `LINK`,
`LIB`, `INCLUDE`, etc.).

---

## CI / Cloud usage examples

### GitHub Actions (Ubuntu)
```yaml
- name: Set up DevEnv
  run: |
    sudo ./devenv/setup.sh
    echo "source /opt/devenv/env.sh" >> $GITHUB_ENV
    source /opt/devenv/env.sh
    echo "${DEVENV_PREFIX}/cmake/bin" >> $GITHUB_PATH
    echo "${DEVENV_PREFIX}/conan-venv/bin" >> $GITHUB_PATH
    echo "${DEVENV_PREFIX}/dotnet" >> $GITHUB_PATH
```

### GitHub Actions (Windows)
```yaml
- name: Set up DevEnv
  shell: pwsh
  run: |
    .\devenv\setup.ps1
    . C:\DevEnv\env.ps1
```

### Azure Pipelines
```yaml
- script: sudo ./devenv/setup.sh
  displayName: Install DevEnv (Linux)
  condition: eq(variables['Agent.OS'], 'Linux')

- powershell: .\devenv\setup.ps1
  displayName: Install DevEnv (Windows)
  condition: eq(variables['Agent.OS'], 'Windows_NT')
```

### Docker (Ubuntu base image)
```dockerfile
FROM ubuntu:22.04
COPY devenv/ /devenv/
RUN /devenv/setup.sh --skip-git   # git already in base, for example

# Bake the activation into the image
ENV PATH="/opt/devenv/cmake/bin:/opt/devenv/conan-venv/bin:/opt/devenv/dotnet:/opt/devenv/bin:${PATH}"
ENV DOTNET_ROOT=/opt/devenv/dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
```

---

## Upgrading a single tool

Override the version via env var without editing `config.json`:

```bash
# Upgrade CMake to a newer patch release
sudo CMAKE_VERSION=3.25.3 ./setup.sh --skip-git --skip-gcc --skip-dotnet \
                                     --skip-conan --skip-nuget

# Or on Windows
$env:CMAKE_VERSION = "3.25.3"
.\setup.ps1 -SkipGit -SkipMsvc -SkipDotnet -SkipConan -SkipNuget
```

---

## Requirements

| Platform | Requirements |
|---|---|
| Ubuntu | `curl`, `python3` (auto-installed by script) |
| Rocky Linux | `curl`, `python3`, EPEL (auto-enabled) |
| macOS | Homebrew (auto-installed if missing), internet access |
| Windows | PowerShell 5.1+, internet access, run as Administrator |
