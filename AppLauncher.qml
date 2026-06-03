import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    widgetWidth: root.pluginData?.widgetWidth ?? 360
    widgetHeight: root.pluginData?.widgetHeight ?? 480

    // Properties for search and added apps
    property string searchQuery: ""
    property bool editMode: false
    
    // Group navigation state
    property int activeGroupIndex: -1 // Index of the Start Marker in addedApps

    // Dynamic settings properties
    readonly property real appSize: root.pluginData?.appSize ?? 88
    readonly property string viewMode: root.pluginData?.viewMode ?? "grid"
    readonly property bool showHeader: root.pluginData?.showHeader ?? false
    readonly property real backgroundOpacity: (root.pluginData?.backgroundOpacity ?? 80) / 100
    readonly property real iconSize: Math.max(28, Math.round(root.appSize * 0.58))
    
    // Flat persistent list of apps and markers
    property var addedApps: root.pluginData?.addedApps ?? []

    // Reactive array for the current view (Replaces ListModel for deep data support)
    property var filteredApps: []

    // Process the flat list into the current view
    function updateFilteredModel() {
        const search = searchQuery.toLowerCase().trim();
        let result = [];
        
        if (activeGroupIndex === -1) {
            // Root View: Show standalone apps and Group Tiles
            for (let i = 0; i < addedApps.length; i++) {
                const item = addedApps[i];
                if (item.isGroup) {
                    let groupApps = [];
                    let j = i + 1;
                    while (j < addedApps.length && !addedApps[j].isSeparator) {
                        if (!addedApps[j].isGroup) groupApps.push(addedApps[j]);
                        j++;
                    }
                    
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          groupApps.some(a => a.name.toLowerCase().indexOf(search) !== -1);
                                          
                    if (matchesSearch) {
                        result.push({
                            appName: item.name,
                            appIcon: "",
                            appExec: "",
                            isGroup: true,
                            originalIndex: i,
                            groupApps: groupApps
                        });
                    }
                    i = j; 
                } else if (!item.isSeparator) {
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          (item.exec && item.exec.toLowerCase().indexOf(search) !== -1);
                    if (matchesSearch) {
                        result.push({
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
            // Inside Group View
            let i = activeGroupIndex + 1;
            while (i < addedApps.length && !addedApps[i].isSeparator) {
                const item = addedApps[i];
                if (!item.isGroup) {
                    const matchesSearch = search === "" || 
                                          item.name.toLowerCase().indexOf(search) !== -1 ||
                                          (item.exec && item.exec.toLowerCase().indexOf(search) !== -1);
                    if (matchesSearch) {
                        result.push({
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
        root.filteredApps = result;
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
            let j = activeGroupIndex + 1;
            while (j < list.length && !list[j].isSeparator) j++;
            list.splice(j, 0, newApp);
        } else {
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
            // Guard: Don't let a separator move above its group marker
            if (list[index].isSeparator && list[index - 1].isGroup) return;

            let temp = list[index];
            list[index] = list[index - 1];
            list[index - 1] = temp;
            saveAddedApps(list);
        }
    }

    function moveAppDown(index) {
        if (index < root.addedApps.length - 1) {
            let list = [...root.addedApps];
            // Guard: Don't let a group marker move below its separator
            if (list[index].isGroup && list[index + 1].isSeparator) return;

            let temp = list[index];
            list[index] = list[index + 1];
            list[index + 1] = temp;
            saveAddedApps(list);
        }
    }

    function updateAppItem(index, newName, newExec) {
        let list = [...root.addedApps];
        if (index >= 0 && index < list.length) {
            if (newName !== undefined) {
                list[index].name = newName || (list[index].isGroup ? I18n.tr("Untitled Group") : list[index].name);
            }
            if (newExec !== undefined && !list[index].isGroup && !list[index].isSeparator) {
                list[index].exec = newExec;
            }
            saveAddedApps(list);
        }
    }

    function renameGroup(index, newName) {
        root.updateAppItem(index, newName, undefined);
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
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.9
                        }
                    }
                }
            }
        }
    }

    // Component for Group Icon in List/Compact Mode (Simple Folder Icon)
    Component {
        id: groupListIconComponent
        Item {
            property var groupApps: [] // Kept for compatibility with Loader.onLoaded
            width: parent.width
            height: parent.height
            
            DankIcon {
                anchors.centerIn: parent
                name: "folder"
                size: parent.height
                color: Theme.primary
                opacity: 0.9
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
            hoverEnabled: false // Disable to prevent interference with cursor updates
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

            // Top: Header
            Item {
                width: parent.width
                height: (root.showHeader || root.activeGroupIndex !== -1) ? 24 : 0
                visible: height > 0

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

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    height: parent.height

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
                            onTextChanged: root.searchQuery = text

                            Text {
                                text: I18n.tr("Search...")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceText
                                opacity: 0.35
                                visible: searchField.text === "" && !searchField.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: clearBtn
                            width: 12; height: 12
                            anchors.right: parent.right; anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchContainer.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
                model: root.filteredApps

                delegate: Item {
                    id: delegateRoot
                    width: appsGrid.cellWidth
                    height: appsGrid.cellHeight
                    readonly property var currentGroupApps: modelData.groupApps

                    MouseArea {
                        id: appCard
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (modelData.isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    clickLaunchAnimation.start();
                                    for (let i = 0; i < delegateRoot.currentGroupApps.length; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(delegateRoot.currentGroupApps[i].exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = modelData.originalIndex;
                                }
                            } else {
                                clickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(modelData.appExec)]);
                            }
                        }

                        Rectangle {
                            id: containerRect
                            width: Math.round(root.iconSize * 1.45)
                            height: width
                            anchors.centerIn: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: appCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.12)
                            border.color: appCard.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.45)
                            border.width: appCard.containsMouse ? 2 : 1
                            
                            SequentialAnimation {
                                id: clickLaunchAnimation
                                NumberAnimation { target: containerRect; property: "scale"; to: 0.92; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: containerRect; property: "scale"; to: 1.05; duration: 150; easing.type: Easing.OutBack }
                                NumberAnimation { target: containerRect; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                            }

                            Item {
                                id: gridIconContainer
                                width: root.iconSize
                                height: root.iconSize
                                anchors.centerIn: parent
                                scale: appCard.containsMouse ? 1.12 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                
                                Loader {
                                    id: gridIconLoader
                                    anchors.fill: parent
                                    sourceComponent: modelData.isGroup ? groupGridIconComponent : appIconLoader
                                    onLoaded: {
                                        if (modelData.isGroup && item) {
                                            item.groupApps = delegateRoot.currentGroupApps;
                                        }
                                    }
                                }

                                Component {
                                    id: appIconLoader
                                    Image {
                                        id: appImage
                                        anchors.fill: parent
                                        source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon) : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: modelData.appIcon !== ""
                                        onStatusChanged: if (status == Image.Error) { fallbackIcon.visible = true; appImage.visible = false; }
                                    }
                                }

                                DankIcon {
                                    id: fallbackIcon
                                    anchors.fill: parent
                                    name: modelData.isGroup ? "folder" : "extension"
                                    size: parent.width
                                    color: Theme.surfaceText
                                    visible: !modelData.isGroup ? (modelData.appIcon === "" || (typeof appImage !== "undefined" && !appImage.visible)) : delegateRoot.currentGroupApps.length === 0
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
                model: root.filteredApps

                delegate: Item {
                    id: listDelegateRoot
                    width: appsList.width
                    height: Math.round(36 * (root.appSize / 88.0))
                    readonly property var currentGroupApps: modelData.groupApps

                    MouseArea {
                        id: listAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS; anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (modelData.isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    listClickLaunchAnimation.start();
                                    for (let i = 0; i < listDelegateRoot.currentGroupApps.length; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(listDelegateRoot.currentGroupApps[i].exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = modelData.originalIndex;
                                }
                            } else {
                                listClickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(modelData.appExec)]);
                            }
                        }

                        Rectangle {
                            id: listContainerRect
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: listAppCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            
                            SequentialAnimation {
                                id: listClickLaunchAnimation
                                NumberAnimation { target: listContainerRect; property: "scale"; to: 0.98; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: listContainerRect; property: "scale"; to: 1.02; duration: 150; easing.type: Easing.OutBack }
                                NumberAnimation { target: listContainerRect; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter

                                Item {
                                    id: listIconContainer
                                    width: Math.round(20 * (root.appSize / 88.0)); height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: listAppCard.containsMouse ? 1.18 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                    Loader {
                                        id: listIconLoader
                                        anchors.fill: parent
                                        sourceComponent: modelData.isGroup ? groupListIconComponent : listAppIconLoader
                                        onLoaded: { if (modelData.isGroup && item) item.groupApps = listDelegateRoot.currentGroupApps; }
                                    }

                                    Component {
                                        id: listAppIconLoader
                                        Image {
                                            id: listAppImage
                                            anchors.fill: parent
                                            source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon) : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: modelData.appIcon !== ""
                                            onStatusChanged: if (status == Image.Error) { listFallbackIcon.visible = true; listAppImage.visible = false; }
                                        }
                                    }

                                    DankIcon {
                                        id: listFallbackIcon
                                        anchors.fill: parent
                                        name: modelData.isGroup ? "folder" : "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: !modelData.isGroup ? (modelData.appIcon === "" || (typeof listAppImage !== "undefined" && !listAppImage.visible)) : listDelegateRoot.currentGroupApps.length === 0
                                    }
                                }

                                StyledText {
                                    text: modelData.appName
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
                model: root.filteredApps

                delegate: Item {
                    id: compactDelegateRoot
                    width: appsCompact.cellWidth
                    height: appsCompact.cellHeight
                    readonly property var currentGroupApps: modelData.groupApps

                    MouseArea {
                        id: compactAppCard
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS; anchors.rightMargin: Theme.spacingXS
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: (mouse) => {
                            if (modelData.isGroup) {
                                if (mouse.button === Qt.MiddleButton) {
                                    compactClickLaunchAnimation.start();
                                    for (let i = 0; i < compactDelegateRoot.currentGroupApps.length; i++) {
                                        Quickshell.execDetached(["sh", "-c", cleanExec(compactDelegateRoot.currentGroupApps[i].exec)]);
                                    }
                                } else {
                                    root.searchQuery = "";
                                    root.activeGroupIndex = modelData.originalIndex;
                                }
                            } else {
                                compactClickLaunchAnimation.start();
                                Quickshell.execDetached(["sh", "-c", cleanExec(modelData.appExec)]);
                            }
                        }

                        Rectangle {
                            id: compactContainerRect
                            anchors.fill: parent
                            radius: Math.round(Theme.cornerRadius / 2)
                            color: compactAppCard.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                            SequentialAnimation {
                                id: compactClickLaunchAnimation
                                NumberAnimation { target: compactContainerRect; property: "scale"; to: 0.98; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: compactContainerRect; property: "scale"; to: 1.02; duration: 150; easing.type: Easing.OutBack }
                                NumberAnimation { target: compactContainerRect; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter

                                Item {
                                    id: compactIconContainer
                                    width: Math.round(16 * (root.appSize / 88.0)); height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    scale: compactAppCard.containsMouse ? 1.18 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                    Loader {
                                        id: compactIconLoader
                                        anchors.fill: parent
                                        sourceComponent: modelData.isGroup ? groupListIconComponent : compactAppIconLoader
                                        onLoaded: { if (modelData.isGroup && item) item.groupApps = compactDelegateRoot.currentGroupApps; }
                                    }

                                    Component {
                                        id: compactAppIconLoader
                                        Image {
                                            id: compactAppImage
                                            anchors.fill: parent
                                            source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon) : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: modelData.appIcon !== ""
                                            onStatusChanged: if (status == Image.Error) { compactFallbackIcon.visible = true; compactAppImage.visible = false; }
                                        }
                                    }

                                    DankIcon {
                                        id: compactFallbackIcon
                                        anchors.fill: parent
                                        name: modelData.isGroup ? "folder" : "extension"
                                        size: parent.width
                                        color: Theme.surfaceText
                                        visible: !modelData.isGroup ? (modelData.appIcon === "" || (typeof compactAppImage !== "undefined" && !compactAppImage.visible)) : compactDelegateRoot.currentGroupApps.length === 0
                                    }
                                }

                                StyledText {
                                    text: modelData.appName
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

        // Empty state placeholder
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: root.filteredApps.length === 0 && searchQuery === ""
            opacity: 0.4

            DankIcon {
                name: "mouse"
                size: 32
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.tr("Middle-click blank space to manage applications")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Modal Manager
    AppLauncherManagePopup {
        id: addAppDialog
        rootWidget: root
    }
}
