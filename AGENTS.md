# NixOS Configuration - Agent Guidelines

**NOTE:** This configuration is actively evolving. Current patterns and structures are subject to change as the system matures. What exists now reflects practical decisions made during development, not necessarily final design goals.

## Repository Overview

This is a flake-based NixOS configuration using `flake-parts` for modular organization. The config manages multiple hosts (desktop, Raspberry Pi servers) with shared feature modules.

**Key Directories:**
- `modules/hosts/` - Per-host configurations (heliosdesk, rpiserver1)
- `modules/features/` - Reusable feature modules (base, desktop, drivers, gaming, self-hosting)
- `modules/variables/` - Centralized variable definitions and monitor configs
- `scripts/` - Deployment and management scripts
- `secrets/` - Age-encrypted secrets (agenix)

**Architecture:** The flake uses `import-tree` to recursively import modules. Configuration is split between NixOS system config and Home Manager for per-user settings.

## Build/Deploy/Test Commands

### Primary Workflow
```bash
# Apply configuration changes (user always does this manually for final approval)
nixos apply

# Alternative: Traditional rebuild
sudo nixos-rebuild switch --flake .#heliosdesk

# Build without switching (test)
nom build .#nixosConfigurations.heliosdesk.config.system.build.toplevel

# Check what will change before applying
nixos build
```

### Raspberry Pi Management
```bash
# Build RPI SD card image
make build-rpi-image

# List available disks before writing
make list-disks

# Write image to SD card
make write-sd DEVICE=/dev/sdX

# Deploy fresh install
make deploy-fresh

# Deploy updates to running system
make deploy-update

# Swap boot priority
make swap-boot
```

### Code Quality Tools
```bash
# Format all Nix files (alejandra)
alejandra .

# Lint Nix files for anti-patterns
statix check

# Compare system generations
nvd diff /run/current-system result

# Check flake structure
nix flake check

# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
```

### Development Environment
```bash
# Enter devshell (via direnv - automatic with .envrc)
direnv allow

# Manual devshell entry
nix develop
```

The devshell includes: `age`, `disko`, `agenix`

## Code Style & Patterns

### File Organization Philosophy

**IMPORTANT:** Prefer fewer, larger files over excessive fragmentation. Don't split modules unnecessarily. Favor simplicity and clarity over DRY principles - it's acceptable to repeat patterns 1-2 times rather than create complex abstractions.

**Good:** A single comprehensive module file with related functionality
**Avoid:** Splitting every small feature into its own file when grouping makes sense

### Module Structure

All modules use the flake-parts module system with clear namespacing:

```nix
{
  # For generic/variable modules
  flake.modules.generic.moduleName = { ... };
  
  # For NixOS system modules
  flake.modules.nixos.moduleName = { pkgs, config, ... }: { ... };
  
  # For Home Manager modules
  flake.modules.homeManager.moduleName = { pkgs, config, ... }: { ... };
}
```

### Feature Module Patterns

**CRITICAL:** Understand these patterns when adding new feature modules:

#### Pattern 1: Combined Feature Modules (base/, desktop/, gaming/, self-hosting/)

Files in these directories export **both** NixOS and Home Manager config under a **single shared namespace**:

```nix
# modules/features/desktop/apps.nix
{
  # NixOS config goes here
  flake.modules.nixos.desktop = { pkgs, config, ... }: {
    programs.usbtop.enable = true;
    virtualisation.docker.enable = true;
  };

  # Home Manager config goes here (same "desktop" namespace)
  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = with pkgs; [ vlc discord ];
    programs.vscode.enable = true;
  };
}
```

**Key Points:**
- Multiple files can contribute to the same namespace (e.g., `desktop.nix` and `apps.nix` both use `desktop`)
- Both NixOS and Home Manager sections are optional - include what's needed
- This allows grouping related functionality while keeping files organized

#### Pattern 2: Individual Driver Modules (drivers/)

Each driver file exports its **own unique namespace**:

```nix
# modules/features/drivers/audio.nix
{
  flake.modules.nixos.audio = {
    services.pipewire.enable = true;
    # ... audio config
  };
}

# modules/features/drivers/bluetooth.nix
{
  flake.modules.nixos.bluetooth = { pkgs, ... }: {
    hardware.bluetooth.enable = true;
    # ... bluetooth config
  };
}
```

**Key Points:**
- Each driver = separate module namespace
- Import individually: `nixos.audio`, `nixos.bluetooth`, `nixos.gpu`
- Drivers typically only need NixOS config (no Home Manager section)

### Host Configuration Pattern

Each host configuration follows this structure:

