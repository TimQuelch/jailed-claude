{
  description = "jailed claude";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.url = "github:cachix/git-hooks.nix";
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      jail-nix,
      llm-agents,
      pre-commit,
      ...
    }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
      forEachSystem = fn: nixpkgs.lib.genAttrs systems (system: fn (mkPkgs system));

      preCommit =
        # all src for check, empty for devShell
        pkgs: src:
        pre-commit.lib.${pkgs.stdenv.hostPlatform.system}.run {
          inherit src;
          hooks = {
            nixfmt.enable = true;
          };
        };

      pname = "jailed-claude";
      binName = "claude";
    in
    {
      lib.makeJailedClaude =
        {
          pkgs,
          extraPkgs ? [ ],
        }:
        let
          jail = jail-nix.lib.extend {
            inherit pkgs;
            # strip out the default and configure it all in the function the default base includes
            # mounting only the wrapped exes closure from the nix store, but it's much easier if we
            # just mount the entire store.
            basePermissions = combinators: [ ];
          };
        in
        (pkgs.callPackage (
          {
            bashInteractive,
            claude-code,
            coreutils,
            curl,
            diffutils,
            fd,
            file,
            findutils,
            gawkInteractive,
            git,
            gnugrep,
            gnused,
            gnutar,
            gzip,
            jq,
            less,
            nix,
            nodejs,
            ps,
            python3,
            ripgrep,
            tree,
            unzip,
            uv,
            wget,
            which,
            xz,
          }:
          (jail binName claude-code (
            with jail.combinators;
            [
              base # from default basePermisisons
              fake-passwd # from default basePermisisons
              (ro-bind "${coreutils}/bin/env" "/usr/bin/env") # some scripts rely on this
              network
              time-zone
              no-new-session
              mount-cwd
              (add-pkg-deps (
                [
                  bashInteractive
                  claude-code
                  coreutils
                  curl
                  diffutils
                  fd
                  file
                  findutils
                  gawkInteractive
                  git
                  gnugrep
                  gnused
                  gnutar
                  gzip
                  jq
                  less
                  nix
                  nodejs
                  ps
                  python3
                  ripgrep
                  tree
                  unzip
                  uv
                  wget
                  which
                  xz
                ]
                ++ extraPkgs
              ))

              # forward git user config, no other config is forwarded
              (add-runtime ''
                RUNTIME_ARGS+=(
                  --setenv GIT_CONFIG_COUNT 2
                  --setenv GIT_CONFIG_KEY_0 user.name
                  --setenv GIT_CONFIG_VALUE_0 "$(git config user.name)"
                  --setenv GIT_CONFIG_KEY_1 user.email
                  --setenv GIT_CONFIG_VALUE_1 "$(git config user.email)"
                )
              '')

              # ensure claude config exists before mounting
              (add-runtime ''
                mkdir -p ~/.claude
                [ -f ~/.claude.json ] || echo '{}' > ~/.claude.json
              '')

              # must set /nix/var/nix to ro manually because mounting the socket creates that dir as
              # rw. If this dir is rw then nix will attempt to use a local store instead of daemon
              # also execute the channel to populate the git config.
              (wrap-entry (entry: ''
                chmod -w /nix/var/nix || true
                ${entry}
              ''))
              (write-text "/etc/nix/nix.conf" "experimental-features = nix-command flakes")
            ]
            ++ (map (p: readwrite (noescape p)) [
              "~/.claude"
              "~/.claude.json"
            ])
            ++ (
              (map (p: try-readonly (noescape p)) [
                "/nix/store"
                "/nix/var/nix/daemon-socket/socket"
              ])
            )
          ))
        ) { });

      overlays.default = final: prev: {
        ${pname} = self.lib.makeJailedClaude {
          pkgs = final // {
            claude-code = llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-code;
          };
        };
      };

      packages = forEachSystem (pkgs: {
        default = pkgs.${pname};
      });

      checks = forEachSystem (pkgs: {
        pre-commit-check = preCommit pkgs ./.;
      });

      devShells = forEachSystem (
        pkgs:
        let
          inherit (preCommit pkgs builtins.emptyFile) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShell {
            inherit shellHook;
            packages = [ pkgs.${pname} ] ++ enabledPackages;
          };
        }
      );
    };
}
