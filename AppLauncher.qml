import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    // Accepts keyboard focus permanently to support text inputs on Wayland
    property bool acceptsKeyboardFocus: true

    // Desktop widget dimensions
    minWidth: 240
    minHeight: 320
    widgetWidth: pluginData.widgetWidth !== undefined ? pluginData.widgetWidth : 360
    widgetHeight: pluginData.widgetHeight !== undefined ? pluginData.widgetHeight : 480

    // Properties for search and added apps
    property string searchQuery: ""
    property bool editMode: false
    
    // Dynamic settings properties
    readonly property real appSize: pluginData.appSize ?? 88
    readonly property string viewMode: pluginData.viewMode ?? "grid"
    readonly property bool showHeader: pluginData.showHeader ?? true
    readonly property real iconSize: Math.max(28, Math.round(appSize * 0.58))
    
    // Load added apps from persistent settings
    property var addedApps: pluginData.addedApps !== undefined ? pluginData.addedApps : []
    property var allAppsList: addedApps

    // ListModel for active filtered apps
    ListModel {
        id: filteredModel
    }

    // Filter addedApps based on search query
    function updateFilteredModel() {
        filteredModel.clear();
        const search = searchQuery.toLowerCase().trim();

        for (let app of allAppsList) {
            const matchesSearch = search === "" || 
                                  app.name.toLowerCase().indexOf(search) !== -1 ||
                                  (app.exec && app.exec.toLowerCase().indexOf(search) !== -1);

            if (matchesSearch) {
                filteredModel.append({
                    appName: app.name,
                    appIcon: app.icon,
                    appExec: app.exec,
                    appCategories: app.categories
                });
            }
        }
    }

    onSearchQueryChanged: updateFilteredModel()
    onAllAppsListChanged: updateFilteredModel()

    Component.onCompleted: {
        updateFilteredModel();
    }

    // Persist dimensions when resized
    onWidgetWidthChanged: {
        if (pluginService && widgetWidth !== pluginData.widgetWidth) {
            pluginService.savePluginData(pluginId, "widgetWidth", widgetWidth);
        }
    }

    onWidgetHeightChanged: {
        if (pluginService && widgetHeight !== pluginData.widgetHeight) {
            pluginService.savePluginData(pluginId, "widgetHeight", widgetHeight);
        }
    }

    // Save added apps to persistent settings
    function saveAddedApps(newList) {
        if (pluginService) {
            pluginService.savePluginData(pluginId, "addedApps", newList);
        }
        root.addedApps = newList;
    }

    // Add app to the grid
    function addApp(app) {
        let list = [...root.addedApps];
        // Prevent duplicates
        if (!list.some(a => a.name === app.name)) {
            list.push(app);
            saveAddedApps(list);
        }
    }

    // Remove app from the grid
    function removeApp(appName) {
        let list = [...root.addedApps];
        list = list.filter(a => a.name !== appName);
        saveAddedApps(list);
    }

    // Glassmorphic Premium Background
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, 0.88)
        radius: Theme.cornerRadius
        border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
        border.width: root.editMode ? 2 : 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: root.showHeader ? Theme.spacingS : 0

            // Top: Header with Title, Expandable Search and Add Button
            Item {
                width: parent.width
                height: root.showHeader ? 24 : 0
                visible: root.showHeader

                // Title
                StyledText {
                    text: I18n.tr("Applications")
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !searchContainer.expanded
                }

                // Controls Row (Search and Add App Button)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    height: parent.height

                    // Premium Expandable Search Container
                    Rectangle {
                        id: searchContainer
                        property bool expanded: false
                        width: expanded ? Math.min(200, root.width - Theme.spacingM * 2 - 40) : 24
                        height: 24
                        radius: 12
                        color: expanded ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"
                        border.color: expanded ? Theme.withAlpha(Theme.outline, 0.15) : "transparent"
                        border.width: expanded ? 1 : 0
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Clicking container opens and focuses search
                        MouseArea {
                            anchors.fill: parent
                            visible: !searchContainer.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchContainer.expanded = true;
                                searchField.forceActiveFocus();
                            }
                        }

                        DankIcon {
                            id: searchIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: searchContainer.expanded ? 4 : (searchContainer.width - size) / 2
                            name: "search"
                            size: 14
                            color: Theme.surfaceText
                            opacity: searchField.activeFocus ? 1.0 : (searchContainer.expanded ? 0.6 : 0.7)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        TextInput {
                            id: searchField
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 4
                            anchors.right: clearBtn.visible ? clearBtn.left : parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceText
                            selectByMouse: true
                            visible: searchContainer.expanded
                            opacity: searchContainer.expanded ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            onTextChanged: {
                                root.searchQuery = text;
                            }

                            // Placeholder Text
                            Text {
                                text: I18n.tr("Search...")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceText
                                opacity: 0.35
                                visible: searchField.text === "" && !searchField.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Clear and Collapse button
                        MouseArea {
                            id: clearBtn
                            width: 12
                            height: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchContainer.expanded
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            
                            onClicked: {
                                searchField.text = "";
                                root.searchQuery = "";
                                searchField.focus = false;
                                searchContainer.expanded = false;
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 10
                                color: Theme.surfaceText
                                opacity: clearBtn.containsMouse ? 0.9 : 0.5
                            }
                        }
                    }

                    // Add App Button
                    MouseArea {
                        id: addBtn
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        anchors.verticalCenter: parent.verticalCenter
                        
                        onClicked: {
                            addAppDialog.openDialog();
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: addBtn.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.03)
                            border.color: Theme.withAlpha(Theme.outline, 0.15)
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: "add"
                                size: 14
                                color: Theme.surfaceText
                                opacity: addBtn.containsMouse ? 1.0 : 0.7
                            }
                        }
                    }
                    
                    // Edit Mode Button
                    MouseArea {
                        id: editBtn
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        anchors.verticalCenter: parent.verticalCenter
                        
                        onClicked: {
                            root.editMode = !root.editMode;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: root.editMode ? Theme.withAlpha(Theme.primary, 0.15) : (editBtn.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.03))
                            border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: "edit"
                                size: 14
                                color: root.editMode ? Theme.primary : Theme.surfaceText
                                opacity: editBtn.containsMouse || root.editMode ? 1.0 : 0.7
                            }
                        }
                    }




                }
            }

            // Apps Grid
            GridView {
                id: appsGrid
                width: parent.width
                height: parent.height - (root.showHeader ? (24 + Theme.spacingS * 2) : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.viewMode === "grid"
                
                cellWidth: Math.floor(width / Math.max(2, Math.floor(width / root.appSize)))
                cellHeight: cellWidth

                model: filteredModel

                // Smooth add/remove transitions
                add: Transition {
                    NumberAnimation { properties: "opacity,scale"; from: 0; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                }
                remove: Transition {
                    NumberAnimation { properties: "opacity,scale"; to: 0; duration: 150; easing.type: Easing.InQuad }
                }

                delegate: Item {
                    id: delegateRoot
                    width: appsGrid.cellWidth
                    height: appsGrid.cellHeight

                    MouseArea {
                        id: appCard
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            clickLaunchAnimation.start();
                            Quickshell.execDetached(["sh", "-c", appExec]);
                        }

                        // Premium Tighter Icon Container with Primary Border on Hover
                        Rectangle {
                            id: containerRect
                            width: Math.round(root.iconSize * 1.45)
                            height: width
                            anchors.centerIn: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            
                            color: appCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.12)
                            border.color: appCard.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.45)
                            border.width: appCard.containsMouse ? 2 : 1
                            
                            Behavior on color { enabled: !clickLaunchAnimation.running; ColorAnimation { duration: 150 } }
                            Behavior on border.color { enabled: !clickLaunchAnimation.running; ColorAnimation { duration: 150 } }
                            Behavior on border.width { enabled: !clickLaunchAnimation.running; NumberAnimation { duration: 150 } }

                            SequentialAnimation {
                                id: clickLaunchAnimation
                                
                                NumberAnimation {
                                    target: containerRect
                                    property: "scale"
                                    to: 0.88
                                    duration: 60
                                    easing.type: Easing.OutQuad
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: containerRect
                                        property: "scale"
                                        to: 1.15
                                        duration: 180
                                        easing.type: Easing.OutBack
                                    }
                                    ColorAnimation {
                                        target: containerRect
                                        property: "color"
                                        to: Theme.withAlpha(Theme.primary, 0.45)
                                        duration: 180
                                    }
                                    ColorAnimation {
                                        target: containerRect
                                        property: "border.color"
                                        to: Theme.primary
                                        duration: 180
                                    }
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: containerRect
                                        property: "scale"
                                        to: 1.0
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                    ColorAnimation {
                                        target: containerRect
                                        property: "color"
                                        to: appCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.12)
                                        duration: 200
                                    }
                                    ColorAnimation {
                                        target: containerRect
                                        property: "border.color"
                                        to: appCard.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.45)
                                        duration: 200
                                    }
                                }
                            }

                            // Centered Icon inside the container
                            Item {
                                width: root.iconSize
                                height: root.iconSize
                                anchors.centerIn: parent
                                
                                Image {
                                    id: appImage
                                    anchors.fill: parent
                                    source: appIcon ? Quickshell.iconPath(appIcon) : ""
                                    fillMode: Image.PreserveAspectFit
                                    scale: appCard.containsMouse ? 1.08 : 1.0
                                    visible: appIcon !== ""
                                    
                                    Behavior on scale {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                    }

                                    onStatusChanged: {
                                        if (status == Image.Error) {
                                            fallbackIcon.visible = true;
                                            appImage.visible = false;
                                        }
                                    }
                                }

                                DankIcon {
                                    id: fallbackIcon
                                    anchors.fill: parent
                                    name: "extension"
                                    size: parent.width
                                    color: Theme.surfaceText
                                    visible: appIcon === "" || !appImage.visible
                                    scale: appCard.containsMouse ? 1.08 : 1.0
                                }
                            }
                        }

                        // Remove App Button (Visible on hover when in desktop Edit Mode)
                        MouseArea {
                            width: 16
                            height: 16
                            anchors.top: parent.top
                            anchors.right: parent.right
                            visible: root.editMode
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                root.removeApp(appName);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: parent.containsMouse ? Theme.error : Theme.surfaceContainerHigh
                                border.color: Theme.outline
                                border.width: 1

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 10
                                    color: parent.parent.containsMouse ? Theme.onError : Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }

            // Apps List
            ListView {
                id: appsList
                width: parent.width
                height: parent.height - (root.showHeader ? (24 + Theme.spacingS * 2) : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.viewMode === "list"
                spacing: 2
                model: filteredModel

                // Smooth transitions
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 200 }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                }

                delegate: Item {
                    id: listDelegateRoot
                    width: appsList.width
                    height: Math.round(36 * (root.appSize / 88.0))

                    MouseArea {
                        id: listAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            listClickLaunchAnimation.start();
                            Quickshell.execDetached(["sh", "-c", appExec]);
                        }

                        Rectangle {
                            id: listContainerRect
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: listAppCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            border.color: listAppCard.containsMouse ? Theme.primary : "transparent"
                            border.width: listAppCard.containsMouse ? 1 : 0

                            SequentialAnimation {
                                id: listClickLaunchAnimation
                                NumberAnimation { target: listContainerRect; property: "scale"; to: 0.98; duration: 60 }
                                NumberAnimation { target: listContainerRect; property: "scale"; to: 1.0; duration: 100 }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                // Icon
                                Item {
                                    width: Math.round(20 * (root.appSize / 88.0))
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: listAppImage
                                        anchors.fill: parent
                                        source: appIcon ? Quickshell.iconPath(appIcon) : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: appIcon !== ""

                                        onStatusChanged: {
                                            if (status == Image.Error) {
                                                listFallbackIcon.visible = true;
                                                listAppImage.visible = false;
                                            }
                                        }
                                    }

                                    DankIcon {
                                        id: listFallbackIcon
                                        anchors.fill: parent
                                        name: "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: appIcon === "" || !listAppImage.visible
                                    }
                                }

                                // App Name
                                StyledText {
                                    text: appName
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - parent.spacing - Math.round(20 * (root.appSize / 88.0)) - (root.editMode ? 24 : 0)
                                }
                            }

                            // Remove App Button
                            MouseArea {
                                width: 16
                                height: 16
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.editMode
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    root.removeApp(appName);
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: parent.containsMouse ? Theme.error : Theme.surfaceContainerHigh
                                    border.color: Theme.outline
                                    border.width: 1

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 10
                                        color: parent.parent.containsMouse ? Theme.onError : Theme.surfaceText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Apps Compact
            GridView {
                id: appsCompact
                width: parent.width
                height: parent.height - (root.showHeader ? (24 + Theme.spacingS * 2) : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.viewMode === "compact"
                
                cellWidth: parent.width > 280 ? parent.width / 2 : parent.width
                cellHeight: Math.round(30 * (root.appSize / 88.0))
                model: filteredModel

                // Smooth transitions
                add: Transition {
                    NumberAnimation { properties: "opacity,scale"; from: 0; to: 1.0; duration: 200 }
                }
                remove: Transition {
                    NumberAnimation { properties: "opacity,scale"; to: 0; duration: 150 }
                }

                delegate: Item {
                    id: compactDelegateRoot
                    width: appsCompact.cellWidth
                    height: appsCompact.cellHeight

                    MouseArea {
                        id: compactAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            compactClickLaunchAnimation.start();
                            Quickshell.execDetached(["sh", "-c", appExec]);
                        }

                        Rectangle {
                            id: compactContainerRect
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: compactAppCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            border.color: compactAppCard.containsMouse ? Theme.primary : "transparent"
                            border.width: compactAppCard.containsMouse ? 1 : 0

                            SequentialAnimation {
                                id: compactClickLaunchAnimation
                                NumberAnimation { target: compactContainerRect; property: "scale"; to: 0.98; duration: 60 }
                                NumberAnimation { target: compactContainerRect; property: "scale"; to: 1.0; duration: 100 }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                // Icon
                                Item {
                                    width: Math.round(16 * (root.appSize / 88.0))
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: compactAppImage
                                        anchors.fill: parent
                                        source: appIcon ? Quickshell.iconPath(appIcon) : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: appIcon !== ""

                                        onStatusChanged: {
                                            if (status == Image.Error) {
                                                compactFallbackIcon.visible = true;
                                                compactAppImage.visible = false;
                                            }
                                        }
                                    }

                                    DankIcon {
                                        id: compactFallbackIcon
                                        anchors.fill: parent
                                        name: "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: appIcon === "" || !compactAppImage.visible
                                    }
                                }

                                // App Name
                                StyledText {
                                    text: appName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - parent.spacing - Math.round(16 * (root.appSize / 88.0)) - (root.editMode ? 24 : 0)
                                }
                            }

                            // Remove App Button
                            MouseArea {
                                width: 16
                                height: 16
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.editMode
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    root.removeApp(appName);
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: parent.containsMouse ? Theme.error : Theme.surfaceContainerHigh
                                    border.color: Theme.outline
                                    border.width: 1

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 10
                                        color: parent.parent.containsMouse ? Theme.onError : Theme.surfaceText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Placeholder when widget is empty (placed outside Column to prevent layout issues)
        StyledText {
            text: I18n.tr("Click + to add applications")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            opacity: 0.4
            anchors.centerIn: parent
            visible: filteredModel.count === 0 && searchQuery === ""
        }
    }

    // Modal popup to select and add system applications
    // Modal in-widget dialog to select and add system applications
    // Modal in-widget dimmer and dialog to select and add system applications
    Rectangle {
        id: addAppDialog
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.6) // glass dimmer
        radius: Theme.cornerRadius
        z: 100
        focus: true
        visible: opened || opacity > 0
        opacity: opened ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 150 } }

        property bool opened: false
        property var systemAppsList: []
        property string systemAppsSearch: ""

        // Prevent mouse clicks from propagating through the dimmer overlay
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {}
        }

        // Trigger scan only when user wants to add an app
        function openDialog() {
            systemAppsSearch = "";
            systemSearchField.text = "";
            opened = true;
            systemSearchField.forceActiveFocus();
            
            const homePath = Quickshell.env("HOME");
            const scriptPath = homePath + "/.config/DankMaterialShell/plugins/dmsAppLauncher/scan_apps.py";
            
            Proc.runCommand(
                "dmsAppLauncher.scanSystem",
                [scriptPath],
                (stdout, exitCode) => {
                    if (exitCode === 0) {
                        try {
                            systemAppsList = JSON.parse(stdout);
                        } catch (e) {
                            console.log("Error parsing system apps: " + e);
                        }
                    }
                }
            );
        }

        function close() {
            opened = false;
        }

        // Centered Card Dialog
        Rectangle {
            width: Math.min(320, parent.width - 20)
            height: Math.min(400, parent.height - 20)
            anchors.centerIn: parent
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            focus: true
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1
            clip: true
            scale: addAppDialog.opened ? 1.0 : 0.95
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                // Dialog Header
                Item {
                    width: parent.width
                    height: 24
                    
                    StyledText {
                        text: I18n.tr("Add Applications")
                        font.bold: true
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Close Dialog Button
                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addAppDialog.close()
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: Theme.surfaceText
                            opacity: parent.containsMouse ? 1.0 : 0.6
                        }
                    }
                }

                // System Apps Search Bar
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Math.round(Theme.cornerRadius / 2)
                    color: Theme.withAlpha(Theme.surfaceText, 0.04)
                    border.color: systemSearchField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.1)
                    border.width: 1

                    DankIcon {
                        id: sysSearchIcon
                        name: "search"
                        size: 14
                        color: Theme.surfaceText
                        opacity: 0.5
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: systemSearchField
                        anchors.left: sysSearchIcon.right
                        anchors.leftMargin: Theme.spacingXS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        selectByMouse: true
                        focus: true
                        
                        onTextChanged: {
                            addAppDialog.systemAppsSearch = text;
                        }

                        Text {
                            text: I18n.tr("Search system apps...")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            opacity: 0.35
                            visible: systemSearchField.text === "" && !systemSearchField.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // System Apps ListView
                ListView {
                    width: parent.width
                    height: parent.height - 24 - 32 - Theme.spacingS * 2
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    model: {
                        const search = addAppDialog.systemAppsSearch.toLowerCase().trim();
                        return addAppDialog.systemAppsList.filter(app => {
                            return search === "" || 
                                   app.name.toLowerCase().indexOf(search) !== -1 ||
                                   (app.exec && app.exec.toLowerCase().indexOf(search) !== -1);
                        });
                    }

                    delegate: Rectangle {
                        width: parent.width
                        height: 38
                        radius: Math.max(2, Math.round(Theme.cornerRadius / 2) - 2)
                        color: listMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            // Icon
                            Image {
                                width: 24
                                height: 24
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // App Name
                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width - 24 - 32 - Theme.spacingS * 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Status Badge or Add Icon
                        property bool isAdded: root.addedApps.some(a => a.name === modelData.name)

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            color: isAdded ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            border.color: isAdded ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: parent.parent.isAdded ? "done" : "add"
                                size: 12
                                color: parent.parent.isAdded ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: listMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                if (parent.isAdded) {
                                    root.removeApp(modelData.name);
                                } else {
                                    root.addApp(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
