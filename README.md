# Setup

TODO

# Deploy

`nixos apply`

# Layout

### Hosts

These are your hosts or computers that your configuration will apply to. For instance:

- desktop
- laptop
- steamdeck
- server1
- server2

### Variables

These are high level personalized or host specific variables. This is to easily set things like:

- username
- email
- timezone
- keyboard laybout
- monitors
- wallpaper

### Features

Features are reusable modules of config to use across hosts. This is so you can configure basic things like your preferred shell or browser to reuse on your laptop the same as your desktop. Some drivers you may reuse and others may need to be different depending on your hardware. The desktop config should stay seperate from base in case you want to create a server that doesn't need things like a browser or UI based tools.

---

# FUTURE TODO:

- disko for managing disk partitions
- impermanence for better reproducability
- secrets management
