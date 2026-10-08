# Portable
Running customized personal nix apps on other machines could disrupt machines directories or not work as expected.
Solution is wrapper modules that encapsulate the application bundling in dependencies and config.

# Mutable
The wrapper app is customized and portable but experience is degraded since the configuration is immutable 
while in the nix store. Solution is to use the syncer which inserts the configuration
into a mutable runtime directory.

# Drift
You can now make changes while in the app to your liking but your declarative drifts 
behind the ideal state in the runtime. It is tedious to set these settings again but in 
the declarative workflow. Copying the entire runtime config is not desirable since it could 
contains state, secrets, host specific settings or settings you simply do not want to track. 
Solution is the snapshotter that selectively extracts runtime configuration and saves it 
with your declarative config.

Portable and Mutable : wrapper package + syncer
Portable and not Mutable : wrapper package
Not Portable and Mutable : repo symlinks*
Not Portable and not Mutable: home manager


Note: If the syncer points to an existing runtime dir or default dir, it may be less portable.

# Syncer

Role: copy configuration from the nix store into a runtime location

Inputs:
trigger - on-init, on-start, never 
sync_store_config - map of nix store files to parse/copy to runtime locations

Behavior:
-destination and source files are parsed/formatted based on file type suffix.
-if destination format is unknown or not a data file, raw content of the first store path is used.
-if destination format is a data format, store paths will be parsed and merged together. if a source file is not data or can't be parsed then that file is skipped. If all source files were skipped, the destination is not created.
-if replace_dst_file is true, the dst file will not be parsed and simply overwritten by the parsed source.


### sync_store_config

"xdg-home/.config/app/config.toml": {
			store_paths: [ "/nix/store/.../config.toml"]
			create_dst_file: true # if the file should be created if it does not exist
			replace_dst_file: false # if the file should be fully replaced
			parsed_append: true # parsed key/value from source added to dst if not in dst
			parsed_replace: true # parsed key/value from source replaces dst key/value when it is set
			parsed_list_behavior: replace # When a list is encountered in dst, option to append, skip or replace. append skips if obj already in list
			override_dst_file_format: null # override to explicitly set format if it can't be detected from file suffix
			sort: false # sort data files or try and preserve existing order/whitespace. 
}
"xdg-home/.config/app/extras": {
			store_paths: [ "/nix/store/.../ext.toml"]
			create_dst_file: true
			replace_dst_file: true 
			parsed_append: false
			parsed_replace: false
			override_dst_file_format: "json"
}

# Snapshotter

Role: parse runtime config and create a filtered snapshot to save.

Inputs:
snapshot_config - where to find config and prune it into a snapshot

Behavior:
- prune_key_contains will remove any config that has the regex expression inside of its full key path: "general.user.0.password"
- prune_value_contains will remove any entry with a value matching the regex expression: "display = hdmi" or "general.out = hdmi2"
-prune_expressions are jq expressions when more advanced usage is needed. this is done after the contains prunes have walked the config.

### snapshot_config

"/home/user/.config/nix-config/snapshot/app/config.toml": {
			config_paths: [ "xdg-home/.config/app/config.toml" "/nix/store/.../config.toml"]
			prune_key_contains: [
				"password"
				"duck[1-9]+"
			]
			prune_value_contains: [
				"hdmi"
			]
			prune_expressions: [
				'.meta.login'
				'path(.. | .password? // empty)'
				'.servers[] | select(.role == "backend")'
			]
}	



# When should liveconfig symlinks be used? 
- The config is a separate file in the repo outside of nix
- The config does not use any values from nix eval time, or the app supports injecting the nix vars or the app supports separating the nix vars in a separate file. 
- running on your local machine only, not when running as a portable package. 

So neovim would be a good candidate since it is owned and modified in the repo, has seperate lua files and injects the nix values. It is also an app that the workflow modifications isduring local development, not when it is portable.



