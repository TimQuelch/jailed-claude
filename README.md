# jailed-claude

Claude Code and other agents are essentially untrusted remote code execution vulnerabilities that run in your user context. My user usually has access to SSH keys, AWS credentials, and client code and data. It is unacceptable that these be exposed to agents which are executing untrusted code and have access to the internet. While Claude Code comes with sandboxing features, I don't particularly trust it to do the right thing.

jailed-claude lets you run [Claude Code](https://claude.ai/code) inside a [bubblewrap](https://github.com/containers/bubblewrap) sandbox using [jail.nix](https://git.sr.ht/~alexdavid/jail.nix) and Nix Flakes. Heavily inspired by [jailed-agents](https://github.com/andersonjoseph/jailed-agents) and the accompanying [article by Anderson Joseph](https://dev.to/andersonjoseph/how-i-run-llm-agents-in-a-secure-nix-sandbox-1899).

The sandbox starts with no permissions and explicitly grants only what Claude Code needs: network access, the current working directory (read-write), basic config files, basic CLI tools, and read-only access to `/nix/store` and the nix daemon socket (if present).

## Usage

Run directly:

```sh
nix run github:timquelch/jailed-claude
```

Or add the package to a devenv or nixos packages, add the overlays to nixpkgs config, or build a custom package with the `lib.makeJailedClaude` function.

The `claude-code` package defaults to the version pinned by the [llm-agents.nix](https://github.com/numtide/llm-agents.nix) input. To use a different version, include your own `claude-code` in the overlay set or override the package with something like `jailed-claude.override { claude-code = my-specific-version }`.

## What's in the sandbox

- **Current working directory** mounted read-write
- **CLI tools**: Just the basics, but additional packages can be configured with the lib function
- **Minimal git config** (user.name/email) forwarded from the host
- **Minimal Nix config** jail has read access to nix store and access to the daemon socket if the host would usually allow it

Everything else is denied by default.

## Development

```sh
nix develop   # or use direnv
nix build     # build the package
nix flake check  # run checks (nixfmt)
```
