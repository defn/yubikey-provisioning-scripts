{
  inputs = {
    dev.url = github:defn/dev/pkg-dev-0.0.9?dir=m/pkg/dev;
    gum.url = github:defn/dev/pkg-gum-0.10.0-10?dir=m/pkg/gum;
  };

  outputs = inputs: { main = inputs.dev.main; } // inputs.dev.main rec {
    inherit inputs;

    src = builtins.path { path = ./.; name = config.slug; };

    config = rec {
      slug = builtins.readFile ./SLUG;
      version = builtins.readFile ./VERSION;
    };

    handler = { pkgs, wrap, system, config, commands }: rec {
      devShell = wrap.devShell {
        devInputs = (wrap.flakeInputs ++
          pkgs.lib.attrsets.mapAttrsToList (name: value: value) commands);
      };

      defaultPackage = wrap.bashBuilder {
        inherit src;

        installPhase = ''
          mkdir $out $out/helper_scripts $out/bin
          cp helper_scripts/* $out/helper_scripts/
          cat $src/yubikey_provision.sh | sed "s#./helper_scripts#$out/helper_scripts#" > $out/bin/yubikey_provision.sh
          chmod 755 $out/bin/* $out/helper_scrpts/*
        '';

        propagatedBuildInputs = [
          pkgs.expect
        ] ++ pkgs.lib.attrsets.mapAttrsToList (name: value: value) commands;
      };

      commands = pkgs.lib.attrsets.mapAttrs
        (name: value: (pkgs.writeShellScriptBin "${name}" value))
        scripts;

      scripts = {
        yk = ''
          set -efu
          while true; do ${commands.${"yk-init"}}/bin/yk-init; done
        '';

        yk-init = ''
          set -efu;

          keys=()

          save_ifs="$IFS" 
          IFS="
          "
          for a in $(ykman list); do
            keys+=("$a")
          done

          mark "yubikeys"
          chose="$(gum choose ''${keys[@]})"
          serial="$(echo "$chose" | awk '{print $NF}')"
          keyserver_url="https://keyserver.ubuntu.com/pks/lookup?search=yk-$serial&fingerprint=on&op=index"
          key_id="$(curl -sSL "https://keyserver.ubuntu.com/pks/lookup?search=yk-$serial&fingerprint=on&op=index" | perl -ne 'print "$1" if m{sig\s+sig.*?>(\w+)<}')"

          if [[ -z "$key_id" ]]; then
            echo "ERROR: no key_id for $chose" 1>&2
            exit 0
          fi

          curl -sSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$key_id" > ".yk-$serial.asc"

          mark "importing key yk-$serial"
          gpg --import ".yk-$serial.asc"
          rm -f ".yk-$serial.asc"

          mark "list secret keys"
          gpg --list-secret-keys "yk-$serial@defn.sh"

          mark "list keys"
          gpg --list-keys "yk-$serial@defn.sh"

          echo "You chose $chose which has a serial number $serial, key_id $key_id"
        '';

        yk-info = ''
          cat s | while read -r name serial; do for b in piv oath openpgp otp ""; do ykman --device $serial $b info > yk-$name-$b.txt 2>&1; done; done 
        '';

        yk-diff = ''
          for b in piv oath openpgp otp ""; do vimdiff $(echo yk-*-$b.txt | sort); done
        '';
      };
    };
  };
}
