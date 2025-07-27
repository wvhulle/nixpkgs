{
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "logitech-udev-rules";
  version = "1.0.0";

  src = ./.;

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    
    install -D -m 644 ${./42-logitech-unify-permissions.rules} $out/lib/udev/rules.d/42-logitech-unify-permissions.rules
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Udev rules for Logitech Unifying receivers and devices";
    longDescription = ''
      This package provides udev rules for Logitech Unifying receivers and devices,
      enabling user access to Logitech wireless mice, keyboards, and other peripherals
      without requiring root privileges. Compatible with Solaar and similar tools.
    '';
    homepage = "https://pwr-solaar.github.io/Solaar/";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ]; # Add your name here
  };
}