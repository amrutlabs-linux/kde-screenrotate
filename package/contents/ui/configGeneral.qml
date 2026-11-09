/*
 * Screen Rotate – settings page
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: page

    property alias cfg_enableNone: enableNone.checked
    property alias cfg_enableLeft: enableLeft.checked
    property alias cfg_enableInverted: enableInverted.checked
    property alias cfg_enableRight: enableRight.checked
    property alias cfg_clickAction: clickAction.currentIndex
    property alias cfg_cycleDirection: cycleDirection.currentIndex
    property string cfg_toggleFirst
    property string cfg_toggleSecond
    property alias cfg_middleClickAction: middleClickAction.currentIndex
    property alias cfg_scrollToRotate: scrollToRotate.checked
    property string cfg_outputName
    property alias cfg_showOsd: showOsd.checked
    property alias cfg_rotatePanelIcon: rotatePanelIcon.checked
    property string cfg_iconName

    // Unused defaults injected by the config system
    property var cfg_enableNoneDefault
    property var cfg_enableLeftDefault
    property var cfg_enableInvertedDefault
    property var cfg_enableRightDefault
    property var cfg_clickActionDefault
    property var cfg_cycleDirectionDefault
    property var cfg_toggleFirstDefault
    property var cfg_toggleSecondDefault
    property var cfg_middleClickActionDefault
    property var cfg_scrollToRotateDefault
    property var cfg_outputNameDefault
    property var cfg_showOsdDefault
    property var cfg_rotatePanelIconDefault
    property var cfg_iconNameDefault

    readonly property var orientationModel: [
        { key: "none",     text: i18n("Normal") },
        { key: "left",     text: i18n("90° Clockwise") },
        { key: "inverted", text: i18n("Upside Down") },
        { key: "right",    text: i18n("90° Counter-Clockwise") }
    ]
    function indexOfKey(key) {
        for (let i = 0; i < orientationModel.length; ++i)
            if (orientationModel[i].key === key) return i;
        return 0;
    }

    // ---- list connected outputs ----
    ListModel { id: outputModel }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: ["kscreen-doctor -j"]
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            outputModel.clear();
            outputModel.append({ value: "", text: i18n("Primary screen") });
            outputModel.append({ value: "*", text: i18n("All screens") });
            try {
                const json = JSON.parse(data["stdout"]);
                (json.outputs || []).forEach(o => {
                    if (o.connected)
                        outputModel.append({ value: o.name, text: o.name + (o.enabled ? "" : " " + i18n("(disabled)")) });
                });
            } catch (e) {}
            // keep a configured but currently disconnected output selectable
            let found = false;
            for (let i = 0; i < outputModel.count; ++i)
                if (outputModel.get(i).value === page.cfg_outputName) found = true;
            if (!found)
                outputModel.append({ value: page.cfg_outputName, text: page.cfg_outputName + " " + i18n("(not connected)") });
            outputCombo.syncIndex();
        }
    }

    Kirigami.FormLayout {
        // ---------------- Screen ----------------
        QQC2.ComboBox {
            id: outputCombo
            Kirigami.FormData.label: i18n("Screen to rotate:")
            model: outputModel
            textRole: "text"
            valueRole: "value"
            function syncIndex() {
                currentIndex = Math.max(0, indexOfValue(page.cfg_outputName));
            }
            onActivated: page.cfg_outputName = currentValue
        }

        Item { Kirigami.FormData.isSection: true }

        // ---------------- Orientations ----------------
        QQC2.CheckBox {
            id: enableNone
            Kirigami.FormData.label: i18n("Allowed orientations:")
            text: i18n("Normal (0°)")
        }
        QQC2.CheckBox {
            id: enableLeft
            text: i18n("90° Clockwise")
        }
        QQC2.CheckBox {
            id: enableInverted
            text: i18n("Upside Down (180°)")
        }
        QQC2.CheckBox {
            id: enableRight
            text: i18n("90° Counter-Clockwise")
        }
        QQC2.Label {
            visible: !(enableNone.checked || enableLeft.checked || enableInverted.checked || enableRight.checked)
            text: i18n("At least one orientation should be enabled.")
            color: Kirigami.Theme.negativeTextColor
        }

        Item { Kirigami.FormData.isSection: true }

        // ---------------- Behaviour ----------------
        QQC2.ComboBox {
            id: clickAction
            Kirigami.FormData.label: i18n("Left click:")
            model: [
                i18n("Cycle through allowed orientations"),
                i18n("Toggle between two orientations"),
                i18n("Open the orientation popup")
            ]
        }
        QQC2.ComboBox {
            id: cycleDirection
            Kirigami.FormData.label: i18n("Cycle direction:")
            enabled: clickAction.currentIndex === 0
            model: [i18n("Clockwise"), i18n("Counter-clockwise")]
        }
        QQC2.ComboBox {
            id: toggleFirst
            Kirigami.FormData.label: i18n("Toggle between:")
            enabled: clickAction.currentIndex === 1
            model: page.orientationModel
            textRole: "text"
            currentIndex: page.indexOfKey(page.cfg_toggleFirst)
            onActivated: page.cfg_toggleFirst = page.orientationModel[currentIndex].key
        }
        QQC2.ComboBox {
            id: toggleSecond
            Kirigami.FormData.label: i18n("and:")
            enabled: clickAction.currentIndex === 1
            model: page.orientationModel
            textRole: "text"
            currentIndex: page.indexOfKey(page.cfg_toggleSecond)
            onActivated: page.cfg_toggleSecond = page.orientationModel[currentIndex].key
        }
        QQC2.ComboBox {
            id: middleClickAction
            Kirigami.FormData.label: i18n("Middle click:")
            model: [i18n("Do nothing"), i18n("Reset to normal"), i18n("Open the orientation popup")]
        }
        QQC2.CheckBox {
            id: scrollToRotate
            Kirigami.FormData.label: i18n("Mouse wheel:")
            text: i18n("Scroll over the icon to rotate")
        }

        Item { Kirigami.FormData.isSection: true }

        // ---------------- Appearance ----------------
        QQC2.Button {
            id: iconButton
            Kirigami.FormData.label: i18n("Icon:")
            implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing * 2
            implicitHeight: implicitWidth
            onClicked: iconDialog.open()
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.large
                height: width
                source: page.cfg_iconName || "object-rotate-right"
            }
            QQC2.ToolTip.text: i18n("Click to choose a different icon")
            QQC2.ToolTip.visible: hovered
        }
        QQC2.Button {
            text: i18n("Reset icon")
            icon.name: "edit-undo"
            visible: page.cfg_iconName !== "object-rotate-right"
            onClicked: page.cfg_iconName = "object-rotate-right"
        }
        KIconThemes.IconDialog {
            id: iconDialog
            onIconNameChanged: if (iconName) page.cfg_iconName = iconName
        }
        QQC2.CheckBox {
            id: rotatePanelIcon
            text: i18n("Rotate panel icon to match the current orientation")
        }
        QQC2.CheckBox {
            id: showOsd
            text: i18n("Show on-screen notification after rotating")
        }
    }
}
