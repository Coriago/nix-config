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