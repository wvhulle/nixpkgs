{
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "microbit-udev-rules";
  version = "1.0.0";

  src = ./.;

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    
    install -D -m 644 ${./69-microbit.rules} $out/lib/udev/rules.d/69-microbit.rules
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Udev rules for BBC micro:bit development board";
    longDescription = ''
      This package provides udev rules for the BBC micro:bit development board,
      enabling CMSIS-DAP access for programming and debugging without requiring
      root privileges.
    '';
    homepage = "https://microbit.org/";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ]; # Add your name here
  };
}