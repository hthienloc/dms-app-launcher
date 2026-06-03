import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import "./dms-common"

Popup {
    id: managePopup
    
    // Bridge to main widget
    required property var rootWidget
    
    width: Math.min(400, rootWidget.width - 20)
    height: Math.min(500, rootWidget.height - 20)
    x: Math.round((rootWidget.width - width) / 2)
    y: Math.round((rootWidget.height - height) / 2)
    modal: true
    focus: true
    dim: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var systemAppsList: []
    property string systemAppsSearch: ""
    property string activeTab: "add"

    function openDialog() {
        systemAppsSearch = "";
        if (activeTab === "add") systemSearchField.forceActiveFocus();
        const allEntries = DesktopEntries.applications.values;
        let apps = [];
        for (let i = 0; i < allEntries.length; i++) {
            const app = allEntries[i];
            if (app && !app.noDisplay) {
                apps.push({
                    name: app.name || "",
                    exec: rootWidget.cleanExec(app.execString || (app.command ? app.command.join(" ") : "")),
                    icon: app.icon || ""
                });
            }
        }
        apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        systemAppsList = apps;
        open();
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        id: dialogCard
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                StyledText {
                    text: I18n.tr("Manage Applications")
                    font.bold: true; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    width: 24; height: 24; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: managePopup.close()
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    DankIcon { anchors.centerIn: parent; name: "close"; size: 16; color: Theme.surfaceText; opacity: parent.containsMouse ? 1.0 : 0.6 }
                }
            }

            // Tabs & Group Creation
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: Theme.spacingS
                Rectangle {
                    width: parent.width - 40; height: 32; radius: 16; color: Theme.withAlpha(Theme.surfaceText, 0.05)
                    border.color: Theme.withAlpha(Theme.outline, 0.1); border.width: 1
                    Row {
                        anchors.fill: parent; anchors.margins: 2
                        MouseArea {
                            id: tabAddBtn; width: parent.width / 2; height: parent.height; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: managePopup.activeTab = "add"
                            Rectangle {
                                anchors.fill: parent; radius: 14; color: managePopup.activeTab === "add" ? Theme.primary : "transparent"
                                StyledText {
                                    anchors.centerIn: parent; text: I18n.tr("Add Apps")
                                    font.bold: true; font.pixelSize: Theme.fontSizeSmall
                                    color: managePopup.activeTab === "add" ? Theme.onPrimary : Theme.surfaceText
                                    opacity: tabAddBtn.containsMouse ? 0.9 : 0.6
                                }
                            }
                        }
                        MouseArea {
                            id: tabManageBtn; width: parent.width / 2; height: parent.height; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: managePopup.activeTab = "manage"
                            Rectangle {
                                anchors.fill: parent; radius: 14; color: managePopup.activeTab === "manage" ? Theme.primary : "transparent"
                                StyledText {
                                    anchors.centerIn: parent; text: I18n.tr("Manage")
                                    font.bold: true; font.pixelSize: Theme.fontSizeSmall
                                    color: managePopup.activeTab === "manage" ? Theme.onPrimary : Theme.surfaceText
                                    opacity: tabManageBtn.containsMouse ? 0.9 : 0.6
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: createGroupBtn; width: 32; height: 32; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: rootWidget.createGroup(I18n.tr("New Group"))
                    Rectangle {
                        anchors.fill: parent; radius: 16
                        color: createGroupBtn.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.03)
                        border.color: Theme.withAlpha(Theme.outline, 0.15); border.width: 1
                        DankIcon { anchors.centerIn: parent; name: "create_new_folder"; size: 16; color: Theme.surfaceText; opacity: createGroupBtn.containsMouse ? 1.0 : 0.6 }
                    }
                }
            }

            // Add Apps Search (Only when tab is "add")
            Rectangle {
                visible: managePopup.activeTab === "add"
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 12
                color: Theme.withAlpha(Theme.surfaceText, 0.04)
                border.color: systemSearchField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.1)
                border.width: 1
                
                DankIcon { id: sysSearchIcon; name: "search"; size: 14; color: Theme.surfaceText; opacity: 0.5; anchors.left: parent.left; anchors.leftMargin: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter }
                TextInput {
                    id: systemSearchField; anchors.left: sysSearchIcon.right; anchors.leftMargin: Theme.spacingXS; anchors.right: parent.right; anchors.rightMargin: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; selectByMouse: true
                    onTextChanged: managePopup.systemAppsSearch = text
                    Text { text: I18n.tr("Search system apps..."); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; opacity: 0.35; visible: systemSearchField.text === "" && !systemSearchField.activeFocus; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // Add Apps List
            ListView {
                id: addAppsListView
                visible: managePopup.activeTab === "add"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true; spacing: 2; boundsBehavior: Flickable.StopAtBounds
                model: {
                    const s = managePopup.systemAppsSearch.toLowerCase().trim();
                    return managePopup.systemAppsList.filter(app => {
                        return s === "" || (app.name && app.name.toLowerCase().indexOf(s) !== -1) || (app.exec && app.exec.toLowerCase().indexOf(s) !== -1);
                    });
                }
                delegate: Rectangle {
                    width: addAppsListView.width; height: 38; radius: 6; color: listMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"
                    
                    Row {
                        anchors.fill: parent; anchors.leftMargin: Theme.spacingS; spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                        Image { width: 24; height: 24; source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""; fillMode: Image.PreserveAspectFit; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter }
                    }
                    
                    property bool isAdded: rootWidget.addedApps.some(a => a.name === modelData.name)
                    Rectangle {
                        width: 22; height: 22; radius: 11; anchors.right: parent.right; anchors.rightMargin: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                        color: isAdded ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"; border.color: isAdded ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3); border.width: 1
                        DankIcon { anchors.centerIn: parent; name: isAdded ? "done" : "add"; size: 12; color: isAdded ? Theme.primary : Theme.surfaceText }
                    }
                    
                    MouseArea {
                        id: listMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: isAdded ? rootWidget.removeApp(rootWidget.addedApps.findIndex(a => a.name === modelData.name)) : rootWidget.addApp(modelData)
                    }
                }
            }

            // Manage List
            ListView {
                id: manageList
                visible: managePopup.activeTab === "manage"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
                model: rootWidget.addedApps
                
                property int editingIndex: -1

                delegate: Rectangle {
                    width: manageList.width; height: !!modelData.isSeparator ? 0 : 38; radius: 6; color: manageItemMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"
                    visible: !modelData.isSeparator
                    
                    readonly property bool isInsideGroupRange: {
                        if (modelData.isGroup || modelData.isSeparator) return false;
                        for (let k = index - 1; k >= 0; k--) {
                            if (rootWidget.addedApps[k].isGroup) return true;
                            if (rootWidget.addedApps[k].isSeparator) return false;
                        }
                        return false;
                    }

                    // Content
                    Row {
                        id: leftPart
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS + (isInsideGroupRange ? 24 : 0)
                        anchors.right: controlsRow.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        
                        DankIcon { name: !!modelData.isGroup ? "folder" : (!!modelData.isSeparator ? "vertical_align_center" : ""); size: 24; color: !!modelData.isGroup ? Theme.primary : Theme.surfaceVariantText; rotation: !!modelData.isSeparator ? 90 : 0; visible: !!modelData.isGroup || !!modelData.isSeparator; anchors.verticalCenter: parent.verticalCenter }
                        Image { width: 24; height: 24; source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""; fillMode: Image.PreserveAspectFit; visible: !modelData.isGroup && !modelData.isSeparator; anchors.verticalCenter: parent.verticalCenter }
                        
                        StyledText {
                            text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; width: parent.width; anchors.verticalCenter: parent.verticalCenter
                            visible: manageList.editingIndex !== index
                        }

                        TextInput {
                            id: editField
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            visible: manageList.editingIndex === index
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            selectByMouse: true
                            
                            onVisibleChanged: {
                                if (visible) {
                                    focusTimer.restart();
                                }
                            }

                            Timer {
                                id: focusTimer
                                interval: 50
                                onTriggered: {
                                    editField.forceActiveFocus();
                                    editField.selectAll();
                                }
                            }

                            onAccepted: {
                                rootWidget.renameGroup(index, text);
                                manageList.editingIndex = -1;
                            }
                            onEditingFinished: manageList.editingIndex = -1
                        }
                    }

                    // Row-level hover area
                    MouseArea {
                        id: manageItemMouseArea
                        anchors.fill: leftPart
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        z: -1
                    }

                    // Specific buttons
                    Row {
                        id: controlsRow
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Rename Button
                        MouseArea {
                            id: renameBtn
                            width: 22; height: 22; hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            visible: !!modelData.isGroup && manageList.editingIndex !== index
                            onClicked: manageList.editingIndex = index

                            DankIcon {
                                anchors.centerIn: parent
                                name: "edit"
                                size: 14
                                color: Theme.surfaceText
                                opacity: renameBtn.containsMouse ? 1.0 : 0.6
                            }
                        }

                        MouseArea {
                            id: upBtn
                            width: 22; height: 22; hoverEnabled: true
                            enabled: index > 0 && !(modelData.isSeparator && rootWidget.addedApps[index - 1].isGroup)
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootWidget.moveAppUp(index)
                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_upward"
                                size: 14
                                color: Theme.surfaceText
                                opacity: upBtn.enabled ? (upBtn.containsMouse ? 1.0 : 0.6) : 0.15
                            }
                        }

                        MouseArea {
                            id: downBtn
                            width: 22; height: 22; hoverEnabled: true
                            enabled: index < rootWidget.addedApps.length - 1 && !(modelData.isGroup && rootWidget.addedApps[index + 1].isSeparator)
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootWidget.moveAppDown(index)
                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_downward"
                                size: 14
                                color: Theme.surfaceText
                                opacity: downBtn.enabled ? (downBtn.containsMouse ? 1.0 : 0.6) : 0.15
                            }
                        }

                        MouseArea {
                            id: delBtn
                            width: 22; height: 22; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWidget.removeApp(index)
                            DankIcon {
                                anchors.centerIn: parent
                                name: "delete"
                                size: 14
                                color: delBtn.containsMouse ? Theme.error : Theme.surfaceText
                                opacity: delBtn.containsMouse ? 1.0 : 0.6
                            }
                        }
                    }
                }
            }
        }
    }
}
