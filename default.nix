{ pkgs, lib, config, ... }:

let
  cfg = config.hardware.nvidia.vgpu;

  vgpuVersion = "550.54.14";
  gridVersion = "550.54.14";
in
{
  options = {
    hardware.nvidia.vgpu = {
      enable = lib.mkEnableOption "vGPU support";

      unlock.enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Unlock vGPU functionality for consumer grade GPUs";
      };
    };
  };

  config = lib.mkIf cfg.enable rec {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
      { postInstall ? "", ... }@attrs: {
        name = "nvidia-x11-${vgpuVersion}-${gridVersion}-${config.boot.kernelPackages.kernel.version}";
        version = "${vgpuVersion}";

        src = lib.fetchurl {
          urls = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/vGPU17.0/NVIDIA-Linux-x86_64-${gridVersion}-grid.run";
          sha256 = "1qwrij3h3hbkwpdslpyp1navp9jz9ik0xx5k9ni4biafw4bv2702";
        };

        postInstall = postInstall + ''
          if [ -n "$bin" ]; then
              # Install the programs.
              for i in nvidia-gridd nvidia-topologyd; do
                  if [ -e "$i" ]; then
                      install -Dm755 $i $bin/bin/$i
                      # unmodified binary backup for mounting in containers
                      install -Dm755 $i $bin/origBin/$i
                      patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                          --set-rpath $out/lib:$libPath $bin/bin/$i
                  fi
              done
          fi
        '';
      }
    );

    systemd.services."nvidia-gridd" = {
      description = "NVIDIA Grid Daemon";
      wantedBy = [ "multi-user.target" ];
      unitConfig.After = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = "${hardware.nvidia.package.bin}/bin/nvidia-gridd --verbose";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-gridd";
      };
    };
  };
}
