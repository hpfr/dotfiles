{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.system.gnome;
in {
  options.profiles.system.gnome.enable =
    mkEnableOption "my system-level GNOME base configuration";

  config = mkIf cfg.enable {
    profiles.system.wayland-base.enable = true;
    services.xserver.desktopManager.gnome.enable = true;

    # Disable gnome-keyring entirely in favor of KeePassXC
    services.gnome.gnome-keyring.enable = lib.mkForce false;

    qt5 = {
      style = "adwaita-dark";
      platformTheme = "gnome";
    };

    environment = {
      systemPackages = with pkgs; [ gnome.gnome-tweaks ];
      gnome.excludePackages = with pkgs.gnome; [
        epiphany # firefox, chromium
        gedit # emacs for text editing
        geary # emacs for mail
        totem # mpv/celluloid for media
        gnome-music # spotify/mpd+emacs
        simple-scan # I don't have a scanner
        gnome-terminal # foot
        pkgs.gnome-connections # remmina
        pkgs.gnome-photos # nomacs
      ];
    };
  };
}
