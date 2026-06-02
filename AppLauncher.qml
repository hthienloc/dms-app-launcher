import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

DesktopPluginComponent {
    id: root

    // Accepts keyboard focus permanently to support text inputs on Wayland
    property bool acceptsKeyboardFocus: true

    function cleanExec(execStr) {
        if (!execStr) return "";
        let clean = execStr.replace(/["']?%[fFuUickdnNvVm]["']?/g, "");
        clean = clean.replace(/%%/g, "%");
        return clean.trim();
    }

    // Desktop widget dimensions
    minWidth: 240
    minHeight: 320
    widgetWidth: pluginData.widgetWidth !== undefined ? pluginData.widgetWidth : 360
    widgetHeight: pluginData.widgetHeight !== undefined ? pluginData.widgetHeight : 480

    // Properties for search and added apps
    property string searchQuery: ""
    property bool editMode: false
    
    // Group navigation state
    property int activeGroupIndex: -1 // Index of the Start Marker in addedApps

    // Dynamic settings properties
    readonly property real appSize: pluginData.appSize ?? 88
    readonly property string viewMode: pluginData.viewMode ?? "grid"
    readonly property bool showHeader: false
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 80) / 100
    readonly property real iconSize: Math.max(28, Math.round(appSize * 0.58))
    
    // Flat persistent list of apps and markers
    property var addedApps: pluginData.addedApps !== undefined ? pluginData.addedApps : []

    // ListModel for active filtered apps (Dynamic View)
    ListModel {
        id: filteredModel
    }

    // Process the flat list into the current view
    function updateFilteredModel() {
        filteredModel.clear();
        const search = searchQuery.toLowerCase().trim();
        
        if (activeGroupIndex === -1) {
            // Root View: Show standalone apps and Group Tiles
            for (let i = 0; i < addedApps.length; i++) {
                const item = addedApps[i];
                if (item.isGroup) {
                    // It's a Group Start Marker. Find apps until next separator.
                    let groupApps = [];
                    let j = i + 1;
                    while (j < addedApps.length && !addedApps[j].isSeparator) {
                        if (!addedApps[j].isGroup) groupApps.push(addedApps[j]);
                        j++;
                    }
                    
                    // Always show group tile in root unless searching (groups filter by content then)
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          groupApps.some(a => a.name.toLowerCase().indexOf(search) !== -1);
                                          
                    if (matchesSearch) {
                        filteredModel.append({
                            appName: item.name,
                            appIcon: "", // Groups use mini-grid
                            appExec: "",
                            isGroup: true,
                            originalIndex: i,
                            groupApps: groupApps
                        });
                    }
                    
                    // Skip the items we just bundled into the group
                    i = j; 
                } else if (!item.isSeparator) {
                    // Standalone App
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          (item.exec && item.exec.toLowerCase().indexOf(search) !== -1);
                    if (matchesSearch) {
                        filteredModel.append({
                            appName: item.name,
                            appIcon: item.icon || "",
                            appExec: item.exec || "",
                            isGroup: false,
                            originalIndex: i,
                            groupApps: []
                        });
                    }
                }
            }
        } else {
            // Inside Group View: Show only apps in the range
            let i = activeGroupIndex + 1;
            while (i < addedApps.length && !addedApps[i].isSeparator) {
                const item = addedApps[i];
                if (!item.isGroup) {
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          (item.exec && item.exec.toLowerCase().indexOf(search) !== -1);
                    if (matchesSearch) {
                        filteredModel.append({
                            appName: item.name,
                            appIcon: item.icon || "",
                            appExec: item.exec || "",
                            isGroup: false,
                            originalIndex: i,
                            groupApps: []
                        });
                    }
                }
                i++;
            }
        }
    }

    onSearchQueryChanged: updateFilteredModel()
    onAddedAppsChanged: updateFilteredModel()
    onActiveGroupIndexChanged: updateFilteredModel()

    Component.onCompleted: updateFilteredModel()

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

    // Save flat list to persistent settings
    function saveAddedApps(newList) {
        if (pluginService) {
            pluginService.savePluginData(pluginId, "addedApps", newList);
        }
        root.addedApps = newList;
    }

    // Add app to the flat list (respects active group context)
    function addApp(app) {
        let list = [...root.addedApps];
        if (list.some(a => a.name === app.name)) return;
        
        const newApp = {
            name: app.name,
            icon: app.icon,
            exec: app.exec
        };

        if (activeGroupIndex !== -1) {
            // Find the separator for the current active group
            let j = activeGroupIndex + 1;
            while (j < list.length && !list[j].isSeparator) j++;
            
            // Insert before the separator
            list.splice(j, 0, newApp);
        } else {
            // Add to the global end
            list.push(newApp);
        }
        saveAddedApps(list);
    }

    // Create a new range
    function createGroup(groupName) {
        let list = [...root.addedApps];
        list.push({
            isGroup: true,
            name: groupName || I18n.tr("New Group")
        });
        list.push({ isSeparator: true });
        saveAddedApps(list);
    }

    function removeApp(index) {
        let list = [...root.addedApps];
        if (index >= 0 && index < list.length) {
            if (list[index].isGroup) {
                // Remove group marker AND its matching separator
                let j = index + 1;
                while (j < list.length && !list[j].isSeparator) j++;
                if (j < list.length) list.splice(j, 1);
            }
            list.splice(index, 1);
            saveAddedApps(list);
        }
    }

    function moveAppUp(index) {
        if (index > 0) {
            let list = [...root.addedApps];
            let temp = list[index];
            list[index] = list[index - 1];
            list[index - 1] = temp;
            saveAddedApps(list);
        }
    }

    function moveAppDown(index) {
        if (index < root.addedApps.length - 1) {
            let list = [...root.addedApps];
            let temp = list[index];
            list[index] = list[index + 1];
            list[index + 1] = temp;
            saveAddedApps(list);
        }
    }

    function renameGroup(index, newName) {
        let list = [...root.addedApps];
        if (index >= 0 && index < list.length && list[index].isGroup) {
            list[index].name = newName || I18n.tr("Untitled Group");
            saveAddedApps(list);
        }
    }

    // Component for iOS-style Group Icon (Grid Mode - 2x2)
    Component {
        id: groupGridIconComponent
        Item {
            property var groupApps: []
            width: root.iconSize
            height: root.iconSize
            anchors.centerIn: parent

            Grid {
                anchors.fill: parent
                columns: 2
                spacing: 2
                Repeater {
                    model: groupApps
                    delegate: Item {
                        width: (parent.width - 2) / 2
                        height: width
                        visible: index < 4
                        Image {
                            anchors.fill: parent
                            source: icon ? Quickshell.iconPath(icon) : ""
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.9
                        }
                    }
                }
            }
        }
    }

    // Component for Group Icon in List/Compact Mode (Row of icons)
    Component {
        id: groupListIconComponent
        Item {
            property var groupApps: []
            width: parent.width
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            Row {
                anchors.centerIn: parent
                spacing: -Math.round(parent.width * 0.2) // Overlap icons
                Repeater {
                    model: groupApps
                    delegate: Image {
                        width: parent.height
                        height: width
                        visible: index < 3
                        source: icon ? Quickshell.iconPath(icon) : ""
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.9
                        z: 10 - index
                    }
                }
            }
        }
    }

    // Glassmorphic Premium Background
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, root.backgroundOpacity)
        radius: Theme.cornerRadius
        border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
        border.width: root.editMode ? 2 : 1
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.MiddleButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    addAppDialog.openDialog();
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: (root.showHeader || root.activeGroupIndex !== -1) ? Theme.spacingS : 0

            // Top: Header with Title and Expandable Search
            Item {
                width: parent.width
                height: (root.showHeader || root.activeGroupIndex !== -1) ? 24 : 0
                visible: height > 0

                // Back Button (Only visible inside group)
                MouseArea {
                    id: backBtn
                    width: 24
                    height: 24
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.activeGroupIndex !== -1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activeGroupIndex = -1;
                        root.searchQuery = "";
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        size: 18
                        color: Theme.surfaceText
                        opacity: backBtn.containsMouse ? 1.0 : 0.7
                    }
                }

                // Title
                StyledText {
                    text: root.activeGroupIndex !== -1 ? root.addedApps[root.activeGroupIndex].name : I18n.tr("Applications")
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.left: root.activeGroupIndex !== -1 ? backBtn.right : parent.left
                    anchors.leftMargin: root.activeGroupIndex !== -1 ? Theme.spacingS : 0
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !searchContainer.expanded
                }

                // Controls Row (Search)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    height: parent.height

                    // Premium Expandable Search Container
                    Rectangle {
                        id: searchContainer
                        property bool expanded: false
                        width: expanded ? Math.min(200, root.width - Theme.spacingM * 2) : 24
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
                }
            }

            // Apps Grid
            GridView {
                id: appsGrid
                width: parent.width
                height: parent.height - ((root.showHeader || root.activeGroupIndex !== -1) ? (24 + Theme.spacingS * 2) : 0)
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
                    readonly property var currentGroupApps: model.groupApps

                    MouseArea {
                        id: appCard
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    // Launch all apps in group
                                    for (let i = 0; i < model.groupApps.count; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(model.groupApps.get(i).exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = originalIndex;
                                }
                            } else {
                                clickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(appExec)]);
                            }
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
                                
                                Loader {
                                    id: gridIconLoader
                                    anchors.fill: parent
                                    sourceComponent: isGroup ? groupGridIconComponent : appIconLoader
                                    visible: !isGroup || delegateRoot.currentGroupApps.length > 0
                                    onLoaded: {
                                        if (isGroup && item) {
                                            item.groupApps = delegateRoot.currentGroupApps;
                                        }
                                    }
                                }

                                Component {
                                    id: appIconLoader
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
                                }

                                DankIcon {
                                    id: fallbackIcon
                                    anchors.fill: parent
                                    name: isGroup ? "folder" : "extension"
                                    size: parent.width
                                    color: Theme.surfaceText
                                    visible: !isGroup ? (appIcon === "" || (typeof appImage !== "undefined" && !appImage.visible)) : delegateRoot.currentGroupApps.length === 0
                                    scale: appCard.containsMouse ? 1.08 : 1.0
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
                height: parent.height - ((root.showHeader || root.activeGroupIndex !== -1) ? (24 + Theme.spacingS * 2) : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.viewMode === "list"
                spacing: 2
                model: filteredModel

                delegate: Item {
                    id: listDelegateRoot
                    width: appsList.width
                    height: Math.round(36 * (root.appSize / 88.0))
                    readonly property var currentGroupApps: model.groupApps

                    MouseArea {
                        id: listAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    for (let i = 0; i < model.groupApps.count; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(model.groupApps.get(i).exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = originalIndex;
                                }
                            } else {
                                listClickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(appExec)]);
                            }
                        }

                        Rectangle {
                            id: listContainerRect
                            width: listDelegateRoot.width
                            height: listDelegateRoot.height
                            anchors.centerIn: parent
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

                                    Loader {
                                        id: listIconLoader
                                        anchors.fill: parent
                                        sourceComponent: isGroup ? groupListIconComponent : listAppIconLoader
                                        visible: !isGroup || listDelegateRoot.currentGroupApps.length > 0
                                        onLoaded: {
                                            if (isGroup && item) {
                                                item.groupApps = listDelegateRoot.currentGroupApps;
                                            }
                                        }
                                    }

                                    Component {
                                        id: listAppIconLoader
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
                                    }

                                    DankIcon {
                                        id: listFallbackIcon
                                        anchors.fill: parent
                                        name: isGroup ? "folder" : "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: !isGroup ? (appIcon === "" || (typeof listAppImage !== "undefined" && !listAppImage.visible)) : listDelegateRoot.currentGroupApps.length === 0
                                    }
                                }

                                // App Name
                                StyledText {
                                    text: appName
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - parent.spacing - Math.round(20 * (root.appSize / 88.0))
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
                height: parent.height - ((root.showHeader || root.activeGroupIndex !== -1) ? (24 + Theme.spacingS * 2) : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.viewMode === "compact"
                
                cellWidth: parent.width > 280 ? parent.width / 2 : parent.width
                cellHeight: Math.round(30 * (root.appSize / 88.0))
                model: filteredModel

                delegate: Item {
                    id: compactDelegateRoot
                    width: appsCompact.cellWidth
                    height: appsCompact.cellHeight
                    readonly property var currentGroupApps: model.groupApps

                    MouseArea {
                        id: compactAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    for (let i = 0; i < model.groupApps.count; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(model.groupApps.get(i).exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = originalIndex;
                                }
                            } else {
                                compactClickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(appExec)]);
                            }
                        }

                        Rectangle {
                            id: compactContainerRect
                            width: compactDelegateRoot.width
                            height: compactDelegateRoot.height
                            anchors.centerIn: parent
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

                                    Loader {
                                        id: compactIconLoader
                                        anchors.fill: parent
                                        sourceComponent: isGroup ? groupListIconComponent : compactAppIconLoader
                                        visible: !isGroup || compactDelegateRoot.currentGroupApps.length > 0
                                        onLoaded: {
                                            if (isGroup && item) {
                                                item.groupApps = compactDelegateRoot.currentGroupApps;
                                            }
                                        }
                                    }

                                    Component {
                                        id: compactAppIconLoader
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
                                    }

                                    DankIcon {
                                        id: compactFallbackIcon
                                        anchors.fill: parent
                                        name: isGroup ? "folder" : "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: !isGroup ? (appIcon === "" || (typeof compactAppImage !== "undefined" && !compactAppImage.visible)) : compactDelegateRoot.currentGroupApps.length === 0
                                    }
                                }

                                // App Name
                                StyledText {
                                    text: appName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - parent.spacing - Math.round(16 * (root.appSize / 88.0))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Placeholder when widget is empty (placed outside Column to prevent layout issues)
        StyledText {
            text: I18n.tr("Middle-click to manage applications")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            opacity: 0.4
            anchors.centerIn: parent
            visible: filteredModel.count === 0 && searchQuery === ""
        }
    }

    // Modal in-widget dimmer and dialog to select and manage applications
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
        property string activeTab: "add"

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
            if (activeTab === "add") {
                systemSearchField.forceActiveFocus();
            }
            
            // Fetch all apps directly from Quickshell's DesktopEntries singleton
            const allEntries = DesktopEntries.applications.values;
            let apps = [];
            for (let i = 0; i < allEntries.length; i++) {
                const app = allEntries[i];
                if (app && !app.noDisplay) {
                    apps.push({
                        name: app.name || "",
                        exec: cleanExec(app.execString || (app.command ? app.command.join(" ") : "")),
                        icon: app.icon || ""
                    });
                }
            }
            apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
            systemAppsList = apps;
        }

        function close() {
            opened = false;
        }

        // Centered Card Dialog
        Rectangle {
            id: dialogCard
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
                        text: I18n.tr("Manage Applications")
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

                // Tabs Segmented Control
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    height: 32

                    Rectangle {
                        width: parent.width - 40
                        height: 32
                        radius: 16
                        color: Theme.withAlpha(Theme.surfaceText, 0.05)
                        border.color: Theme.withAlpha(Theme.outline, 0.1)
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 2

                            // Tab 1: Add Apps
                            MouseArea {
                                id: tabAddBtn
                                width: parent.width / 2
                                height: parent.height
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addAppDialog.activeTab = "add"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: addAppDialog.activeTab === "add" ? Theme.primary : "transparent"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: I18n.tr("Add Apps")
                                        font.bold: addAppDialog.activeTab === "add"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: addAppDialog.activeTab === "add" ? Theme.onPrimary : Theme.surfaceText
                                        opacity: tabAddBtn.containsMouse ? 0.9 : 0.6
                                        visible: addAppDialog.activeTab !== "add"
                                    }
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: I18n.tr("Add Apps")
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.onPrimary
                                        visible: addAppDialog.activeTab === "add"
                                    }
                                }
                            }

                            // Tab 2: Manage
                            MouseArea {
                                id: tabManageBtn
                                width: parent.width / 2
                                height: parent.height
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addAppDialog.activeTab = "manage"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: addAppDialog.activeTab === "manage" ? Theme.primary : "transparent"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: I18n.tr("Manage")
                                        font.bold: addAppDialog.activeTab === "manage"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: addAppDialog.activeTab === "manage" ? Theme.onPrimary : Theme.surfaceText
                                        opacity: tabManageBtn.containsMouse ? 0.9 : 0.6
                                        visible: addAppDialog.activeTab !== "manage"
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: I18n.tr("Manage")
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.onPrimary
                                        visible: addAppDialog.activeTab === "manage"
                                    }
                                }
                            }
                        }
                    }

                    // Create Group Button
                    MouseArea {
                        id: createGroupBtn
                        width: 32
                        height: 32
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.createGroup(I18n.tr("New Group"))

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: createGroupBtn.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.03)
                            border.color: Theme.withAlpha(Theme.outline, 0.15)
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: "create_new_folder"
                                size: 16
                                color: Theme.surfaceText
                                opacity: createGroupBtn.containsMouse ? 1.0 : 0.6
                            }
                        }
                    }
                }

                // System Apps Search Bar (Only visible when activeTab === "add")
                Rectangle {
                    visible: addAppDialog.activeTab === "add"
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

                // System Apps ListView (Only visible when activeTab === "add")
                ListView {
                    visible: addAppDialog.activeTab === "add"
                    width: parent.width
                    height: dialogCard.height - Theme.spacingM * 2 - 24 - 32 - 32 - Theme.spacingS * 3
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
                                id: listAppImg
                                width: 24
                                height: 24
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter

                                onStatusChanged: {
                                    if (status == Image.Error) {
                                        fallbackListIcon.visible = true;
                                        listAppImg.visible = false;
                                    }
                                }
                            }

                            DankIcon {
                                id: fallbackListIcon
                                width: 24
                                height: 24
                                name: "extension"
                                size: 24
                                color: Theme.surfaceText
                                visible: !modelData.icon || !listAppImg.visible
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
                                    // Find index of app to remove
                                    let idx = -1;
                                    for (let k = 0; k < root.addedApps.length; k++) {
                                        if (root.addedApps[k].name === modelData.name) {
                                            idx = k; break;
                                        }
                                    }
                                    if (idx !== -1) root.removeApp(idx);
                                } else {
                                    root.addApp(modelData);
                                }
                            }
                        }
                    }
                }

                // Manage ListView (Only visible when activeTab === "manage")
                ListView {
                    visible: addAppDialog.activeTab === "manage"
                    width: parent.width
                    height: dialogCard.height - Theme.spacingM * 2 - 24 - 32 - Theme.spacingS * 2
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds

                    model: root.addedApps

                    delegate: Rectangle {
                        width: parent.width
                        height: 38
                        radius: Math.max(2, Math.round(Theme.cornerRadius / 2) - 2)
                        color: manageItemMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"

                        MouseArea {
                            id: manageItemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            // Icon
                            DankIcon {
                                name: !!modelData.isGroup ? "folder" : ""
                                size: 24
                                color: Theme.primary
                                visible: !!modelData.isGroup
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            DankIcon {
                                name: !!modelData.isSeparator ? "vertical_align_center" : ""
                                size: 18
                                color: Theme.surfaceVariantText
                                visible: !!modelData.isSeparator
                                rotation: 90
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                id: manageIcon
                                width: 24
                                height: 24
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !modelData.isGroup && !modelData.isSeparator

                                onStatusChanged: {
                                    if (status == Image.Error) {
                                        manageFallback.visible = true;
                                        manageIcon.visible = false;
                                    }
                                }
                            }

                            DankIcon {
                                id: manageFallback
                                width: 24
                                height: 24
                                name: "extension"
                                size: 24
                                color: Theme.surfaceText
                                visible: !modelData.isGroup && !modelData.isSeparator && (!modelData.icon || !manageIcon.visible)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // App Name
                            StyledText {
                                text: !!modelData.isSeparator ? "──────────" : modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.italic: !!modelData.isSeparator
                                color: !!modelData.isSeparator ? Theme.surfaceVariantText : Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width - 24 - 72 - Theme.spacingS * 3
                                anchors.verticalCenter: parent.verticalCenter
                                
                                MouseArea {
                                    anchors.fill: parent
                                    visible: !!modelData.isGroup
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: renameGroup(index, prompt(I18n.tr("New name:"), text))
                                }
                            }

                            // Action buttons row (Up, Down, Delete)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                // Move Up Button
                                MouseArea {
                                    id: upBtn
                                    width: 22
                                    height: 22
                                    hoverEnabled: true
                                    cursorShape: index > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (index > 0) {
                                            root.moveAppUp(index);
                                        }
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "arrow_upward"
                                        size: 14
                                        color: Theme.surfaceText
                                        opacity: index > 0 ? (upBtn.containsMouse ? 1.0 : 0.6) : 0.15
                                    }
                                }

                                // Move Down Button
                                MouseArea {
                                    id: downBtn
                                    width: 22
                                    height: 22
                                    hoverEnabled: true
                                    cursorShape: index < root.addedApps.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (index < root.addedApps.length - 1) {
                                            root.moveAppDown(index);
                                        }
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "arrow_downward"
                                        size: 14
                                        color: Theme.surfaceText
                                        opacity: index < root.addedApps.length - 1 ? (downBtn.containsMouse ? 1.0 : 0.6) : 0.15
                                    }
                                }

                                // Delete Button
                                MouseArea {
                                    id: delBtn
                                    width: 22
                                    height: 22
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.removeApp(index);
                                    }

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
    }
}
