;; -*-mode: Emacs-Lisp; coding: utf-8;-*-
;;; braille-chords.el --- map simultaneous key presses of home keys to Braille dot patterns
;;------------------------------------------------------------------------
;; This is free and unencumbered software released into the public domain.
;;
;; Anyone is free to copy, modify, publish, use, compile, sell, or
;; distribute this software, either in source code form or as a compiled
;; binary, for any purpose, commercial or non-commercial, and by any
;; means.
;;
;; In jurisdictions that recognize copyright laws, the author or authors
;; of this software dedicate any and all copyright interest in the
;; software to the public domain. We make this dedication for the benefit
;; of the public at large and to the detriment of our heirs and
;; successors. We intend this dedication to be an overt act of
;; relinquishment in perpetuity of all present and future rights to this
;; software under copyright law.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
;; OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;; OTHER DEALINGS IN THE SOFTWARE.
;;
;; For more information, please refer to <http://unlicense.org/>
;;------------------------------------------------------------------------

;; Author: Patrick Stein <pat@nklein.com>
;; Created: 2015-02-11
;; Version: 0.1 (2015-02-11)
;; Keywords: keyboard chord input braille

;;; Commentary:

;; ########   Compatibility   ############################################
;;
;; Tested on Emacs 24.3.1
;;

