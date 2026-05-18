{
  name = "ifstate-hooks";

  nodes = {
    server = {
      imports = [ ../../modules/profiles/minimal.nix ];
      virtualisation.interfaces.eth1.vlan = 1;

      networking.ifstate = {
        enable = true;
        settings.interfaces.eth1 = {
          addresses = [ "192.168.44.1/24" ];
          link = {
            state = "up";
            kind = "physical";
          };
        };
      };

      services.dnsmasq = {
        enable = true;
        settings = {
          interface = "eth1";
          dhcp-range = [ "192.168.44.100,192.168.44.200,12h" ];
        };
      };

      networking.firewall.allowedUDPPorts = [ 67 ];
    };
    client = { lib, pkgs, ... }: {
      imports = [ ../../modules/profiles/minimal.nix ];
      virtualisation.interfaces.eth1.vlan = 1;

      networking.ifstate = {
        enable = true;
        hooks = {
          dhcp = {
            description = "DHCP Client";
            systemdProps = { };
            command = [
              (lib.getExe' pkgs.busybox "udhcpc")
            ]
            ++ (lib.cli.toCommandLineGNU { } {
              i = "$IFS_IFNAME";
              f = true;
              script = lib.getExe (
                pkgs.writeShellApplication {
                  name = "udhcpc-script";
                  # iproute2 before busybox, so we dont use busybox ip
                  runtimeInputs = with pkgs; [
                    iproute2
                    busybox
                    systemd
                  ];
                  text = builtins.readFile ./udhcpc.script;
                }
              );
            });
          };
        };
        settings.interfaces.eth1 = {
          hooks = [ { name = "dhcp"; } ];
          link = {
            state = "up";
            kind = "physical";
          };
        };
      };

      services.resolved.enable = true;
    };
  };

  testScript = # python
    ''
      start_all()

      server.wait_for_unit("default.target")
      client.wait_for_unit("default.target")

      client.wait_until_succeeds("ping -c 1 192.168.44.1")
    '';
}
