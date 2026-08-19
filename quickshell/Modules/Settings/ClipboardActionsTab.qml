pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var operatorOptions: ClipboardActionsService.operators

    function actionsIn(group) {
        const all = SettingsData.clipboardActions || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if ((all[i].group || "text") === group)
                out.push({
                    "action": all[i],
                    "index": i
                });
        }
        return out;
    }

    function operatorLabel(value) {
        for (let i = 0; i < operatorOptions.length; i++) {
            if (operatorOptions[i].value === value)
                return operatorOptions[i].label;
        }
        return operatorOptions[1].label;
    }

    function operatorValue(label) {
        for (let i = 0; i < operatorOptions.length; i++) {
            if (operatorOptions[i].label === label)
                return operatorOptions[i].value;
        }
        return "includes";
    }

    function placeholderHint(group) {
        switch (group) {
        case "color":
            return "${clipboard}  ${color}  ${type}";
        case "path":
            return "${clipboard}  ${path}  ${ext}  ${basename}  ${dirname}  ${type}";
        default:
            return "${clipboard}  ${type}";
        }
    }

    function commandPlaceholder(group) {
        switch (group) {
        case "url":
            return "yt-dlp ${clipboard}";
        case "color":
            return "notify-send ${color}";
        case "path":
            return "mpv ${path}";
        default:
            return "notify-send ${clipboard}";
        }
    }

    component ActionDelegate: Rectangle {
        id: actionDelegate

        required property var modelData

        readonly property var action: modelData.action
        readonly property int actionIndex: modelData.index
        readonly property string group: action.group || "text"

        width: parent?.width ?? 0
        height: actionColumn.implicitHeight + Theme.spacingM
        radius: Theme.cornerRadius
        color: Theme.floatingWindowFieldColor

        Column {
            id: actionColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankIconPicker {
                    id: iconPicker
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130

                    Component.onCompleted: {
                        const icon = actionDelegate.action.icon;
                        if (icon?.value)
                            setIcon(icon.value, icon.type || "material");
                    }

                    onIconSelected: (iconName, iconType) => {
                        SettingsData.updateClipboardActionField(actionDelegate.actionIndex, "icon", {
                            "type": iconType,
                            "value": iconName
                        });
                        setIcon(iconName, iconType);
                    }
                }

                DankTextField {
                    id: nameField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - iconPicker.width - enableToggle.width - deleteButton.width - Theme.spacingS * 3
                    text: actionDelegate.action.name || ""
                    font.pixelSize: Theme.fontSizeSmall
                    placeholderText: I18n.tr("Action name")
                    onEditingFinished: SettingsData.updateClipboardActionField(actionDelegate.actionIndex, "name", text)
                }

                DankToggle {
                    id: enableToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 24
                    hideText: true
                    checked: actionDelegate.action.enabled !== false
                    onToggled: checked => SettingsData.updateClipboardActionField(actionDelegate.actionIndex, "enabled", checked)
                }

                Item {
                    id: deleteButton
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.withAlpha(Theme.error, 0)
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "delete"
                        size: 18
                        color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: deleteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsData.removeClipboardAction(actionDelegate.actionIndex)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXXS
                visible: actionDelegate.group === "path"

                StyledText {
                    text: I18n.tr("Extensions")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    width: parent.width
                    text: actionDelegate.action.extensions || ""
                    font.pixelSize: Theme.fontSizeSmall
                    placeholderText: I18n.tr("mp4, mkv, webm - leave empty for any")
                    onEditingFinished: SettingsData.updateClipboardActionField(actionDelegate.actionIndex, "extensions", text)
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXXS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        id: conditionsLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Filters")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                    }

                    Item {
                        width: Math.max(0, parent.width - conditionsLabel.implicitWidth - addConditionButton.width - Theme.spacingS * 2)
                        height: 1
                    }

                    DankActionButton {
                        id: addConditionButton
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: 26
                        iconName: "add"
                        iconSize: 16
                        iconColor: Theme.primary
                        onClicked: SettingsData.addClipboardActionCondition(actionDelegate.actionIndex)
                    }
                }

                StyledText {
                    width: parent.width
                    visible: (actionDelegate.action.conditions || []).length === 0
                    text: I18n.tr("No filters - matches any %1 content").arg(ClipboardActionsService.groupLabel(actionDelegate.group).toLowerCase())
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    font.italic: true
                }

                Repeater {
                    model: actionDelegate.action.conditions || []

                    delegate: Row {
                        id: conditionRow

                        required property int index
                        required property var modelData

                        readonly property bool needsValue: (modelData.op || "includes") !== "any"

                        width: actionColumn.width - Theme.spacingS * 2
                        spacing: Theme.spacingS

                        DankDropdown {
                            id: opDropdown
                            anchors.verticalCenter: parent.verticalCenter
                            width: 150
                            compactMode: true
                            dropdownWidth: width
                            popupWidth: 180
                            currentValue: root.operatorLabel(conditionRow.modelData.op || "includes")
                            options: root.operatorOptions.map(o => o.label)
                            onValueChanged: value => SettingsData.updateClipboardActionConditionField(actionDelegate.actionIndex, conditionRow.index, "op", root.operatorValue(value))
                        }

                        DankTextField {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, parent.width - opDropdown.width - caseToggle.width - conditionDelete.width - Theme.spacingS * 3)
                            enabled: conditionRow.needsValue
                            opacity: enabled ? 1 : 0.5
                            text: conditionRow.modelData.value || ""
                            font.pixelSize: Theme.fontSizeSmall
                            placeholderText: I18n.tr("Value")
                            onEditingFinished: SettingsData.updateClipboardActionConditionField(actionDelegate.actionIndex, conditionRow.index, "value", text)
                        }

                        DankActionButton {
                            id: caseToggle
                            anchors.verticalCenter: parent.verticalCenter
                            buttonSize: 26
                            iconName: "match_case"
                            iconSize: 16
                            enabled: conditionRow.needsValue
                            iconColor: conditionRow.modelData.caseSensitive === true ? Theme.primary : Theme.surfaceVariantText
                            tooltipText: I18n.tr("Case sensitive")
                            onClicked: SettingsData.updateClipboardActionConditionField(actionDelegate.actionIndex, conditionRow.index, "caseSensitive", conditionRow.modelData.caseSensitive !== true)
                        }

                        DankActionButton {
                            id: conditionDelete
                            anchors.verticalCenter: parent.verticalCenter
                            buttonSize: 26
                            iconName: "close"
                            iconSize: 16
                            iconColor: Theme.surfaceVariantText
                            onClicked: SettingsData.removeClipboardActionCondition(actionDelegate.actionIndex, conditionRow.index)
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXXS

                StyledText {
                    text: I18n.tr("Command")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    width: parent.width
                    text: actionDelegate.action.command || ""
                    font.pixelSize: Theme.fontSizeSmall
                    placeholderText: root.commandPlaceholder(actionDelegate.group)
                    onEditingFinished: SettingsData.updateClipboardActionField(actionDelegate.actionIndex, "command", text)
                }

                StyledText {
                    width: parent.width
                    text: root.placeholderHint(actionDelegate.group)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component GroupBody: Column {
        id: groupBody

        property string group: "text"

        width: parent?.width ?? 0
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            visible: root.actionsIn(groupBody.group).length === 0
            text: I18n.tr("No actions yet. Use + to add one.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            font.italic: true
        }

        Repeater {
            model: root.actionsIn(groupBody.group)

            delegate: ActionDelegate {}
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(650, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "clipboardActions"
                tags: ["clipboard", "actions", "script", "run", "command"]
                settingKey: "clipboardActionsIntro"
                title: I18n.tr("How it works")
                iconName: "info"

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Actions never run on their own. Open the action runner and it reads the current clipboard, works out whether it is a URL, a color, a path or plain text, and lists only the actions whose filters match.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Open it with: %1").arg("dms ipc call clipboard-actions toggle")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Clipboard values are passed to the command as arguments, so they are never interpreted as shell syntax.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SettingsCard {
                id: urlCard
                tab: "clipboardActions"
                tags: ["clipboard", "actions", "url", "link", "download"]
                settingKey: "clipboardActionsUrl"
                title: I18n.tr("URL")
                iconName: "link"
                collapsible: true
                expanded: false

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        iconColor: Theme.primary
                        onClicked: {
                            SettingsData.addClipboardAction("url");
                            urlCard.userToggledCollapse = true;
                            urlCard.expanded = true;
                        }
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Offered when the clipboard holds a link, such as https://, mailto: or magnet:.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        bottomPadding: Theme.spacingS
                    }

                    GroupBody {
                        group: "url"
                    }
                }
            }

            SettingsCard {
                id: colorCard
                tab: "clipboardActions"
                tags: ["clipboard", "actions", "color", "hex", "rgb"]
                settingKey: "clipboardActionsColor"
                title: I18n.tr("Color")
                iconName: "palette"
                collapsible: true
                expanded: false

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        iconColor: Theme.primary
                        onClicked: {
                            SettingsData.addClipboardAction("color");
                            colorCard.userToggledCollapse = true;
                            colorCard.expanded = true;
                        }
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Offered when the clipboard holds a color, such as #ff0080, rgb(...) or hsl(...).")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        bottomPadding: Theme.spacingS
                    }

                    GroupBody {
                        group: "color"
                    }
                }
            }

            SettingsCard {
                id: pathCard
                tab: "clipboardActions"
                tags: ["clipboard", "actions", "path", "file", "extension"]
                settingKey: "clipboardActionsPath"
                title: I18n.tr("Path & File")
                iconName: "folder"
                collapsible: true
                expanded: false

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        iconColor: Theme.primary
                        onClicked: {
                            SettingsData.addClipboardAction("path");
                            pathCard.userToggledCollapse = true;
                            pathCard.expanded = true;
                        }
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Offered when the clipboard holds a filesystem path or a file:// URI.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        bottomPadding: Theme.spacingS
                    }

                    GroupBody {
                        group: "path"
                    }
                }
            }

            SettingsCard {
                id: textCard
                tab: "clipboardActions"
                tags: ["clipboard", "actions", "text", "string"]
                settingKey: "clipboardActionsText"
                title: I18n.tr("Text")
                iconName: "text_fields"
                collapsible: true
                expanded: false

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        iconColor: Theme.primary
                        onClicked: {
                            SettingsData.addClipboardAction("text");
                            textCard.userToggledCollapse = true;
                            textCard.expanded = true;
                        }
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Offered for anything that is not a URL, a color or a path.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        bottomPadding: Theme.spacingS
                    }

                    GroupBody {
                        group: "text"
                    }
                }
            }
        }
    }
}
