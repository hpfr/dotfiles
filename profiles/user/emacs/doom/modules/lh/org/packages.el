;; -*- no-byte-compile: t; -*-
(package! org-super-agenda)
(package! org-caldav)
;; TODO: references .emacs.d instead of variable
(package! org-vcard :disable t)
(package! org-chef)
(when (featurep! :lang org +present)
  (package! revealjs-plugins-rajgoel :recipe (:host github :repo "rajgoel/reveal.js-plugins" :files ("chalkboard"))))
