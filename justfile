# List available commands.
default:
    @just --list

# Capture preferences for installed programs.
snapshot:
    snapshot-all

# Capture first; apply only if every selected snapshot succeeds.
apply: snapshot
    nixos apply "path:$PWD"
