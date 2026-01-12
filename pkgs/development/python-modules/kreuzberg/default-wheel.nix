{
  lib,
  buildPythonPackage,
  fetchPypi,
}:

buildPythonPackage rec {
  pname = "kreuzberg";
  version = "4.0.0rc21";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    python = "cp311";
    abi = "abi3";
    platform = "macosx_11_0_arm64";
    hash = "sha256-PLACEHOLDER";
  };

  dependencies = [ ];

  pythonImportsCheck = [ "kreuzberg" ];

  doCheck = false;

  meta = {
    description = "High-performance document intelligence library for Python with Rust core";
    homepage = "https://github.com/kreuzberg-dev/kreuzberg";
    changelog = "https://kreuzberg.dev/CHANGELOG/";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.unix;
  };
}
