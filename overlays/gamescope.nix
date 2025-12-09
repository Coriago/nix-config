# Overlay to use gamescope from git master
# Fetch gamescope from GitHub master branch
final: prev: {
  gamescope = prev.gamescope.overrideAttrs (oldAttrs: {
    # Fetch gamescope from GitHub with the specific commit
    src = prev.fetchFromGitHub {
      owner = "ValveSoftware";
      repo = "gamescope";
      # rev = "f980684487ab1849d0f02d8952831725d0825541";
      rev = "9416ca9334da7ff707359e5f6aa65dcfff66aa01";
      fetchSubmodules = true;
      # hash = "sha256-VTeJO47cEFc9T89PMYEI0AaSJV1HUY8RWX5H5kVksx0=";
      hash = "sha256-bZXyNmhLG1ZcD9nNKG/BElp6I57GAwMSqAELu2IZnqA=";
    };
    version = "git-9416ca9";
  });
}
