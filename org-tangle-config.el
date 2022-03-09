;;; org-tangle-config.el --- Checks .org config files for updates before babel loading them -*- lexical-binding: t; -*-

;; Copyright (C) Trevor Richards

;; Author: Trevor Richards <trev@trevdev.ca>
;; Version: 1.0.2
;; Keywords: performance, utility
;; URL: https://github.com/trev-dev/org-tangle-config.el

;;; License:
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>

;;; Commentary:
;; This package contains a small function library for comparing your .org
;; configuration file against a timestamp of a previous version of that file.
;; If the timestamps do not match, or your config.el is missing, it will use
;; org-babel-tangle-file to create a new config.el.  The stamp is stored
;; in a hidden file that is the same as your config file name with the .prev
;; extension

;;;  Example:
;; (require 'org-tangle-config)
;; If no path is provided the default is "~/.emacs.d/config.org"
;; (org-tangle-config-before-load "/path/to/file.org")

;;; Code:
;;; Global Variables:
(defgroup org-tangle-config nil
  "Compare your config against an old version before tangling it."
  :group 'tools)

(defcustom org-tangle-config-org-file nil
  "The location of your .org formatted configuration file."
  :type 'string
  :group 'org-tangle-config)

(defcustom org-tangle-config-hash nil
  "A basic cryptographic hash of the last known config version."
  :type 'string
  :group 'org-tangle-config)

(defun org-tangle-config-set-enable (sym value)
  "Set the `SYM' (`org-tangle-config-enable') to a new `VALUE'.
After that, add or remove the auto-save hook as needed."
  (set sym value)
  (funcall (if value #'add-hook #'remove-hook)
           'after-save-hook
           #'org-tangle-config-do-auto-tangle))

(defcustom org-tangle-config-enable nil
  "Whether or not to auto-tangle the configuration on `after-save-hook'."
  :type 'boolean
  :set 'org-tangle-config-set-enable
  :initialize 'custom-initialize-set
  :group 'org-tangle-config)

;;; Functions:
(defun org-tangle-config-get-hash (path)
  "Get the modified time of a file from a PATH if it exists."
  (if (file-exists-p (expand-file-name path))
      (with-temp-buffer
       (insert-file-contents path)
       (buffer-hash))
    (error (format "Org file configuration %s could not be found"
                   (expand-file-name path)))))

(defun org-tangle-config-record-hash (new-hash)
  "Save the `NEW-HASH' hash to the `org-tangle-config-hash' variable."
  (customize-save-variable
   'org-tangle-config-hash
   new-hash
   (format "Last updated %s" (current-time-string)))
  new-hash)

(defun org-tangle-config-new-hash (next-hash)
  "Compare the `NEXT-HASH' to the stored `org-tangle-config-hash'.
Return `NEXT-HASH' if it is new."
  (when (not (equal org-tangle-config-hash next-hash))
    next-hash))

(defun org-tangle-config-get-config (org-file)
  "Get the path to a tangled configuration based on a given `ORG-FILE'."
  (format "%s%s.el"
          (file-name-directory (expand-file-name org-file))
          (file-name-sans-extension (file-name-nondirectory org-file))))

(defun org-tangle-config-load (config)
  "Load an existing `CONFIG'."
    (if (file-exists-p config)
        (load-file config)))


;;; Auto-save hook function.
(defun org-tangle-config-do-auto-tangle ()
  "Automatically tangle the config when it is saved."
  (if (equal buffer-file-name (expand-file-name org-tangle-config-org-file))
      (org-tangle-config-do-tangle
       (org-tangle-config-new-hash
        (org-tangle-config-get-hash
         org-tangle-config-org-file))
       t)))

(defun org-tangle-config-do-tangle (new-hash &optional inter)
  "Tangle a new config, record the `NEW-HASH' and alert user based on `INTER'.
Meant for internal use.  Return `NEW-HASH' if tangle is done."
  (if (and (featurep 'org) (stringp new-hash))
      (progn
        (require 'org)
        (org-tangle-config-record-hash new-hash)
        (org-babel-tangle-file org-tangle-config-org-file)
        (funcall
         (if inter #'message #'message-box)
         "Your configuration has been tangled. Restart Emacs to use it.")
        new-hash)))

;;;###autoload
(defun org-tangle-config-enable (&optional enable)
  "`ENABLE' the `org-tangle-config-do-auto-tangle' hook."
  (interactive)
  (customize-set-variable
   'org-tangle-config-enable (or enable (not org-tangle-config-enable)))
  (message "Auto tangle config %s"
           (if org-tangle-config-enable "enabled" "disabled"))
  :group 'org-tangle-config)

;;;###autoload
(defun org-tangle-config ()
  "Tangle the `org-tangle-config-org-file' and record a `NEW-HASH' version."
  (interactive)
  (org-tangle-config-do-tangle
   (org-tangle-config-new-hash
    (org-tangle-config-get-hash
     org-tangle-config-org-file))
   (called-interactively-p 'interactive))
  :group 'org-tangle-config)

;;;###autoload
(defun org-tangle-config-before-load (&optional config)
  "Compare your Org `CONFIG' to its previous version.
Tangle a new config if the org configuration has changed."
  (if (stringp config)
      (setq org-tangle-config-org-file config))
  (if (not (org-tangle-config-do-tangle
            (org-tangle-config-new-hash
             (org-tangle-config-get-hash
              org-tangle-config-org-file))))
      (org-tangle-config-load
       (org-tangle-config-get-config
        org-tangle-config-org-file)))
  :group 'org-tangle-config)

(provide 'org-tangle-config)
;;; org-tangle-config.el ends here
