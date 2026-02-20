# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

jailed-claude creates a sandboxed environment for running Claude Code using Nix and the jail.nix framework (bubblewrap-based). It provides a `makeJailedClaude` library function, a Nix overlay, and a default package.

## Build System

Nix Flakes. Key commands:

- `nix build` — build the jailed-claude package
- `nix flake check` — run checks (pre-commit hooks including nixfmt)
- `nix develop` — enter dev shell (also activated automatically via direnv/.envrc)

No test suite exists. The only automated check is `nixfmt` via pre-commit hooks.

## Architecture

All code lives in `flake.nix`. Three main outputs:

1. **`lib.makeJailedClaude`** — Takes `{ pkgs, extraPkgs ? [] }`, returns a jailed package. Uses `jail-nix.lib.extend` (with empty `basePermissions`) to create a jail around `claude-code` with combinators for network access, timezone, CWD mounting, bundled CLI tools (bash, curl, fd, git, jq, nix, ripgrep, wget, etc.), git author forwarding, a nix.conf enabling `nix-command flakes`, read-write access to `~/.claude` and `~/.claude.json`, and read-only access to `/nix/store` and the nix daemon socket.

2. **`overlays.default`** — Nix overlay exposing `jailed-claude` in pkgs. The `claude-code` dependency defaults to the version pinned in the `llm-agents` input but can be overridden by including a `claude-code` package in the consuming overlay set.

3. **`packages.default` / `devShells.default`** — Standard flake outputs for building and developing.

## Key Dependencies

- `jail-nix` (sourcehut:~alexdavid/jail.nix) — sandboxing framework
- `llm-agents` (github:numtide/llm-agents.nix) — provides `claude-code` package
- `pre-commit` (github:cachix/git-hooks.nix) — nixfmt hook

## Formatting

All Nix code must pass `nixfmt`. This is enforced by pre-commit hooks.
