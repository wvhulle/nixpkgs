{
  lib,
  stdenv,
  makeWrapper,
  bun,
}:

stdenv.mkDerivation rec {
  pname = "ccusage";
  version = "15.9.1";

  dontUnpack = true;
  
  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    bun
  ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    makeWrapper ${bun}/bin/bunx $out/bin/ccusage \
      --add-flags "ccusage"
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI tool for analyzing Claude Code token usage and costs";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
    mainProgram = "ccusage";
  };
}