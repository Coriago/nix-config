# Hosts

# Detail

The configuration.nix file contains the primary config for the host. The hardware-configuration.nix file is simply for storing generated config for your system. Configuration has 3 sections.

There is a generic module for variables `modules.generic.<HOSTNAME>` for reuse into other modules.

A nixos module `flake.modules.nixos.<HOSTNAME>` for your main nixos config. This module is used to import desired features for the host. These act as quick toggles for the high level config. For isntance: a headless server probably needs base and some drivers but probably doesn't need desktop features. It also can be used to add system overrides at the bottom for the host.

A nixos config `flake.nixosConfigurations.<HOSTNAME>` which sets up the final config output. This is simply the nixos module above.

# Instructions for adding more hosts

TODO
