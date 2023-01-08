{
  inputs = {
    dev.url = github:defn/pkg/dev-0.0.22?dir=dev;
  };

  outputs = inputs: { main = inputs.dev.main; } // inputs.dev.main rec {
    inherit inputs;

    src = builtins.path { path = ./.; name = config.slug; };

    config = rec {
      slug = builtins.readFile ./SLUG;
      version = builtins.readFile ./VERSION;
    };

    handler = { pkgs, wrap, system, builders }: rec {
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
        ];
      };

      commands = pkgs.lib.attrsets.mapAttrs
        (name: value: (pkgs.writeShellScriptBin "this-${name}" value))
        scripts;

      scripts = {
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
