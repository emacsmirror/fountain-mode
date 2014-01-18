;; fountain-mode.el --- Emacs major mode for editing Fountain files

;; author: Paul Rankin <paul@tilk.co>
;; maintainer: Paul Rankin <paul@tilk.co>
;; created: 2014-01-16
;; version: 0.7
;; keywords: Fountain, screenplay, screenwriting, scriptwriting
;; url: http://github.com/rnkn/fountain-mode/

;; This file is not part of GNU Emacs.

;; The MIT License (MIT)

;; Copyright (c) 2014 Paul Rankin

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.


;;; Code:

;;; Group ======================================================================

(defgroup fountain ()
  "Major mode for editing Fountain-formatted text files."
  :prefix "fountain-"
  :group 'wp
  :link '(url-link "http://github.com/rnkn/fountain-mode/"))


;;; Customizable Options =======================================================

(defcustom fountain-export-options-template
  "title: 
credit: 
author: 
draft date: 
contact: 
"
  "Export options template inserted at the beginning of buffer."
  :type 'string
  :group 'fountain)

(defcustom fountain-slugline-prefix-list
  '("int." "ext." "i/e." "est.")
  "List of slugline prefixes (case insensitive).
The default list requires that each slugline prefix be appended
with a dot, like so:

INT. HOUSE - DAY

If you prefer not to append a dot to your slugline prefixes, you
can add \"int\", \"ext\", etc. here."
  :type '(repeat (string :tag "Prefix"))
  :group 'fountain)

(defcustom fountain-trans-list
  '("fade in:" "to:" "fade out" "to black")
  "List of transition endings (case insensitive).
This list is used to match the endings of transitions,
e.g. \"to:\" will match both the following:

CUT TO:

DISSOLVE TO:"
  :type '(repeat (string :tag "Transition"))
  :group 'fountain)

(defcustom fountain-align-column-character 20
  "Column integer to which character should be aligned."
  :type 'integer
  :group 'fountain)

(defcustom fountain-align-column-dialogue 10
  "Column integer to which dialogue should be aligned."
  :type 'integer
  :group 'fountain)

(defcustom fountain-align-column-paren 15
  "Column integer to which parenthetical should be aligned."
  :type 'integer
  :group 'fountain)

(defcustom fountain-align-column-trans 45
  "Column integer to which transitions should be aligned."
  :type 'integer
  :group 'fountain)

(defcustom fountain-indent-elements t
  "If non-nil, elements will be displayed indented.
This option does not affect file contents."
  :type 'boolean
  :group 'fountain)

(defcustom fountain-dot-slugline-hierarchy t
  "If non-nil, forced sluglines will take a lower hierarchy.
When writing, it is usually preferable to treat forced sluglines
as constituents of the larger scene. If you prefer to treat
forced sluglines like regular sluglines, set this to nil."
  :type 'boolean
  :group 'fountain)


;;; Element Regular Expressions ================================================

(defconst fountain-line-empty-regexp
  (rx line-start
      (zero-or-one " ")
      line-end)
  "Regular expression for matching an empty line.")

(defvar fountain-slugline-regexp
  (rx line-start
      (eval `(or ,@fountain-slugline-prefix-list))
      (one-or-more " ")
      (zero-or-more not-newline))
  "Regular expression for matching sluglines.
Requires `fountain-slugline-p' for preceding and succeeding blank
lines.")

(defconst fountain-dot-slugline-regexp
  (rx line-start
      (group "." word-start)
      (group (zero-or-more not-newline)))
  "Regular expression for matching forced sluglines.")

(defconst fountain-character-regexp
  (rx (zero-or-more blank)
      (group (one-or-more (not (any lower "(" "\n"))))
      (group (zero-or-one "(" (zero-or-more not-newline))))
  "Regular expression for matching characters.")

(defvar fountain-paren-regexp
  (rx line-start
      (zero-or-more blank)
      "(" (zero-or-more not-newline) ")"
      (zero-or-more blank)
      line-end)
  "Regular expression for matching parentheticals.")

(defvar fountain-trans-regexp
  (rx (or (and line-start
               (zero-or-more blank)
               ">"
               (group (zero-or-more (any upper blank ":"))
                      line-end))
          (and line-start
               (zero-or-more (any upper blank))
               (eval `(or ,@fountain-trans-list))
               (zero-or-one blank)
               line-end)))
  "Regular expression for matching transitions.
Requires `fountain-trans-p' for preceding and succeeding blank
lines.")

(defconst fountain-page-break-regexp
  (rx line-start
      (group (zero-or-more blank))
      (group (>= 3 "="))
      (group (zero-or-more not-newline)))
  "Regular expression for matching page breaks.")

(defconst fountain-note-regexp
  (rx (group "[[")
      (group (zero-or-more not-newline (zero-or-one "\n")))
      (group "]]"))
  "Regular expression for matching comments.")

(defconst fountain-section-regexp
  (rx line-start
      (group (repeat 1 5 "#") (not (any "#")))
      (group (zero-or-more not-newline)))
  "Regular expression for matching sections.")

(defconst fountain-synopsis-regexp
  (rx line-start
      (group "=" (not (any "=")))
      (group (zero-or-more not-newline)))
  "Regular expression for matching synopses.")


;;; Faces ======================================================================

(require 'font-lock)

(defgroup fountain-faces nil
  "Faces used in Fountain Mode"
  :group 'fountain)

(defvar fountain-slugline-face 'fountain-slugline-face
  "Face name to use for sluglines.")

(defvar fountain-dot-slugline-face
  (if fountain-dot-slugline-hierarchy
      'fountain-dot-slugline-face
    'fountain-slugline-face)
  "Face name to use for forced sluglines.")

(defvar fountain-character-face 'fountain-character-face
  "Face name to use for character names.")

(defvar fountain-note-face 'fountain-note-face
  "Face name to use for notes.")

(defvar fountain-section-face 'fountain-section-face
  "Face name to use for sections.")

(defvar fountain-synopsis-face 'fountain-synopsis-face
  "Face name to use for synopses.")

(defface fountain-slugline-face
  '((t (:weight bold :underline t)))
  "Face for sluglines."
  :group 'fountain-faces)

(defface fountain-dot-slugline-face
  '((t (:weight bold)))
  "Face for forced sluglines."
  :group 'fountain-faces)

(defface fountain-character-face
  '((t (:foreground "red")))
  "Face for character names."
  :group 'fountain-faces)

(defface fountain-nonprinting-face
  '((t (:foreground "dim gray")))
  "Face for comments."
  :group 'fountain-faces)

(defface fountain-note-face
  '((t (:foreground "forest green")))
  "Face for notes.")

(defface fountain-section-face
  '((t (:foreground "dark red")))
  "Face for sections."
  :group 'fountain-faces)

(defface fountain-synopsis-face
  '((t (:foreground "dark cyan")))
  "Face for synopses."
  :group 'fountain-faces)


;;; Font Lock ==================================================================

(defvar fountain-font-lock-keywords
  `((,fountain-slugline-regexp . fountain-slugline-face)
    (,fountain-dot-slugline-regexp . fountain-dot-slugline-face)
    (,fountain-section-regexp . fountain-section-face)
    (,fountain-synopsis-regexp . fountain-synopsis-face)
    (,fountain-note-regexp . fountain-note-face))
  "Font lock highlighting keywords.")


;;; Functions ==================================================================

(defun fountain-get-line ()
  "Return the line at point as a string."
  (buffer-substring-no-properties
   (line-beginning-position) (line-end-position)))

(defun fountain-trim-whitespace (str)
  "Trim the leading and trailing whitespace of STR."
  (setq str (mapconcat 'identity (split-string str) " ")))

(defun fountain-line-upper-p ()
  "Return non-nil if line at point is uppercase."
  (let ((str (fountain-get-line)))
    (string= (upcase str) str)))

(defun fountain-line-empty-p ()
  "Return non-nil if line at point is a newline or single space."
  (save-excursion
    (forward-line 0)
    (looking-at-p fountain-line-empty-regexp)))

(defun fountain-section-p ()
  "Return non-nil if line at point is a section heading."
  (save-excursion
    (forward-line 0)
    (looking-at-p fountain-section-regexp)))

(defun fountain-synopsis-p ()
  "Return non-nil if line at point is a synopsis."
  (save-excursion
    (forward-line 0)
    (looking-at-p fountain-synopsis-regexp)))

(defun fountain-boneyard-p ()
  "Return non-nil if line at point is within boneyard."
  (comment-only-p (line-beginning-position) (line-end-position)))

(defun fountain-blank-p ()
  "Return non-nil if line at point is considered blank.
A line is blank if it is empty, or consists of a comment,
section, synopsis or is within a boneyard."
  (cond ((fountain-line-empty-p))
        ((fountain-boneyard-p))
        ((fountain-note-p))
        ((fountain-section-p))
        ((fountain-synopsis-p))))

(defun fountain-frontmatter-p ()
  "Return non-nil if line at point is frontmatter."
  (ignore))

(defun fountain-slugline-p ()
  "Return non-nil if line at point is a slugline."
  (save-excursion
    (forward-line 0)
    (and (or (bobp)
             (save-excursion
               (forward-line -1)
               (fountain-blank-p)))
         (save-excursion
           (forward-line 1)
           (or (eobp)
               (fountain-blank-p)))
         (looking-at-p fountain-slugline-regexp))))

(defun fountain-dot-slugline-p ()
  "Return non-nil if line at point is a forced slugline."
  (save-excursion
    (forward-line 0)
    (and (or (bobp)
             (save-excursion
               (forward-line -1)
               (fountain-blank-p)))
         (save-excursion
           (forward-line 1)
           (or (eobp)
               (fountain-blank-p)))
         (looking-at-p fountain-dot-slugline-regexp))))

(defun fountain-character-p ()
  "Return non-nil if line at point is a character name."
  (unless (or (fountain-line-empty-p)
              (fountain-slugline-p))
    (and (let ((str (car (split-string (fountain-get-line) "("))))
           (string= (upcase str) str))
         (save-excursion
           (forward-line 0)
           (and (or (bobp)
                    (save-excursion
                      (forward-line -1)
                      (fountain-line-empty-p)))
                (save-excursion
                  (forward-line 1)
                  (unless (eobp)
                    (not (fountain-blank-p)))))))))

(defun fountain-dialogue-p ()
  "Return non-nil if line at point is dialogue."
  (unless (or (fountain-blank-p)
              (fountain-paren-p))
    (save-excursion
      (forward-line -1)
      (unless (bobp)                    ; FIXME character at bobp
        (or (fountain-character-p)
            (fountain-paren-p)
            (fountain-dialogue-p))))))

(defun fountain-paren-p ()
  "Return non-nil if line at point is a paranthetical."
  (save-excursion
    (forward-line 0)
    (and (looking-at-p fountain-paren-regexp)
         (forward-line -1)
         (unless (bobp)
           (or (fountain-character-p)
               (fountain-dialogue-p))))))

(defun fountain-trans-p ()
  "Return non-nil if line at point is a transition."
  (and (fountain-line-upper-p)
       (save-excursion
         (forward-line 0)
         (looking-at-p fountain-trans-regexp))
       (save-excursion
         (forward-line -1)
         (or (bobp)
             (fountain-line-empty-p)))
       (save-excursion
         (forward-line 1)
         (or (eobp)
             (fountain-line-empty-p)))))

(defun fountain-note-p ()
  "Return non-nil if line at point is a note."
  (save-excursion
    (forward-line 0)
    (looking-at-p fountain-note-regexp)))

(defun fountain-indent-add (column)
  "Add indentation properties to line at point."
  (with-silent-modifications
    (put-text-property (line-beginning-position) (line-end-position)
                       'line-prefix `(space :align-to ,column))
    (put-text-property (line-beginning-position) (line-end-position)
                       'wrap-prefix `(space :align-to ,column))))

(defun fountain-indent-refresh (start end length)
  "Refresh indentation properties of restriction."
  (save-excursion
    (goto-char end)
    (forward-paragraph 1)
    (setq end (point))
    (goto-char start)
    (forward-paragraph -1)
    (while (< (point) end)
      (cond ((fountain-character-p)
             (fountain-indent-add fountain-align-column-character))
            ((fountain-paren-p)
             (fountain-indent-add fountain-align-column-paren))
            ((fountain-dialogue-p)
             (fountain-indent-add fountain-align-column-dialogue))
            ((fountain-trans-p)
             (fountain-indent-add fountain-align-column-trans))
            ((fountain-indent-add 0)))
      (forward-line 1))))


;;; Interaction ================================================================

(defun fountain-upcase-line ()
  "Upcase the line."
  (interactive)
  (upcase-region (line-beginning-position) (line-end-position)))

(defun fountain-upcase-line-and-newline ()
  "Upcase the line and insert a newline."
  (interactive)
  (upcase-region (line-beginning-position) (point))
  (newline))

(defun fountain-next-comment ()
  "Find the next comment."
  (interactive)
  (search-forward comment-start))

(defun fountain-note-dwim (&optional arg)
  "Insert a note. If prefixed with ARG, also insert a UUID."
  (interactive "P")
    (let ((comment-start "[[")
          (comment-end "]]"))
      (comment-dwim nil)
      (if arg
          (let ((str (downcase (shell-command-to-string "uuidgen"))))
            (insert (car (split-string str "-")))))))

(defun fountain-insert-export-options ()
  "Insert the export options template at the beginning of file."
  (interactive)
  (save-excursion
    (save-restriction
      (goto-char (point-min))
      (insert fountain-export-options-template "\n\n"))))


;;; Mode Map ===================================================================

(defvar fountain-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<S-return>") 'fountain-upcase-line-and-newline)
    (define-key map (kbd "C-c C-z") 'fountain-note-dwim)
    map)
  "Mode map for `fountain-mode'.")


;;; Syntax Table ===============================================================

(defvar fountain-mode-syntax-table
  (let ((syntax (make-syntax-table)))
    (modify-syntax-entry ?\/ ". 14" syntax)
    (modify-syntax-entry ?* ". 23" syntax)
    syntax)
  "Syntax table for `fountain-mode'.")


;;; Mode Definition ============================================================

;;;###autoload
(define-derived-mode fountain-mode text-mode "Fountain"
  "Major mode for editing Fountain-formatted text files.
For more information on the Fountain markup format, visit
<http://fountain.io>."
  :group 'fountain
  (set (make-local-variable 'comment-start) "/*")
  (set (make-local-variable 'comment-end) "*/")
  (set (make-local-variable 'font-lock-comment-face)
       'fountain-nonprinting-face)
  (setq font-lock-defaults '(fountain-font-lock-keywords nil t))
  (when fountain-indent-elements
    (fountain-indent-refresh (point-min) (point-max) nil)
    (add-hook 'after-change-functions 'fountain-indent-refresh nil t)))

(provide 'fountain-mode)

;;; fountain-mode.el ends here