;; ########   Quick start     ############################################
;;
;; Add to your ~/.emacs
;;     (require 'braille-chords)
;;
;; Enter Braille chords mode with:
;;     M-x braille-chords-mode
;;
;; While in Braille chords mode, simultaneous press multiple keys in
;; the home row of the keyboard.  By default, these are mapped to be
;; convenient on an English QWERTY keyboard:
;;
;;    key | f d s j k l a ;
;;    ----+----------------
;;    dot | 1 2 3 4 5 6 7 8
;;
;;   +---+---+---+---+---+---+---+---+---+---+
;;   | q | w | e | r | t | y | u | i | o | p |
;;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;;     |=7=|=3=|=2=|=1=| g | h |=4=|=5=|=6=|=8=|
;;     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;;       | z | x | c | v | b | n | m | , | . |
;;       +---+---+---+---+---+---+---+---+---+
;;
;; Exit Braille chords mode by pressing a printable, non-whitespace character
;; that is not one of the dot keys mentioned above.
;;

;; ########   Description     ############################################
;;
;; This package was developed using David Andersson's key-chord.el as an
;; example of how to create a small package which overrides the Emacs
;; input-mode and "detects" simultaneous key presses.
;;
;; Braille chords mode is a buffer-local minor mode.  It is controlled
;; by the function `braille-chords-mode'.
;;
;; When in Braille chords mode, simultaneous keypresses of the home key
;; are combined to create single Braille patterns.  Each finger in the
;; home position represents a dot in the overall Braille pattern.  The
;; left index finger is dot 1, the left middle finger is dot 2, and
;; the left ring finger is dot 3.  The right index finger is dot 4,
;; the right middle finger is dot 5, and the right ring finger is dot
;; 6.  The left pinky is dot 7.  The right pinky is dot 8.
;;
;; As an example, while in Braille chords mode, pressing 's', 'd', 'f',
;; and 'j' simultaneously generates the Braille pattern ⠏ which has
;; dots 1, 2, 3, and 4 set.
;;
;; You can override this mapping by setting the `braille-dot-keys'
;; association list.
;;
;; When in Braille chords mode, spaces are converted to the blank Braille
;; pattern.  All other whitespace is left as-is.
;;
;; When in Braille chords mode, pressing a printable, non-whitespace
;; character that does not represent a Braille dot exits Braille chords
;; mode.
;;
;; If chorded input is not your thing, you may like to check out
;; braille-input.el which is a contrib to the liblouis project that
;; allows one to enter Braille patterns using abbreviations for the
;; dot-patterns.  For example, the ⠕ pattern would be entered as
;; `b135' using that library.

;; ########   Limitations     ############################################
;;
;; Emacs does not provide both `key-down' and `key-up' events.  The
;; idea of "simultaneity" here is that the key-presses were received
;; in rapid succession.  You can control how many seconds between
;; consecutive presses count as "simultaneous" with the
;; `braille-dot-delay' variable.  On top of that, Emacs macros
;; effectively play back keystrokes without regard for timing, so
;; there is almost no chance that you can invoke a macro while in
;; Braille chords mode with any useful results.
;;
;; No effort has been made to ensure that your buffer is in a mode
;; which supports Unicode characters.  If it is not, then the
;; character inserted into your buffer may be illegal for the current
;; mode or not display as a Braille pattern.
;;
;; Braille chords mode overrides the `input-method-function'.  So do a
;; variety of other packages (key-chord, mule, quail, ...).  They
;; don't play well together.  If you run into trouble, I recommend
;; using Braille mode in a scratch buffer and yanking the results into
;; the buffer you want.
;;
;; Emacs will not call `input-method-function' for keys that have
;; non-numeric codes or whose code is outside the range 32..126, so
;; only keys in that range can be used to represent Braille dots or
;; to escape from Braille chords mode.
;;
;; The BRAILLE PATTERN BLANK is not recognized as whitespace by any of
;; the functions which attempt to linewrap or otherwise reformat text.
;; On the other hand, for most fonts, spaces are a different width
;; than the BRAILLE PATTERN BLANK.  You can set the
;; `braille-blank-for-space' variable to `NIL' if you would prefer to
;; have <Space>s remain <Space>s.

;; ########   History     ################################################
;;
;; 0.1 (2005-02-11) pat@nklein.com
;;     First release

;;; Code:

(defconst semicolon (char-from-name "SEMICOLON")
  "This is included here because the literal ?; is intrepreted by
Emacs indenting and color coding to be a question mark followed by a comment.")

;;;###autoload
(defvar braille-blank-for-spaces t
  "When non-NIL, the <Space> in Braille chords mode is emitted as
a BRAILLE PATTERN BLANK.  For example, the following two lines
say the same thing, the first with spaces and the second with the
blank Braille pattern:
  ⠠⠽ ⠜⠑ ⠥⠎⠬ ⠃⠗⠇ ⠡⠕⠗⠙⠎ ⠍⠕⠙⠑⠲
  ⠠⠽⠀⠜⠑⠀⠥⠎⠬⠀⠃⠗⠇⠀⠡⠕⠗⠙⠎⠀⠍⠕⠙⠑⠲
With my current font, the second line takes up more room than the
first.")

;;;###autoload
(defvar braille-dot-delay 0.05
  "Max time delay between two key presses to be considered part
of the same Braille pattern.")

;;;###autoload
(defvar braille-dot-keys
  `((?f . 1) (?d . 2) (?s . 3)
    (?j . 4) (?k . 5) (?l . 6)
    (?a . 7) (,semicolon . 8))
  "This specifies the mapping from keys pressed to Braille dots.")

;; Internal variables

(defvar braille-chords-mode nil
  "Whether we are currently in Braille chords mode.")

;; Constants used for cleaner code below.
(defconst braille-pattern-blank (char-from-name "BRAILLE PATTERN BLANK")
  "The empty Braille pattern.")

;;;###autoload
(define-minor-mode braille-chords-mode
  "Toggle Braille chords mode.
With positive ARG enable the mode.  With zero or negative arg
diable the mode.  While in the mode, look for key presses in
rapid sequence of the keys 'f', 'd', 's', 'j', 'k', 'l'.
Interpret those in rapid succession as Braille dots 1, 2, 3, 4,
5, and 6 respectively.  For <Space>, use the Unicode character
for a Braille cell with no dots.  For other whitespace, pass
those characters through.  For all other characters, switch out
of Braille chords mode and pass those characters through."
  :init-value nil
  :lighter " ⠃⠗⠇")

;;;###autoload
(defun braille-chords-mode (arg)
  "Toggle Braille chords mode.
With positive ARG enable the mode.  With zero or negative arg
diable the mode.  While in the mode, look for key presses in
rapid sequence of the keys 'f', 'd', 's', 'j', 'k', 'l'.
Interpret those in rapid succession as Braille dots 1, 2, 3, 4,
5, and 6 respectively.  For <Space>, use the Unicode character
for a Braille cell with no dots.  For other whitespace, pass
those characters through.  For all other characters, switch out
of Braille chords mode and pass those characters through."
  (interactive "P")
  (setq braille-chords-mode (if arg
                               (> (prefix-numeric-value arg) 0)
                             (not braille-chords-mode)))
  (cond
   (braille-chords-mode
    (setq-local input-method-function 'braille-chords-input-method)
    (message "Braille chords mode on"))
   (t
    (setq-local input-method-function nil)
    (message "Braille chords mode off"))))


(defun whitespace-p (char)
  (or (char-equal char ?\t)
      (char-equal char ?\n)
      (char-equal char ?\f)
      (char-equal char ?\r)
      (char-equal char ?\s)))

(defun braille-dot-for (char)
  (cdr (assoc char braille-dot-keys)))

(defun incorporate-dot-value (current-char-code dot-value)
  (logior braille-pattern-blank
          current-char-code
          (ash 1 (1- dot-value))))

(defun process-multi-dot-character (char current-char-code)
  (let ((dot-value (braille-dot-for char)))
    (cond
     (dot-value
      (let ((current-char-code (incorporate-dot-value
                                current-char-code
                                dot-value))
            (next-char (unless (sit-for braille-dot-delay nil)
                         (read-event))))
        (if next-char
            (process-multi-dot-character next-char current-char-code)
          (list current-char-code))))
     (t
      (braille-chords-mode 0)
      (if (> current-char-code 0)
          (list current-char-code char)
        (list char))))))

(defun braille-chords-input-method (first-char)
  (cond
   ;; Return <Space> as a BRAILLE PATTERN BLANK if set to do so.
   ((and braille-blank-for-spaces
         (char-equal first-char ?\s))
    (list braille-pattern-blank))

   ;; Return other whitespace as itself
   ((whitespace-p first-char)
    (list first-char))

   (t
    (process-multi-dot-character first-char 0))))

(provide 'braille-chords)

;;; braille-chords.el ends here
