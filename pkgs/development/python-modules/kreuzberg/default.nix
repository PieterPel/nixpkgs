{
  lib,
  stdenv,
  fetchzip,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  rustc,
  cmake,
  buildPythonPackage,
  nix-update-script,
  python,
}:

let
  inherit (stdenv.hostPlatform) system;

  version = "4.0.0rc21";

  src = fetchFromGitHub {
    owner = "kreuzberg-dev";
    repo = "kreuzberg";
    rev = "v4.0.0-rc.21";
    hash = "sha256-H2NiAK0/UY4CK3hpiRSe+J9EpXFqupyVHeDQrYHAK9s=";
  };

  pdfiumMeta =
    {
      x86_64-linux = {
        url = "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/7568/pdfium-linux-x64.tgz";
        hash = "sha256-f2NovViS56JNd8lsXLAp6DPO2siISB+zCDlVXvX87uk=";
      };
      aarch64-darwin = {
        url = "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/7568/pdfium-mac-arm64.tgz";
        hash = "sha256-YAzM4iUCzX9lv1UYIuM7iX90lTsI95OXOF/v2twGaOA=";
      };
    }
    .${system} or (throw "Unsupported system for kreuzberg: ${system}");

  pdfium = fetchzip {
    inherit (pdfiumMeta) url hash;
    stripRoot = false;
  };
in
buildPythonPackage rec {
  pname = "kreuzberg";
  inherit version src;
  pyproject = true;
  sourceRoot = "${src.name}/packages/python";

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-XFOoNyCJgb6u2X8le2043gmsMS0Rsf+g+QdCnLaRpXM=";
  };

  postPatch = ''
    cp ../../Cargo.lock Cargo.lock

    if [ -e ../../.cargo/config.toml ]; then
      substituteInPlace ../../.cargo/config.toml \
        --replace "build-std = [\"panic_abort\", \"std\"]" "" \
        --replace "[unstable]" ""
    fi

    substituteInPlace ../../crates/kreuzberg-ffi/build.rs \
      --replace 'std::fs::write("kreuzberg-ffi.pc"' 'std::fs::write(&format!("{}/kreuzberg-ffi.pc", std::env::var("OUT_DIR").unwrap())' \
      --replace 'std::fs::write("kreuzberg-ffi-install.pc"' 'std::fs::write(&format!("{}/kreuzberg-ffi-install.pc", std::env::var("OUT_DIR").unwrap())'
  '';

  nativeBuildInputs = [
    cargo
    rustc
    cmake
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
    rustPlatform.rustLibSrc
  ];

  dontUseCmakeConfigure = true;

  env = {
    RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
    RUSTLIB_SRC = "${rustPlatform.rustLibSrc}";
    KREUZBERG_PDFIUM_PREBUILT = pdfium;
    CARGO_TARGET_DIR = "target";
  };

  # Build the Rust CLI and embed it in the wheel so the console script works.
  preBuild = ''
    cargo build -p kreuzberg-cli --release --features all --locked --offline

    if [ -n "''${CARGO_TARGET_DIR-}" ]; then
      target_dir=''${CARGO_TARGET_DIR}
    else
      target_dir=target
    fi

    cli_path=$(find "''${target_dir}" -type f \( -name kreuzberg -o -name kreuzberg-cli \) | head -n1)
    if [ -z "''${cli_path}" ]; then
      echo "kreuzberg CLI binary was not produced during build" >&2
      exit 1
    fi

    cli_name=$(basename "''${cli_path}")
    install -Dm755 "''${cli_path}" "kreuzberg/''${cli_name}"
    if [ "''${cli_name}" != "kreuzberg-cli" ]; then
      ln -sf "''${cli_name}" kreuzberg/kreuzberg-cli
    fi
  '';

  postInstall = ''
    for name in kreuzberg-cli kreuzberg; do
      if [ -e "$out/${python.sitePackages}/kreuzberg/$name" ]; then
        install -Dm755 "$out/${python.sitePackages}/kreuzberg/$name" "$out/bin/$name"
      fi
    done
  '';

  pythonImportsCheck = [ "kreuzberg" ];

  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "4\\.0\\.0rc.*"
    ];
  };

  meta = {
    description = "High-performance document intelligence library for Python with Rust core";
    homepage = "https://github.com/kreuzberg-dev/kreuzberg";
    changelog = "https://kreuzberg.dev/CHANGELOG/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ pelpieter ];
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
