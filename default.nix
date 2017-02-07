{ nixpkgs ? import ../nixpkgs {} }:

with nixpkgs;
with pkgs;

let

  appstream-generator = stdenv.mkDerivation {
    name = "appstream-generator";
    src = ./.;
    buildInputs = [ meson ninja dmd glib pkgconfig appstream lmdb libarchive cairo gdk_pixbuf librsvg curl.dev pango mustache-d ];

    configurePhase = ''
      mkdir -p build
      cd build
      meson.py --prefix "$out" ..
    '';

    buildPhase = ''
      ninja
    '';

    installPhase = "ninja install";

    doCheck = true;
  };

  mustache-d = stdenv.mkDerivation {
    name = "mustache-d";

    src = fetchFromGitHub {
      owner = "repeatedly";
      repo = "mustache-d";
      rev = "v0.1.3";
      sha256 = "0wxkv7989aglcrq7a8fb2q1wvj2xaabanz6xajjx91w2g65l1zgc";
    };

    buildInputs = [ ninja meson dmd ];

    configurePhase = ''
      mkdir -p build
      cd build
      meson.py --prefix "$out" ..
    '';

    buildPhase = "ninja";

    installPhase = "ninja install";
  };

in appstream-generator
