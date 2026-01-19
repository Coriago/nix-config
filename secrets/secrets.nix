let
  # Master key (your personal age key)
  # master = "age1z6h46h4vqeayqete44sm9sqx0vt8d4fg2mnfck7svfvssgnu3f2qeh8n2u";
  # Host SSH public keys
  heliosdesk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAz7gDRD7wKds16rl9PPW0HKY3C3CWJbELtUfkXNIwAu";
  rpiserver1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOshmG6Skkup8Y2xWNWuZSx5V3YCNla6H78ZX4a2OSjK";

  hosts = [heliosdesk rpiserver1];
in {
  "k3s.age".publicKeys = hosts;
}
