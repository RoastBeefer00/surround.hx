(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/keymaps.scm")
(require "helix/components.scm")

(require-builtin helix/core/text)

;; Import shared utilities from the vim plugin.
;; Paths resolve relative to this file's installed location (~/.config/helix/surround.hx/),
;; so ../vim/ points at ~/.config/helix/vim/ where the vim plugin lives.
(require "../vim/utils.scm")
(require "../vim/visual-motions.scm")

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

;;; ---- ds{char} — delete surrounding pair ----

(define (vim-surround-delete)
  (on-key-callback
   (lambda (key-event)
     (define char (on-key-event-char key-event))
     (when char
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
         (helix.static.replace-selection-with ""))))))

;;; ---- cs{old}{new} — change surrounding pair ----

(define (vim-surround-change)
  (on-key-callback
   (lambda (key-event)
     (define old-char (on-key-event-char key-event))
     (when old-char
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
              (helix.static.replace-selection-with (string (surround-open-char new-char)))))))))))

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

;;; ---- S{char} — surround visual selection (select mode) ----

(define (vim-surround-visual)
  (on-key-callback
   (lambda (key-event)
     (define char (on-key-event-char key-event))
     (when char
       (surround-wrap-selection char)))))

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
