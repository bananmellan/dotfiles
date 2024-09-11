(load-file "~/.emacs.d/minit.el")
(require 'magit)
(global-set-key (kbd "C-x g") 'magit-status)
(setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1)

(magit-status)
