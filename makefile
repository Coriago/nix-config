.PHONY: build-rpi-image
build-rpi-image:
	nom build .#nixosConfigurations.rpi5-installer.config.system.build.sdImage