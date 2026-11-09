#!/bin/sh
# Install or upgrade the Screen Rotate plasmoid for the current user.
set -e
cd "$(dirname "$0")"
ID=com.github.amrutlabs-linux.screenrotate
if kpackagetool6 -t Plasma/Applet -s "$ID" >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
echo "Installed. Right-click your panel → Add Widgets… → search \"Screen Rotate\"."

