{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "comment-checker";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "go-claude-code-comment-checker";
    rev = "v${version}";
    hash = "sha256-RyZlVPJ+G3Vvt5Mhja7mxSe8bd+BfsYqbbrfqjjCbYE=";
  };

  vendorHash = "sha256-IRsAfaVp6bI159C+bCWfe0GM/uXiL2SjzseDUO6U1pQ=";

  subPackages = ["cmd/comment-checker"];

  preBuild = ''
    tsdir=vendor/github.com/smacker/go-tree-sitter
    if [ -d "$tsdir" ]; then
      chmod -R u+w "$tsdir"
      if [ ! -e "$tsdir/tree_sitter" ]; then
        ln -s . "$tsdir/tree_sitter"
      fi
      for lang in "$tsdir"/*/; do
        if [ -d "$lang" ] && [ ! -e "''${lang}tree_sitter" ]; then
          ln -s .. "''${lang}tree_sitter"
        fi
      done
    fi
  '';

  meta = {
    description = "Multi-language comment detection hook for Claude Code/OpenCode";
    homepage = "https://github.com/code-yeongyu/go-claude-code-comment-checker";
    license = lib.licenses.mit;
    mainProgram = "comment-checker";
  };
}
