# kde-screenrotate – Screen Rotate widget for KDE Plasma 6

Rotate your screen from the panel. Uses `kscreen-doctor` (ships with Plasma), works on Wayland and X11.

## Install

1. Clone the repository and run the installer:

   ```sh
   git clone https://github.com/amrutlabs-linux/kde-screenrotate.git
   cd kde-screenrotate
   ./install.sh
   ```

2. Add the widget to your panel:
   1. Right-click the desktop or the panel and choose **Enter Edit Mode**.
   2. Click **Add Widgets…** at the top of the screen.
   3. Search for **Screen Rotate**.
   4. Drag the widget onto your panel and drop it where you want the icon.
   5. Click **Exit Edit Mode** (or press <kbd>Esc</kbd>).

## Usage
- **Left click** – cycle / toggle / open popup (configurable)
- **Middle click** – reset to normal (configurable)
- **Scroll** over the icon – rotate clockwise / counter-clockwise
- **Right click** – Rotate Clockwise, Rotate Counter-Clockwise, Reset to Normal
- **Global shortcut** – set one in the widget settings → Keyboard Shortcuts

## Settings
- Screen to rotate: primary, all, or a specific output
- Allowed orientations: Normal, 90° clockwise, upside down, 90° counter-clockwise
- Left-click action, cycle direction, toggle pair, middle-click action, scroll on/off
- Custom icon, rotate the panel icon with the screen, on-screen notification

## Uninstall
    kpackagetool6 -t Plasma/Applet -r com.github.amrutlabs-linux.screenrotate
