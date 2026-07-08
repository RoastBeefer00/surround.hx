# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`surround.hx` is a [helix-steel](https://github.com/mattwparas/helix) plugin that brings vim-surround (`ds`, `cs`, `ys`, `S`) to Helix. It is written in Steel (a Scheme dialect embedded in Helix) and distributed as a Steel package via `cog.scm`.

The plugin depends on [`helix-vim-plugin`](https://github.com/RoastBeefer00/helix-vim-plugin), which provides the shared utilities it imports (`../vim/utils.scm`, `../vim/visual-motions.scm`). These paths resolve relative to the plugin's installed location (`~/.config/helix/surround.hx/`), so `../vim/` points at `~/.config/helix/vim/`.

## Package metadata

`cog.scm` is the Steel package manifest (analogous to `Cargo.toml`). It declares the package name, version, and dependencies. Update it when bumping the version or adding Steel package dependencies.

## Dev environment

The project uses [devenv](https://devenv.sh) (Nix-based). Enter the shell with:

```
devenv shell
```

This provides `git`, `vhs`, and `ttyd`, and exposes a `record` script.

## Recording the demo

```
record
```

This runs `vhs demo/surround.tape` from the `demo/` directory and outputs `demo/surround.gif`. Requires `hx` (helix-steel) to be on `PATH`.

## Architecture

`surround.scm` is the single source file. It is structured in layers:

1. **Char pair mapping** — `surround-open-char` / `surround-close-char` normalize any bracket/quote variant to its canonical open/close form.
2. **Pair search** — `find-surround-pair` dispatches to `find-bracket-pair` (from `vim/utils.scm`) for bracket pairs and `find-quote-pair` for quote pairs, returning `(open-pos . close-pos)` or `#f`.
3. **Operations** — `vim-surround-delete`, `vim-surround-change`, and `vim-surround-visual` implement `ds`, `cs`, and `S` respectively. Each uses `on-key-callback` to consume the next keypress(es) from the Helix event loop.
4. **Motion wrappers** — `vim-surround-add-with-motion` and the `vim-surround-add-*` family implement `ys{motion}` by switching to select mode, running the motion function (from `vim/visual-motions.scm`), then calling `vim-surround-visual`.
5. **Keybindings** — `surround-keybindings` declares the full keymap; `set-surround-keybindings!` registers it via `add-global-keybinding`.

All public symbols are listed in the `(provide ...)` form at the bottom of the file.

## Key bindings exposed

| Key sequence | Action |
|---|---|
| `ds{char}` | Delete surrounding pair |
| `cs{old}{new}` | Change surrounding pair |
| `ys{motion}{char}` | Add surrounding pair via motion |
| `S{char}` (select mode) | Surround visual selection |
