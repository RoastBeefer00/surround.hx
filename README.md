# surround.hx

vim-surround (`ds`, `cs`, `ys`, `S`) for [helix-steel](https://github.com/mattwparas/helix).

## Requirements

- [helix-steel](https://github.com/mattwparas/helix) — the Steel-embedded fork of Helix
- [helix-vim-plugin](https://github.com/RoastBeefer00/helix-vim-plugin) — installed automatically as a dependency

## Installation

Install with [forge](https://github.com/mattwparas/forge):

```
forge install https://github.com/RoastBeefer00/surround.hx
```

Then add to your `~/.config/helix/init.scm`:

```scheme
(require "surround.hx/surround.scm")
(set-surround-keybindings!)
```

## Key bindings

### Normal mode

| Sequence | Action |
|---|---|
| `ds{char}` | Delete surrounding pair |
| `cs{old}{new}` | Change surrounding pair |
| `ysiw{char}` | Surround inner word |
| `ysiW{char}` | Surround inner WORD |
| `ysip{char}` | Surround inner paragraph |
| `ysaw{char}` | Surround around word |
| `ysaW{char}` | Surround around WORD |
| `ysap{char}` | Surround around paragraph |
| `ysi{{char}` | Surround inner `{}` block |
| `ysi({char}` | Surround inner `()` block |
| `ysi[{char}` | Surround inner `[]` block |
| `ysi"{char}` | Surround inner `""` block |
| `ysi'{char}` | Surround inner `''` block |
| `yse{char}` | Surround to end of word |
| `ys${char}` | Surround to end of line |

### Select mode

| Sequence | Action |
|---|---|
| `S{char}` | Surround visual selection |

### Supported surrounding characters

Any bracket pair — `(` `)`, `{` `}`, `[` `]`, `<` `>` — as well as `"`, `'`, and `` ` ``.
Either the open or close bracket can be used interchangeably (e.g. `ds(` and `ds)` both delete parentheses).
