# surround.hx demo
# Requirements: helix-steel with vim plugin + surround.hx loaded and set-surround-keybindings! called
# Run from this directory: vhs surround.tape

Output surround.gif

Set Shell "fish"
Set FontSize 14
Set Width 1000
Set Height 585
Set Theme "Catppuccin Mocha"
Set TypingSpeed 80ms

# Open helix with the sample file
Type "cd demo && hx sample.txt"
Enter
Sleep 2s

# ── ds" : delete surrounding quotes ─────────────────────────────────────────
# line 1: let greeting = "hello"
# f" jumps to the opening quote, l steps inside
Type "f\""
Sleep 300ms
Type "l"
Sleep 300ms
Type "ds"
Sleep 150ms
Type "\""
Sleep 1s
Type "u"
Sleep 500ms

# ── cs[( : change surrounding brackets to parens ────────────────────────────
# line 2: let items = [one, two, three]
Type "j"
Sleep 200ms
Type "f["
Sleep 300ms
Type "l"
Sleep 300ms
Type "cs"
Sleep 150ms
Type "["
Sleep 150ms
Type "("
Sleep 1s
Type "u"
Sleep 500ms

# ── ysiw( : surround inner word with parens ──────────────────────────────────
# line 3: return value — move to "value"
Type "j"
Sleep 200ms
Type "0"
Sleep 200ms
Type "w"
Sleep 300ms
Type "ysiw"
Sleep 150ms
Type "("
Sleep 1s
Type "u"
Sleep 500ms

# ── S" : surround visual selection with quotes ───────────────────────────────
# line 4: let message = hello, world
# fh lands on 'h' of 'hello', then v$ selects to end of line
Type "j"
Sleep 200ms
Type "fh"
Sleep 300ms
Type "v"
Sleep 200ms
Type "$"
Sleep 500ms
Type "S"
Sleep 150ms
Type "\""
Sleep 1s
Type "u"
Sleep 500ms

# ── dst : delete surrounding HTML tag ───────────────────────────────────────
# line 5: <div>some content here</div>  →  some content here
Type "j"
Sleep 200ms
Type "0"
Sleep 300ms
Type "dst"
Sleep 1500ms
Type "u"
Sleep 500ms

# ── cst : change surrounding HTML tag name ───────────────────────────────────
# line 6: <span>styled text</span>  →  <strong>styled text</strong>
# cursor anywhere inside the element; cst opens a prompt pre-filled with current name
Type "j"
Sleep 200ms
Type "0"
Sleep 300ms
Type "cst"
Sleep 700ms
Type "strong"
Enter
Sleep 1500ms

# ── St : wrap visual selection in an HTML tag ────────────────────────────────
# line 7: click here  →  <a>click here</a>
# v$ selects to end of line, S reads the next key (t = tag), prompt opens
Type "j"
Sleep 200ms
Type "0"
Sleep 200ms
Type "v"
Sleep 150ms
Type "$"
Sleep 300ms
Type "S"
Sleep 150ms
Type "t"
Sleep 700ms
Type "a"
Enter
Sleep 1500ms

Type ":q!"
Enter
