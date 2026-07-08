(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/keymaps.scm")
(require "helix/components.scm")
(require "helix/treesitter.scm")

(require-builtin helix/core/text)

;; Import shared utilities from the vim plugin (forge-installed to ../vim.hx/).
(require "../vim.hx/utils.scm")
(require "../vim.hx/visual-motions.scm")

;;; ---- Char pair mapping ----

(define (surround-open-char char)
  (cond
    [(or (char=? char #\() (char=? char #\))) #\(]
    [(or (char=? char #\{) (char=? char #\})) #\{]
    [(or (char=? char #\[) (char=? char #\])) #\[]
    [(or (char=? char #\<) (char=? char #\>)) #\<]
    [else char]))

(define (surround-close-char char)
  (cond
    [(or (char=? char #\() (char=? char #\))) #\)]
    [(or (char=? char #\{) (char=? char #\})) #\}]
    [(or (char=? char #\[) (char=? char #\])) #\]]
    [(or (char=? char #\<) (char=? char #\>)) #\>]
    [else char]))

;;; ---- Pair search ----

;; Returns a sorted list of absolute char positions where `char` appears on `line-idx`.
(define (quote-positions-on-line rope char line-idx)
  (define line-start (rope-line->char rope line-idx))
  (define line-str (rope->string (rope->line rope line-idx)))
  (let loop ([i 0] [acc '()])
    (if (>= i (string-length line-str))
        (reverse acc)
        (loop (+ i 1)
              (if (char=? (string-ref line-str i) char)
                  (cons (+ line-start i) acc)
                  acc)))))

;; Given a sorted list of quote-char positions, returns (open-pos . close-pos)
;; for the pair surrounding cur-pos, or #f. Pairs are consecutive: (0,1), (2,3), ...
(define (find-quote-pair positions cur-pos)
  (let loop ([ps positions])
    (cond
      [(or (null? ps) (null? (cdr ps))) #f]
      [(and (<= (car ps) cur-pos) (<= cur-pos (cadr ps)))
       (cons (car ps) (cadr ps))]
      [else (loop (cddr ps))])))

;; Returns (open-pos . close-pos) for the pair surrounding cur-pos, or #f.
(define (find-surround-pair rope cur-pos char)
  (cond
    [(or (char=? char #\() (char=? char #\))) (find-bracket-pair rope cur-pos #\()]
    [(or (char=? char #\{) (char=? char #\})) (find-bracket-pair rope cur-pos #\{)]
    [(or (char=? char #\[) (char=? char #\])) (find-bracket-pair rope cur-pos #\[)]
    [(or (char=? char #\<) (char=? char #\>)) (find-bracket-pair rope cur-pos #\<)]
    [(or (char=? char #\") (char=? char #\') (char=? char #\`))
     (define cur-line (rope-char->line rope cur-pos))
     (find-quote-pair (quote-positions-on-line rope char cur-line) cur-pos)]
    [else #f]))

;;; ---- Tree-sitter helpers for tag operations ----

(define (ts-current-doc-id)
  (editor->doc-id (editor-focus)))

(define (ts-current-rope)
  (editor->text (ts-current-doc-id)))

(define (find-ancestor-of-kind node kind)
  (let loop ([n node])
    (cond
      [(not n) #f]
      [(equal? (tsnode-kind n) kind) n]
      [else (loop (tsnode-parent n))])))

(define (find-named-child node kind)
  (let loop ([children (tsnode-named-children node)])
    (cond
      [(null? children) #f]
      [(equal? (tsnode-kind (car children)) kind) (car children)]
      [else (loop (cdr children))])))

;; Extract the rope text covered by a TSNode as a string.
(define (tsnode-text rope node)
  (rope->string
    (rope->slice rope
      (rope-byte->char rope (tsnode-start-byte node))
      (rope-byte->char rope (tsnode-end-byte node)))))

;; Find the enclosing element node for the current cursor position.
(define (enclosing-element)
  (define rope (ts-current-rope))
  (define tree (document->tree (ts-current-doc-id)))
  (and rope tree
       (let* ([cb   (rope-char->byte rope (cursor-position))]
              [root (tstree->root tree)]
              [leaf (tsnode-named-descendant-byte-range root cb cb)])
         (find-ancestor-of-kind leaf "element"))))

;; Select a char range [start, end] (both inclusive) and replace with str.
(define (replace-char-range! start end str)
  (helix.static.set-current-selection-object!
    (helix.static.range->selection (helix.static.range start end)))
  (helix.static.replace-selection-with str))

;; Trim leading and trailing whitespace from a string.
(define (trim-string str)
  (define len (string-length str))
  (define start
    (let loop ([i 0])
      (if (or (>= i len) (not (char-whitespace? (string-ref str i)))) i (loop (+ i 1)))))
  (define end
    (let loop ([i (- len 1)])
      (if (or (< i 0) (not (char-whitespace? (string-ref str i)))) (+ i 1) (loop (- i 1)))))
  (if (>= start end) "" (substring str start end)))

;;; ---- dst — delete surrounding HTML/XML tag ----

(define (surround-delete-tag)
  (define rope (ts-current-rope))
  (define element (enclosing-element))
  (when element
    (define start-tag (find-named-child element "start_tag"))
    (define end-tag   (find-named-child element "end_tag"))
    (when (and start-tag end-tag)
      (define st-start (rope-byte->char rope (tsnode-start-byte start-tag)))
      (define st-end   (- (rope-byte->char rope (tsnode-end-byte start-tag)) 1))
      (define et-start (rope-byte->char rope (tsnode-start-byte end-tag)))
      (define et-end   (- (rope-byte->char rope (tsnode-end-byte end-tag)) 1))
      ;; Delete end tag first so start tag positions stay valid
      (replace-char-range! et-start et-end "")
      (replace-char-range! st-start st-end ""))))

;;; ---- cst — change surrounding HTML/XML tag name ----

(define (surround-change-tag)
  (define rope (ts-current-rope))
  (define element (enclosing-element))
  (when element
    (define start-tag (find-named-child element "start_tag"))
    (define end-tag   (find-named-child element "end_tag"))
    (when (and start-tag end-tag)
      (define st-name (find-named-child start-tag "tag_name"))
      (define et-name (find-named-child end-tag   "tag_name"))
      (when (and st-name et-name)
        ;; Capture all positions before opening the prompt
        (define st-start (rope-byte->char rope (tsnode-start-byte st-name)))
        (define st-end   (- (rope-byte->char rope (tsnode-end-byte st-name)) 1))
        (define et-start (rope-byte->char rope (tsnode-start-byte et-name)))
        (define et-end   (- (rope-byte->char rope (tsnode-end-byte et-name)) 1))
        (define current-name (tsnode-text rope st-name))
        (push-component!
          (prompt (string-append "Tag (" current-name "): ")
            (lambda (input)
              (define new-name (trim-string input))
              (when (> (string-length new-name) 0)
                ;; Replace end tag name first — doesn't shift start tag positions
                (replace-char-range! et-start et-end new-name)
                (replace-char-range! st-start st-end new-name)))))))))

;;; ---- ds{char} — delete surrounding pair ----

(define (vim-surround-delete)
  (on-key-callback
   (lambda (key-event)
     (define char (on-key-event-char key-event))
     (when char
       (if (char=? char #\t)
           (surround-delete-tag)
           (begin
             (define rope (get-document-as-slice))
             (define cur-pos (cursor-position))
             (define pair (find-surround-pair rope cur-pos char))
             (when pair
               (define open-pos (min (car pair) (cdr pair)))
               (define close-pos (max (car pair) (cdr pair)))
               ;; Delete close first so open-pos stays valid
               (move-to-position close-pos)
               (helix.static.replace-selection-with "")
               (move-to-position open-pos)
               (helix.static.replace-selection-with "")))))))))


;;; ---- cs{old}{new} — change surrounding pair ----

(define (vim-surround-change)
  (on-key-callback
   (lambda (key-event)
     (define old-char (on-key-event-char key-event))
     (when old-char
       (if (char=? old-char #\t)
           (surround-change-tag)
           (on-key-callback
            (lambda (key-event2)
              (define new-char (on-key-event-char key-event2))
              (when new-char
                (define rope (get-document-as-slice))
                (define cur-pos (cursor-position))
                (define pair (find-surround-pair rope cur-pos old-char))
                (when pair
                  (define open-pos (min (car pair) (cdr pair)))
                  (define close-pos (max (car pair) (cdr pair)))
                  ;; 1-for-1 replacement at close keeps open-pos valid
                  (move-to-position close-pos)
                  (helix.static.replace-selection-with (string (surround-close-char new-char)))
                  (move-to-position open-pos)
                  (helix.static.replace-selection-with (string (surround-open-char new-char))))))))))))


;;; ---- Core wrap: insert chars around the current selection ----

;; Gets selection bounds, exits to normal mode, then inserts at both ends.
;; Shared by S in visual mode and all ys{motion} wrappers.
(define (surround-wrap-selection char)
  (define primary (car (selection-char-ranges)))
  (define start-pos (car primary))
  (define end-pos (cadr primary))
  (define open-str (string (surround-open-char char)))
  (define close-str (string (surround-close-char char)))
  (helix.static.normal_mode)
  ;; Insert close after selection end (end is exclusive)
  (move-to-position end-pos)
  (helix.static.insert_string close-str)
  ;; Insert open before selection start (unchanged since end-pos > start-pos)
  (move-to-position start-pos)
  (helix.static.insert_string open-str))

;;; ---- S{char} / ys{motion}t — surround with HTML/XML tag ----

(define (surround-wrap-tag start-pos end-pos)
  (push-component!
    (prompt "Tag: "
      (lambda (input)
        (define name (trim-string input))
        (when (> (string-length name) 0)
          (define open-str  (string-append "<" name ">"))
          (define close-str (string-append "</" name ">"))
          ;; Insert close first (end-pos is exclusive; doesn't shift start-pos)
          (helix.static.set-current-selection-object!
            (helix.static.range->selection (helix.static.range end-pos end-pos)))
          (helix.static.insert_string close-str)
          (helix.static.set-current-selection-object!
            (helix.static.range->selection (helix.static.range start-pos start-pos)))
          (helix.static.insert_string open-str))))))

;;; ---- S{char} — surround visual selection (select mode) ----

(define (vim-surround-visual)
  (on-key-callback
   (lambda (key-event)
     (define char (on-key-event-char key-event))
     (when char
       (if (char=? char #\t)
           (let* ([primary   (car (selection-char-ranges))]
                  [start-pos (car primary)]
                  [end-pos   (cadr primary)])
             (helix.static.normal_mode)
             (surround-wrap-tag start-pos end-pos))
           (surround-wrap-selection char))))))

;;; ---- ys{motion}{char} — add surround with motion ----

(define (vim-surround-add-with-motion motion-fn)
  (helix.static.select_mode)
  (motion-fn)
  (vim-surround-visual))

(define (vim-surround-add-inner-word)          (vim-surround-add-with-motion select-inner-word))
(define (vim-surround-add-around-word)         (vim-surround-add-with-motion select-around-word))
(define (vim-surround-add-inner-long-word)     (vim-surround-add-with-motion select-inner-long-word))
(define (vim-surround-add-around-long-word)    (vim-surround-add-with-motion select-around-long-word))
(define (vim-surround-add-inner-paragraph)     (vim-surround-add-with-motion select-inner-paragraph))
(define (vim-surround-add-around-paragraph)    (vim-surround-add-with-motion select-around-paragraph))
(define (vim-surround-add-inner-curly)         (vim-surround-add-with-motion select-inner-curly))
(define (vim-surround-add-around-curly)        (vim-surround-add-with-motion select-around-curly))
(define (vim-surround-add-inner-paren)         (vim-surround-add-with-motion select-inner-paren))
(define (vim-surround-add-around-paren)        (vim-surround-add-with-motion select-around-paren))
(define (vim-surround-add-inner-square)        (vim-surround-add-with-motion select-inner-square))
(define (vim-surround-add-around-square)       (vim-surround-add-with-motion select-around-square))
(define (vim-surround-add-inner-double-quote)  (vim-surround-add-with-motion select-inner-double-quote))
(define (vim-surround-add-around-double-quote) (vim-surround-add-with-motion select-around-double-quote))
(define (vim-surround-add-inner-single-quote)  (vim-surround-add-with-motion select-inner-single-quote))
(define (vim-surround-add-around-single-quote) (vim-surround-add-with-motion select-around-single-quote))

(define (vim-surround-add-to-word-end)
  (helix.static.select_mode)
  (helix.static.extend_next_word_end)
  (vim-surround-visual))

(define (vim-surround-add-to-line-end)
  (helix.static.select_mode)
  (helix.static.extend_to_line_end)
  (vim-surround-visual))

;;; ---- Keybindings ----

(define surround-keybindings
  (keymap
   (normal
    ;; ds{char} — delete surrounding pair
    (d (s ":vim-surround-delete"))
    ;; cs{old}{new} — change surrounding pair
    (c (s ":vim-surround-change"))
    ;; ys{motion}{char} — add surrounding pair
    (y (s (i (w ":vim-surround-add-inner-word")
             (W ":vim-surround-add-inner-long-word")
             (p ":vim-surround-add-inner-paragraph")
             ("{" ":vim-surround-add-inner-curly")
             ("(" ":vim-surround-add-inner-paren")
             ("[" ":vim-surround-add-inner-square")
             ("\"" ":vim-surround-add-inner-double-quote")
             ("'" ":vim-surround-add-inner-single-quote"))
          (a (w ":vim-surround-add-around-word")
             (W ":vim-surround-add-around-long-word")
             (p ":vim-surround-add-around-paragraph")
             ("{" ":vim-surround-add-around-curly")
             ("(" ":vim-surround-add-around-paren")
             ("[" ":vim-surround-add-around-square")
             ("\"" ":vim-surround-add-around-double-quote")
             ("'" ":vim-surround-add-around-single-quote"))
          (e ":vim-surround-add-to-word-end")
          ($ ":vim-surround-add-to-line-end"))))
   (select
    ;; S{char} — surround visual selection
    (S ":vim-surround-visual"))))

(define (set-surround-keybindings!)
  (add-global-keybinding surround-keybindings))

(provide
  set-surround-keybindings!
  surround-delete-tag
  surround-change-tag
  surround-wrap-tag
  vim-surround-delete
  vim-surround-change
  vim-surround-visual
  vim-surround-add-inner-word
  vim-surround-add-around-word
  vim-surround-add-inner-long-word
  vim-surround-add-around-long-word
  vim-surround-add-inner-paragraph
  vim-surround-add-around-paragraph
  vim-surround-add-inner-curly
  vim-surround-add-around-curly
  vim-surround-add-inner-paren
  vim-surround-add-around-paren
  vim-surround-add-inner-square
  vim-surround-add-around-square
  vim-surround-add-inner-double-quote
  vim-surround-add-around-double-quote
  vim-surround-add-inner-single-quote
  vim-surround-add-around-single-quote
  vim-surround-add-to-word-end
  vim-surround-add-to-line-end)
