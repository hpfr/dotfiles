{ config, pkgs, lib, options, ... }:

{
  imports = [ /etc/nixos/hardware-configuration.nix <home-manager/nixos> ];

  nix.nixPath = options.nix.nixPath.default
    ++ [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      (self: super: { mwlwifi = super.callPackage ./pkgs/mwlwifi { }; })
      (self: super: { ipts = super.callPackage ./pkgs/ipts { }; })
      (self: super: { i915 = super.callPackage ./pkgs/i915 { }; })
      (self: super: { mrvl = super.callPackage ./pkgs/mrvl { }; })
      # # Globally patched libwacom. Forces rebuilds of libinput and all
      # # dependents
      # (self: super: {
      #   libwacom = super.libwacom.overrideAttrs (oldAttrs: {
      #     patches = oldAttrs.patches or [ ]
      #       ++ (map (name: ./pkgs/libwacom/patches + "/${name}")
      #         (builtins.attrNames (lib.filterAttrs (k: v: v == "regular")
      #           (builtins.readDir ./pkgs/libwacom/patches))));
      #   });
      # })
      # Limit patched libwacom to Xorg. Everything still works afaict
      (self: super: {
        # I believe this is for desktop environments that depend on
        # xf86inputlibinput, but otherwise the xorg overlay covers everything
        xf86inputlibinput = super.xf86inputlibinput.override {
          libinput = self.libinput-surface;
        };
        xorg = super.xorg // {
          xf86inputlibinput = super.xorg.xf86inputlibinput.override {
            libinput = self.libinput-surface;
          };
        };
        libinput-surface = super.libinput.override {
          libwacom = super.libwacom.overrideAttrs (oldAttrs: {
            patches = oldAttrs.patches or [ ]
              ++ (map (name: ./pkgs/libwacom/patches + "/${name}")
                (builtins.attrNames (lib.filterAttrs (k: v: v == "regular")
                  (builtins.readDir ./pkgs/libwacom/patches))));
          });
        };
      })
      # not sure why this isn't the default, KPXC has it as their default
      (self: super: {
        keepassxc = super.keepassxc.override { withKeePassNetworking = true; };
      })
      (self: super: {
        linux_4_19 = super.linux_4_19.override {
          extraConfig = ''
            SERIAL_DEV_BUS y
            SERIAL_DEV_CTRL_TTYPORT y
            SURFACE_SAM y
            SURFACE_SAM_SSH m
            SURFACE_SAM_SAN m
            SURFACE_SAM_VHF m
            SURFACE_SAM_DTX m
            SURFACE_SAM_SID n
            INPUT_SOC_BUTTON_ARRAY m
            INTEL_IPTS m
            INTEL_IPTS_SURFACE m
            MWLWIFI n
          '';
          # ignoreConfigErrors = true;
        };
      })
    ];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.wireless.networks = {
  #   eduroam = {
  #     auth = ''
  #       key_mgmt=WPA-EAP
  #       eap=PEAP
  #       identity="user@example.com"
  #       password="secret"
  #     '';
  #   };
  # };
  networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n = {
    # consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   hplip # python27Packages.dbus-python dbus
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [
      22000 # syncthing transfer
    ];
    allowedUDPPorts = [
      21027 # syncthing discovery
    ];
  };

  services = {
    # Enable CUPS to print documents.
    # printing = {
    #   enable = true;
    #   drivers = [ pkgs.hplipWithPlugin ]; # FIXME hp-setup not working
    # };

    # emacs = {
    #   enable = true;
    #   package = with pkgs;
    #     ((emacsPackagesNgGen emacs).emacsWithPackages (epkgs: [
    #       epkgs.emacs-libvterm
    #     ]));
    # };
  };

  # users.mutableUsers = false;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lh = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "lp" ];
  };

  home-manager.useUserPackages = true;
  home-manager.users.lh = { config, pkgs, ... }: {
    nixpkgs.config.allowUnfree = true;
    home.packages = with pkgs; [
      gnumake
      gnutls # for circe
      zip
      unzip
      socat # detach processes

      shellcheck # check shell scripts for syntax and semantics
      nix-diff
      nixfmt # format nix files

      wget # file download CLI
      youtube-dl # video download CLI
      rclone # multiplatform cloud sync CLI

      texlive.combined.scheme-medium # latex environment
      pandoc # convert document formats
      fio # disk benchmarking
      python3

      nnn # TUI file manager
      htop # system monitoring TUI
      ncdu # disk management TUI
    ];

    programs = {
      # Let Home Manager install and manage itself.
      home-manager.enable = true;

      bash = {
        enable = true;
        sessionVariables = {
          # add .local/bin/ and all subdirectories to path
          PATH = ''
            $PATH:$HOME/.emacs.d/bin/:$(du "$HOME/.local/bin/" | cut -f2 | tr '\n' ':' | sed 's/:*$//')
          '';
          # fall back to emacs if no emacs server
          EDITOR = "emacsclient -ca emacs";
          TERMINAL = "alacritty";
          BROWSER = "firefox";
          READER = "zathura";
          FILE = "nnn";
          # use this variable in scripts to generalize dmenu, rofi, etc
          MENU = "rofi -dmenu";
          SUDO_ASKPASS = "$HOME/.local/bin/tools/menupass";

          # GTK2_RC_FILES = "$HOME/.config/gtk-2.0/gtkrc-2.0";
          # for adwaita-qt
          QT_STYLE_OVERRIDE = "Adwaita-Dark";

          # https://www.topbug.net/blog/2016/09/27/make-gnu-less-more-powerful/
          LESS =
            "--quit-if-one-screen --ignore-case --status-column --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=4 --no-init --window=-2";
          # less colors
          # https://unix.stackexchange.com/questions/119/colors-in-man-pages/147#147
          # https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
          LESS_TERMCAP_mb = "$(tput bold; tput setaf 2)"; # green
          LESS_TERMCAP_md = "$(tput bold; tput setaf 6)"; # cyan
          LESS_TERMCAP_me = "$(tput sgr0)";
          LESS_TERMCAP_so =
            "$(tput bold; tput setaf 3; tput setab 4)"; # yellow on blue
          LESS_TERMCAP_se = "$(tput rmso; tput sgr0)";
          LESS_TERMCAP_us = "$(tput smul; tput bold; tput setaf 7)"; # white
          LESS_TERMCAP_ue = "$(tput rmul; tput sgr0)";
          LESS_TERMCAP_mr = "$(tput rev)";
          LESS_TERMCAP_mh = "$(tput dim)";
          LESS_TERMCAP_ZN = "$(tput ssubm)";
          LESS_TERMCAP_ZV = "$(tput rsubm)";
          LESS_TERMCAP_ZO = "$(tput ssupm)";
          LESS_TERMCAP_ZW = "$(tput rsupm)";
        };
        shellOptions = [
          # Append to history file rather than replacing
          "histappend"
          # extended globbing
          "extglob"
          "globstar"
          # warn if closing shell with running jobs
          "checkjobs"
          # cd by typing directory name alone
          "autocd"
        ];
        shellAliases = {
          pg = "pgrep";
          pk = "pkill";
          mkd = "mkdir -pv";
          mpv = "mpv --input-ipc-server=/tmp/mpvsoc$(date +%s)";
          nrs = "sudo nixos-rebuild switch";
          nrsu = "sudo nixos-rebuild switch --upgrade";
          nrb = "sudo nixos-rebuild boot";
          nrt = "sudo nixos-rebuild test";
          SS = "sudo systemctl";
          dots = "git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
          f = "$FILE";
          trem = "transmission-remote";
          e = "$EDITOR";
          x = "sxiv -ft *";
          sdn = "sudo shutdown -h now";
          ls = "ls -hN --color=auto --group-directories-first";
          grep = "grep --color=auto";
          diff = "diff --color";
          yt =
            "youtube-dl --add-metadata -i -o '%(upload_date)s-%(title)s.%(ext)s'";
          yta = "yt -x -f bestaudio/best";
          ffmpeg = "ffmpeg -hide_banner";
          ffplay = "ffplay -hide_banner";
          ffprobe = "ffprobe -hide_banner";
        };
        initExtra = ''
          stty -ixon # disable ctrl-s and ctrl-q
          # https://wiki.archlinux.org/index.php/Bash/Prompt_customization
          export PS1=export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 4)\]\h \[$(tput setaf 5)\]\W\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\\$ \[$(tput sgr0)\]"
        '';
      };

      neovim.enable = true;

      emacs = {
        enable = true;
        extraPackages = epkgs: [ epkgs.emacs-libvterm ];
      };

      git = {
        enable = true;
        userName = "hpfr";
        userEmail = "44043764+hpfr@users.noreply.github.com";
      };
    };

    services.syncthing.enable = true;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?
}
