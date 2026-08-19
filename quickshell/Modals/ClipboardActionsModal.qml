pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property bool loading: false
    property var detail: null
    property string errorText: ""
    property var matchedActions: []
    property int selectedIndex: 0

    readonly property int rowHeight: 52
    readonly property int maxListHeight: 340

    function show() {
        loading = true;
        detail = null;
        errorText = "";
        matchedActions = [];
        selectedIndex = 0;
        open();
        ClipboardActionsService.fetchCurrent(function (result, error) {
            root.loading = false;
            if (!result) {
                root.detail = null;
                root.errorText = error || I18n.tr("Clipboard has no text content");
                root.matchedActions = [];
                return;
            }
            root.detail = result;
            root.errorText = "";
            root.matchedActions = ClipboardActionsService.actionsFor(result);
            root.selectedIndex = 0;
        });
    }

    function hide() {
        close();
    }

    function toggle() {
        if (shouldBeVisible)
            hide();
        else
            show();
    }

    function activate(index) {
        if (index < 0 || index >= matchedActions.length)
            return;
        const action = matchedActions[index];
        const target = detail;
        close();
        ClipboardActionsService.run(action, target);
    }

    function openSettings() {
        close();
        PopoutService.settingsModal?.showWithTabName("clipboard-actions");
    }

    layerNamespace: "dms:clipboard-actions"
    objectName: "clipboardActionsModal"
    shouldBeVisible: false
    allowStacking: true
    shouldHaveFocus: true
    enableShadow: true
    modalWidth: 480
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingL * 2 : 200

    onBackgroundClicked: close()
    onOpened: {
        Qt.callLater(function () {
            modalFocusScope.forceActiveFocus();
            modalFocusScope.focus = true;
            root.shouldHaveFocus = true;
        });
    }

    modalFocusScope.Keys.onPressed: function (event) {
        const count = root.matchedActions.length;

        switch (event.key) {
        case Qt.Key_Escape:
            root.close();
            event.accepted = true;
            return;
        case Qt.Key_Down:
            if (count > 0)
                root.selectedIndex = (root.selectedIndex + 1) % count;
            event.accepted = true;
            return;
        case Qt.Key_Up:
            if (count > 0)
                root.selectedIndex = (root.selectedIndex - 1 + count) % count;
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activate(root.selectedIndex);
            event.accepted = true;
            return;
        }

        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            root.activate(event.key - Qt.Key_1);
            event.accepted = true;
        }
    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "content_paste_go"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Clipboard Actions")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width
                    height: previewRow.implicitHeight + Theme.spacingM
                    radius: Theme.cornerRadius
                    color: Theme.floatingWindowFieldColor
                    visible: root.detail !== null

                    Row {
                        id: previewRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        Rectangle {
                            id: typeChip
                            anchors.verticalCenter: parent.verticalCenter
                            width: typeChipText.implicitWidth + Theme.spacingM
                            height: 22
                            radius: height / 2
                            color: Theme.withAlpha(Theme.primary, 0.16)

                            StyledText {
                                id: typeChipText
                                anchors.centerIn: parent
                                text: ClipboardActionsService.groupLabel(root.detail?.type ?? "text")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                            }
                        }

                        DankColorSwatch {
                            id: previewSwatch
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            visible: (root.detail?.color ?? "").startsWith("#")
                            swatchColor: visible ? root.detail.color : "transparent"
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - typeChip.width - (previewSwatch.visible ? previewSwatch.width + Theme.spacingS : 0) - Theme.spacingS * 2
                            text: (root.detail?.text ?? "").replace(/\s+/g, " ")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 60
                    visible: root.loading

                    DankSpinner {
                        anchors.centerIn: parent
                        size: 28
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !root.loading && root.errorText.length > 0
                    text: root.errorText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    visible: !root.loading && root.errorText.length === 0 && root.matchedActions.length === 0
                    text: I18n.tr("No actions match this clipboard content")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankFlickable {
                    width: parent.width
                    visible: root.matchedActions.length > 0
                    height: visible ? Math.min(root.maxListHeight, actionColumn.implicitHeight) : 0
                    contentWidth: width
                    contentHeight: actionColumn.implicitHeight
                    clip: true

                    Column {
                        id: actionColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.matchedActions

                            delegate: Rectangle {
                                id: actionRow

                                required property int index
                                required property var modelData

                                width: actionColumn.width
                                height: root.rowHeight
                                radius: Theme.cornerRadius
                                color: root.selectedIndex === index ? Theme.primaryHover : (actionMouse.containsMouse ? Theme.surfacePressed : Theme.floatingWindowFieldColor)
                                border.width: root.selectedIndex === index ? 1 : 0
                                border.color: root.selectedIndex === index ? Theme.primary : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: actionRow.modelData?.icon?.value || "bolt"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.iconSize - shortcutHint.width - Theme.spacingM * 2
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: ClipboardActionsService.actionLabel(actionRow.modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: ClipboardActionsService.preview(actionRow.modelData, root.detail)
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledText {
                                        id: shortcutHint
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: actionRow.index < 9
                                        text: visible ? String(actionRow.index + 1) : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selectedIndex = actionRow.index
                                    onClicked: root.activate(actionRow.index)
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - configureButton.width - Theme.spacingS
                        text: I18n.tr("Enter to run, 1-9 to pick, Esc to close")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }

                    DankButton {
                        id: configureButton
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Configure")
                        iconName: "settings"
                        onClicked: root.openSettings()
                    }
                }
            }
        }
    }
}
