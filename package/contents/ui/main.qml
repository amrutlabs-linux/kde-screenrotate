/*
 * Screen Rotate – KDE Plasma 6 panel widget
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ---------------------------------------------------------------
    // Orientation model. KScreen semantics: "left" = 90° clockwise,
    // "right" = 90° counter-clockwise (same as System Settings › Display).
    // Listed in clockwise order.
    // ---------------------------------------------------------------
    readonly property var orientations: [
        { key: "none",     value: 1, angle: 0,   label: i18n("Normal"),               icon: "go-up" },
        { key: "left",     value: 2, angle: 90,  label: i18n("90° Clockwise"),        icon: "go-next" },
        { key: "inverted", value: 4, angle: 180, label: i18n("Upside Down"),          icon: "go-down" },
        { key: "right",    value: 8, angle: 270, label: i18n("90° Counter-Clockwise"), icon: "go-previous" }
    ]

    readonly property var cfg: Plasmoid.configuration

    // Live state from kscreen-doctor
    property var outputs: []            // [{id, name, rotation, priority}]
    property string currentKey: "none"
    property bool busy: false
    property string lastError: ""

    readonly property var targetOutputs: {
        if (outputs.length === 0) return [];
        if (cfg.outputName === "*") return outputs;
        if (cfg.outputName !== "") {
            const match = outputs.filter(o => o.name === cfg.outputName);
            if (match.length > 0) return match;
        }
        // primary = lowest priority number
        const sorted = outputs.slice().sort((a, b) => a.priority - b.priority);
        return [sorted[0]];
    }

    readonly property var enabledKeys: {
        const list = [];
        if (cfg.enableNone) list.push("none");
        if (cfg.enableLeft) list.push("left");
        if (cfg.enableInverted) list.push("inverted");
        if (cfg.enableRight) list.push("right");
        return list.length > 0 ? list : ["none"];
    }

    function orientationFor(key) {
        for (let i = 0; i < orientations.length; ++i)
            if (orientations[i].key === key) return orientations[i];
        return orientations[0];
    }
    function keyForValue(value) {
        for (let i = 0; i < orientations.length; ++i)
            if (orientations[i].value === value) return orientations[i].key;
        return "none";
    }
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // ---------------------------------------------------------------
    // Command execution
    // ---------------------------------------------------------------
    readonly property string queryCmd: "kscreen-doctor -j"

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const stdout = data["stdout"] || "";
            const stderr = data["stderr"] || "";
            const exitCode = data["exit code"];
            disconnectSource(sourceName);

            if (sourceName === root.queryCmd) {
                root.parseOutputs(stdout);
            } else {
                root.busy = false;
                if (exitCode !== 0) {
                    root.lastError = (stderr || stdout).trim() || i18n("kscreen-doctor failed");
                } else {
                    root.lastError = "";
                }
                refreshTimer.restart();
            }
        }

        function exec(cmd) {
            if (connectedSources.indexOf(cmd) !== -1) return;
            connectSource(cmd);
        }
    }

    function refresh() {
        executable.exec(queryCmd);
    }

    function parseOutputs(json) {
        try {
            const data = JSON.parse(json);
            const list = [];
            (data.outputs || []).forEach(o => {
                if (o.connected && o.enabled)
                    list.push({ id: o.id, name: o.name, rotation: o.rotation, priority: o.priority || 99 });
            });
            outputs = list;
            if (targetOutputs.length > 0)
                currentKey = keyForValue(targetOutputs[0].rotation);
        } catch (e) {
            lastError = i18n("Could not read screen configuration");
        }
    }

    function rotateTo(key) {
        if (busy || targetOutputs.length === 0) return;
        const args = targetOutputs.map(o => shellQuote("output." + o.name + ".rotation." + key));
        let cmd = "kscreen-doctor " + args.join(" ");
        if (cfg.showOsd) {
            const o = orientationFor(key);
            cmd += " && { gdbus call --session --dest org.kde.plasmashell --object-path /org/kde/osdService"
                 + " --method org.kde.osdService.showText " + shellQuote(cfg.iconName || "object-rotate-right")
                 + " " + shellQuote(o.label) + " >/dev/null 2>&1; true; }";
        }
        busy = true;
        currentKey = key; // optimistic
        executable.exec(cmd);
    }

    function step(direction) {
        // direction: +1 clockwise, -1 counter-clockwise
        const keys = enabledKeys;
        let idx = keys.indexOf(currentKey);
        if (idx === -1) {
            // current orientation not enabled: pick next enabled one by angle
            const curAngle = orientationFor(currentKey).angle;
            const sorted = keys.slice().sort((a, b) => orientationFor(a).angle - orientationFor(b).angle);
            const next = direction > 0
                ? (sorted.find(k => orientationFor(k).angle > curAngle) || sorted[0])
                : (sorted.slice().reverse().find(k => orientationFor(k).angle < curAngle) || sorted[sorted.length - 1]);
            rotateTo(next);
            return;
        }
        idx = (idx + direction + keys.length) % keys.length;
        rotateTo(keys[idx]);
    }

    function cycle() {
        step(cfg.cycleDirection === 1 ? -1 : 1);
    }

    function toggle() {
        rotateTo(currentKey === cfg.toggleFirst ? cfg.toggleSecond : cfg.toggleFirst);
    }

    function primaryAction() {
        switch (cfg.clickAction) {
        case 1: toggle(); break;
        case 2: root.expanded = !root.expanded; break;
        default: cycle(); break;
        }
    }

    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: root.refresh()
    }

    // Periodic poll so external changes (System Settings, auto-rotate) show up
    Timer {
        interval: root.expanded ? 2000 : 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
    onExpandedChanged: if (expanded) refresh()

    // ---------------------------------------------------------------
    // Plasmoid setup
    // ---------------------------------------------------------------
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Screen Rotate")
    toolTipSubText: {
        if (lastError) return lastError;
        const names = targetOutputs.map(o => o.name).join(", ");
        let s = i18n("Current: %1", orientationFor(currentKey).label);
        if (names) s += "\n" + i18n("Output: %1", names);
        s += "\n" + (cfg.clickAction === 1 ? i18n("Click to toggle")
                   : cfg.clickAction === 2 ? i18n("Click to choose")
                   : i18n("Click to rotate"));
        if (cfg.scrollToRotate) s += "\n" + i18n("Scroll to rotate");
        return s;
    }
    Plasmoid.icon: cfg.iconName || "object-rotate-right"

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Rotate Clockwise")
            icon.name: "object-rotate-right"
            onTriggered: root.step(1)
        },
        PlasmaCore.Action {
            text: i18n("Rotate Counter-Clockwise")
            icon.name: "object-rotate-left"
            onTriggered: root.step(-1)
        },
        PlasmaCore.Action {
            text: i18n("Reset to Normal")
            icon.name: "edit-undo"
            onTriggered: root.rotateTo("none")
        }
    ]

    compactRepresentation: MouseArea {
        id: compact
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        property real wheelDelta: 0

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.cfg.middleClickAction === 1) root.rotateTo("none");
                else if (root.cfg.middleClickAction === 2) root.expanded = !root.expanded;
            } else {
                root.primaryAction();
            }
        }

        onWheel: wheel => {
            if (!root.cfg.scrollToRotate) { wheel.accepted = false; return; }
            wheelDelta += wheel.angleDelta.y || wheel.angleDelta.x;
            if (wheelDelta >= 120) { wheelDelta = 0; root.step(-1); }
            else if (wheelDelta <= -120) { wheelDelta = 0; root.step(1); }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: root.cfg.iconName || "object-rotate-right"
            active: compact.containsMouse
            opacity: root.busy ? 0.5 : 1
            rotation: root.cfg.rotatePanelIcon ? root.orientationFor(root.currentKey).angle : 0
            Behavior on rotation {
                RotationAnimation { duration: Kirigami.Units.longDuration; direction: RotationAnimation.Shortest }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: i18n("Screen Rotation")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Configure…")
                    onClicked: Plasmoid.internalAction("configure").trigger()
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 2

            // Screen preview
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 6

                Rectangle {
                    id: preview
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 6
                    height: Kirigami.Units.gridUnit * 4
                    radius: Kirigami.Units.smallSpacing
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 2
                    rotation: root.orientationFor(root.currentKey).angle
                    Behavior on rotation {
                        RotationAnimation { duration: Kirigami.Units.longDuration; direction: RotationAnimation.Shortest }
                    }
                    // "top" marker
                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: Kirigami.Units.smallSpacing
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width / 3
                        height: Kirigami.Units.smallSpacing
                        radius: height / 2
                        color: Kirigami.Theme.highlightColor
                    }
                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        text: "A"
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit * 1.5
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.orientationFor(root.currentKey).label
                    + (root.targetOutputs.length ? "  ·  " + root.targetOutputs.map(o => o.name).join(", ") : "")
                opacity: 0.8
                elide: Text.ElideRight
            }

            // Orientation buttons
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.orientations
                    delegate: PlasmaComponents3.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        visible: root.enabledKeys.indexOf(modelData.key) !== -1
                        text: modelData.label
                        icon.name: modelData.icon
                        checkable: true
                        checked: root.currentKey === modelData.key
                        enabled: !root.busy
                        onClicked: root.rotateTo(modelData.key)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "object-rotate-left"
                    text: i18n("Rotate Left")
                    enabled: !root.busy
                    onClicked: root.step(-1)
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "object-rotate-right"
                    text: i18n("Rotate Right")
                    enabled: !root.busy
                    onClicked: root.step(1)
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.lastError !== ""
                text: root.lastError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
            }

            Item { Layout.fillHeight: true }
        }
    }
}
