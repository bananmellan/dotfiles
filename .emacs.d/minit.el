(if (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(global-subword-mode 1)
;; (xterm-mouse-mode 1)

(fset 'yes-or-no-p 'y-or-n-p)
(setq create-lockfiles nil)
(setq make-backup-files nil)
(setq backup-directory-alist         `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t)))
(setq vc-follow-symlinks t)

(use-package emacs
  :bind
  ("C-z" . nil) ;; Unset freeze-key

  ("M-i" . imenu)

  ("C-å" . comment-line)
  ("C-ö" . undo)
  ("M-[ ö" . undo))