```nix
{
  inputs,
  config,
  ...
}: let
  hostname = "hostname-here";
  username = "username-here";
in {
  # 1. Variables module
  flake.modules.generic.${hostname} = {
    imports = with config.flake.modules; [generic.variables];
    vars = { ... };
  };

  # 2. NixOS configuration
  flake.modules.nixos.${hostname} = { ... }: {
    imports = with config.flake.modules; [
      generic.${hostname}
      nixos.base
      nixos.desktop
      nixos.gaming
      
      # Drivers (individual imports)
      nixos.bluetooth
      nixos.gpu
      nixos.audio
    ];
    
    home-manager.users.${username} = {
      imports = with config.flake.modules; [
        generic.${hostname}
        homeManager.base
        homeManager.desktop
      ];
    };
    # Host-specific overrides here
  };

  # 3. Final configuration
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [config.flake.modules.nixos.${hostname}];
  };
}
```

### Imports & Dependencies

Use `with config.flake.modules` for importing modules:

```nix
imports = with config.flake.modules; [
  generic.hostname
  nixos.base
  nixos.desktop
  homeManager.base
];
```

### Naming Conventions

- **File names:** kebab-case (`audio.nix`, `self-hosting.nix`)
- **Hostnames:** lowercase, no special chars (`heliosdesk`, `rpiserver1`)
- **Attribute names:** camelCase (`stateVersion`, `wallpaperHash`, `timeZone`)
- **Module namespaces:** Use dotted paths (`nixos.base`, `homeManager.desktop`)
- **Variables:** Access via `config.vars.variableName`

### Variable Usage

Access centralized variables through `config.vars`:

```nix
config.vars.username
config.vars.stateVersion
config.vars.timeZone
config.vars.email
```

Define new variables in `modules/variables/common.nix` using NixOS options.

### Code Formatting

- Use `alejandra` for formatting (configured in devshell)
- 2-space indentation (standard Nix style)
- Use `let...in` for local bindings (especially hostname/username)
- Keep attribute sets organized and readable
- Add comments for non-obvious configuration choices

## Secrets Management

**STATUS:** Currently evolving - improvements needed.

Uses `agenix` for age-encrypted secrets. Secrets are stored in `secrets/` directory.

```nix
# In configuration
age.secrets.secretName.file = ./path/to/secret.age;

# Access in config
config.age.secrets.secretName.path
```

**TODO:** This area needs refinement. Current implementation is functional but may not reflect final design.

## Common Patterns

### Adding a New Host

1. Create `modules/hosts/new-hostname/configuration.nix`
2. Define hostname, username, and vars
3. Import appropriate feature modules
4. Add host-specific overrides
5. Build: `nom build .#nixosConfigurations.new-hostname.config.system.build.toplevel`

### Adding a New Feature Module

**For base/, desktop/, gaming/, self-hosting/ directories:**

1. Create file in appropriate directory (e.g., `modules/features/desktop/newfeature.nix`)
2. Export NixOS config under the parent namespace:
   ```nix
   flake.modules.nixos.desktop = { ... }: { /* config */ };
   ```
3. Optionally export Home Manager config under same namespace:
   ```nix
   flake.modules.homeManager.desktop = { ... }: { /* config */ };
   ```
4. Import in host using existing namespace: `nixos.desktop`, `homeManager.desktop`

**For drivers/ directory:**

1. Create file: `modules/features/drivers/newdriver.nix`
2. Export with unique namespace:
   ```nix
   flake.modules.nixos.newdriver = { ... }: { /* config */ };
   ```
3. Import in host individually: `nixos.newdriver`

### Testing Changes

1. Make changes to configuration
2. Run `alejandra .` to format
3. Run `statix check` to lint
4. Build: `nom build .#nixosConfigurations.HOSTNAME.config.system.build.toplevel`
5. When ready: `nixos apply` (user approval required)

## Development Workflow

**Critical:** The user always runs `nixos apply` manually to activate changes. This provides final approval before system changes take effect. Never automatically apply or switch generations without explicit user instruction.

1. Modify configuration files
2. Format and lint code
3. Test build
4. Inform user changes are ready
5. User runs `nixos apply` when ready

## Notes for AI Agents

- **Simplicity over DRY:** Prefer simple, clear code even if slightly repetitive
- **File consolidation:** Don't over-modularize - group related functionality
- **Namespace awareness:** Understand the difference between combined feature modules and individual driver modules
- **No automatic deploys:** Never run `nixos apply` or deployment commands automatically
- **Evolution in progress:** Current patterns may change - don't treat them as immutable
- **User approval:** Always get confirmation before significant structural changes
