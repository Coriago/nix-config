.PHONY: build-rpi-image
build-rpi-image:
	nom build .#nixosConfigurations.rpi5-installer-sd-card.config.system.build.sdImage

.PHONY: list-disks
list-disks:
	@echo "Available block devices:"
	@lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
	@echo ""
	@echo "Use 'make write-sd DEVICE=/dev/sdX' to write the image"

.PHONY: write-sd
write-sd:
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE not specified"; \
		echo "Usage: make write-sd DEVICE=/dev/sdX"; \
		echo "Run 'make list-disks' to see available devices"; \
		exit 1; \
	fi
	@if [ ! -e "$(DEVICE)" ]; then \
		echo "Error: Device $(DEVICE) does not exist"; \
		exit 1; \
	fi
	@echo "WARNING: This will overwrite all data on $(DEVICE)"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@IMAGE=$$(find result/sd-image -name "*.img" -o -name "*.img.zst" | head -n1); \
	if [ -z "$$IMAGE" ]; then \
		echo "Error: No image found in result/sd-image/"; \
		exit 1; \
	fi; \
	echo "Writing $$IMAGE to $(DEVICE)..."; \
	if echo "$$IMAGE" | grep -q ".zst$$"; then \
		echo "Decompressing and writing zstd image..."; \
		sudo zstd -dc "$$IMAGE" | sudo dd bs=4M conv=fsync oflag=direct status=progress of=$(DEVICE); \
	else \
		sudo dd bs=4M conv=fsync oflag=direct status=progress if="$$IMAGE" of=$(DEVICE); \
	fi; \
	echo "Syncing..."; \
	sudo sync; \
	echo "Done! SD card is ready."

DEVICE_CONFIG = rpiserver3
DEVICE_IP = $(shell nix eval .#nixosConfigurations.$(DEVICE_CONFIG).config.vars.local_ip --raw)

.PHONY: deploy-fresh
deploy-fresh:
	nix run github:nix-community/nixos-anywhere -- --flake .#$(DEVICE_CONFIG) --target-host root@$(DEVICE_IP) --copy-host-keys
	sleep 5
	$(MAKE) swap-boot
	ssh-keygen -R $(DEVICE_IP)
	

deploy-rebuild:
	nixos apply .#$(DEVICE_CONFIG) --target-host root@$(DEVICE_IP)

deploy-rebuild-switch:
	nixos-rebuild switch --flake .#$(DEVICE_CONFIG) --target-host root@$(DEVICE_IP)

swap-boot:
	./scripts/rpi-boot-priority.sh root@$(DEVICE_IP)

create-primary-key:
	mkdir -p ~/.config/sops/age
	nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_rsa > ~/.config/sops/age/keys.txt

get-primary-pub-key:
	nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt

get-host-pub-key:
	nix-shell -p ssh-to-age --run 'ssh-keyscan -t ed25519 $(DEVICE_IP) | ssh-to-age'


update-flake:
	nix flake update --override-input nixpkgs github:NixOS/nixpkgs/$(shell curl -s https://status.nixos.org | jq -r '.data.result[] | select(.metric.channel=="nixos-unstable") | .metric.revision'