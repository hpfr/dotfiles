{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.user.emacs;
in {
  options.profiles.user.emacs.enable = mkEnableOption "my emacs configuration";

  config = mkIf cfg.enable {
    programs = {
      emacs = {
        enable = true;
        extraPackages = epkgs: [ epkgs.vterm ];
      };
      fish.shellInit = ''
        # fish does not perform wordsplitting
        set EDITOR emacsclient -ca emacs
      '';
    };

    services.emacs = {
      enable = false;
      # TODO: make this independent of emacs service upstream
      client.enable = true; # xdg desktop file
    };

    home = {
      packages = with pkgs;
        [
          # TODO: expose these only to emacs somehow
          gnutls # circe
          # TODO: bump nixpkgs tdlib to 1.7.3 for telega
          tdlib # telega
          gnumake # telega
          cmake # telega
          gcc # magit forge https://www.reddit.com/r/emacs/comments/adlmh2/
          sqlite # org-roam
          ripgrep # doom code searching features
          jq # json parsing
          gdb # gdb mode, lsp gdb
          nodejs # dap-mode
          openssl # elpher gemini support
          python3 # treemacs advanced features, telega

          # language linting and formatting
          shellcheck # shell linting
          shfmt # shell formatting
          clang-tools # for clang-format
          nixfmt # opinionated nix formatting
          html-tidy # html and xml formatting
          black # python

          # language servers
          ccls # c
          lua53Packages.digestif # TeX
          gopls # go
          jdk11 # java
          rls # rust
          nodePackages.pyright # python
          python3Packages.debugpy
          nodePackages.javascript-typescript-langserver
        ] ++ (if config.profiles.user.gui-base.enable then
          [
            libreoffice # docx to docview
          ]
        else
          [ ]);

      sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];
      sessionVariables = {
        # fall back to emacs if no emacs server
        EDITOR = "emacsclient -ca emacs";
      };
    };

    xdg = {
      configFile = {
        "doom" = {
          source = ./doom;
          recursive = true;
        };
        "doom/doom-source-dir.el".text = ''
          (setq lh/doom-source-dir "${toString ./doom}/")
        '';
        "doom/modules/lh/email/mu4e-load-path.el".text = ''
          (add-to-list 'load-path "${pkgs.mu}/share/emacs/site-lisp/mu4e")
        '';
        "doom/telega-server-libs.el".text = ''
          (setq telega-server-libs-prefix "${pkgs.tdlib}")
        '';
      };
      mimeApps = let
        applyToAll = list:
          builtins.listToAttrs (map (key: {
            name = key;
            value = "emacsclient.desktop";
          }) list);
      in {
        associations.added = applyToAll [
          "application/pdf"
          "inode/directory"
          "text/x-diff"
          "application/vnd.ms-powerpoint"
          "application/epub+zip"
        ] // {
          "x-scheme-handler/mailto" = "emacsclient-mail.desktop";
          "x-scheme-handler/gopher" = "emacsclient-gemini.desktop";
          "x-scheme-handler/gemini" = "emacsclient-gemini.desktop";
        };
        defaultApplications = applyToAll [
          "application/pdf"
          "inode/directory"
          "text/x-diff"
          "application/epub+zip"
        ] // {
          "x-scheme-handler/mailto" = "emacsclient-mail.desktop";
          "x-scheme-handler/gopher" = "emacsclient-gemini.desktop";
          "x-scheme-handler/gemini" = "emacsclient-gemini.desktop";
        };
      };
      # these are output to /etc/profiles/per-user/lh/share/applications
      desktopEntries = {
        emacsclient = {
          type = "Application";
          name = "Emacsclient";
          genericName = "Text Editor";
          comment = "Edit text";
          mimeType = [
            "text/english"
            "text/plain"
            "text/x-makefile"
            "text/x-c++hdr"
            "text/x-c++src"
            "text/x-chdr"
            "text/x-csrc"
            "text/x-java"
            "text/x-moc"
            "text/x-pascal"
            "text/x-tcl"
            "text/x-tex"
            "application/x-shellscript"
            "text/x-c"
            "text/x-c++"
          ];
          # the --no-wait option is necessary to actually get a new frame for
          # some reason. from terminal you don't need it but you do from openers
          # like firefox
          # https://forum.manjaro.org/t/emacsclient-as-desktop-application/132072
          exec =
            "emacsclient --create-frame --alternate-editor emacs --no-wait %F";
          icon = "emacs";
          categories = [ "Development" "TextEditor" ];
          settings = {
            StartupWMClass = "Emacs";
            Keywords = "Text;Editor;";
          };
        };
        emacsclient-mail = let
          execScript = pkgs.writeShellScript "emacsclient-mail.sh" ''
            set -euo pipefail
            emacsclient --create-frame --alternate-editor 'emacs --eval' --no-wait --eval "(progn (x-focus-frame nil) (mu4e-compose-from-mailto \"$1\"))"
          '';
        in {
          type = "Application";
          name = "Mu4e";
          genericName = "Email client";
          comment = "Compose email";
          mimeType = [ "x-scheme-handler/mailto" ];
          exec = "${execScript} %u";
          categories = [ "Network" "Email" ];
          settings.NoDisplay = "true";
        };
        emacsclient-gemini = let
          execScript = pkgs.writeShellScript "emacsclient-gemini.sh" ''
            set -euo pipefail
            emacsclient --create-frame --alternate-editor 'emacs --eval' --no-wait --eval "(progn (x-focus-frame nil) (require 'elpher) (elpher-go \"$1\"))"
          '';
        in {
          type = "Application";
          name = "Elpher";
          genericName = "Gopher/Gemini browser";
          comment = "View Gopher/Gemini sites";
          mimeType = [ "x-scheme-handler/gemini" "x-scheme-handler/gopher" ];
          exec = "${execScript} %u";
          categories = [ "Network" "X-Gemini" "X-Gopher" ];
          settings.NoDisplay = "true";
        };
      };
    };
  };
}
