import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    // Desktop widget dimensions
    minWidth: 240
    minHeight: 320
    widgetWidth: pluginData.widgetWidth !== undefined ? pluginData.widgetWidth : 360
    widgetHeight: pluginData.widgetHeight !== undefined ? pluginData.widgetHeight : 480

    // Properties for search, category filtering, and added apps
    property string searchQuery: ""
    property string selectedCategory: "All"
    
    // Load added apps from persistent settings
    property var addedApps: pluginData.addedApps !== undefined ? pluginData.addedApps : []
    property var allAppsList: addedApps

    // Categories list (English key, friendly Vietnamese translated label, and icon)
    readonly property var categoriesList: [
        { key: "All", label: I18n.tr("All"), icon: "apps" },
        { key: "Internet", label: I18n.tr("Internet"), icon: "language" },
        { key: "Development", label: I18n.tr("Development"), icon: "code" },
        { key: "Game", label: I18n.tr("Game"), icon: "sports_esports" },
        { key: "Graphics", label: I18n.tr("Graphics"), icon: "palette" },
        { key: "Office", label: I18n.tr("Office"), icon: "description" },
        { key: "Multimedia", label: I18n.tr("Multimedia"), icon: "movie" },
        { key: "System", label: I18n.tr("System"), icon: "settings" },
        { key: "Utility", label: I18n.tr("Utility"), icon: "build" }
    ]

    // ListModel for active filtered apps
    ListModel {
        id: filteredModel
    }

    // Filter addedApps based on search query and category
    function updateFilteredModel() {
        filteredModel.clear();
        const search = searchQuery.toLowerCase().trim();
        const category = selectedCategory;

        for (let app of allAppsList) {
            const matchesSearch = search === "" || 
                                  app.name.toLowerCase().indexOf(search) !== -1 ||
                                  (app.exec && app.exec.toLowerCase().indexOf(search) !== -1);
            
            const matchesCategory = category === "All" || 
                                    (app.categories && app.categories.indexOf(category) !== -1);

            if (matchesSearch && matchesCategory) {
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
    onSelectedCategoryChanged: updateFilteredModel()
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
        color: Theme.withAlpha(Theme.surfaceContainer, 0.75)
        radius: Theme.cornerRadius
        border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
        border.width: root.editMode ? 2 : 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Top: Search Bar and Add Button
            Row {
                width: parent.width
                spacing: Theme.spacingS
                height: 36

                // Styled Search Box
                Rectangle {
                    id: searchContainer
                    width: parent.width - 44
                    height: parent.height
                    radius: Theme.cornerRadiusSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.04)
                    border.color: searchField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    DankIcon {
                        id: searchIcon
                        name: "search"
                        size: 16
                        color: Theme.surfaceText
                        opacity: searchField.activeFocus ? 1.0 : 0.5
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchField
                        anchors.left: searchIcon.right
                        anchors.leftMargin: Theme.spacingXS
                        anchors.right: clearBtn.visible ? clearBtn.left : parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceText
                        selectByMouse: true
                        focus: true
                        
                        onTextChanged: {
                            root.searchQuery = text;
                        }

                        Text {
                            text: I18n.tr("Search launcher...")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceText
                            opacity: 0.35
                            visible: searchField.text === "" && !searchField.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: clearBtn
                        width: 20
                        height: 20
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length > 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            searchField.text = "";
                            root.searchQuery = "";
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: Theme.surfaceText
                            opacity: clearBtn.containsMouse ? 0.8 : 0.4
                        }
                    }
                }

                // Add App Button
                MouseArea {
                    id: addBtn
                    width: 36
                    height: 36
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        addAppDialog.openDialog();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadiusSmall
                        color: addBtn.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.03)
                        border.color: Theme.withAlpha(Theme.outline, 0.15)
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 16
                            color: Theme.surfaceText
                            opacity: addBtn.containsMouse ? 1.0 : 0.7
                        }
                    }
                }
            }

            // Categories list: horizontal scrolling chips
            ScrollView {
                width: parent.width
                height: 32
                contentWidth: categoriesRow.width
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                Row {
                    id: categoriesRow
                    spacing: Theme.spacingXS
                    height: parent.height

                    Repeater {
                        model: root.categoriesList

                        delegate: MouseArea {
                            id: chipArea
                            width: chipRow.implicitWidth + Theme.spacingS * 2
                            height: 28
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                root.selectedCategory = modelData.key;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: root.selectedCategory === modelData.key
                                    ? Theme.primary
                                    : (chipArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                                border.color: root.selectedCategory === modelData.key
                                    ? "transparent"
                                    : Theme.withAlpha(Theme.outline, 0.15)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: modelData.icon
                                        size: 14
                                        color: root.selectedCategory === modelData.key ? Theme.primaryText : Theme.surfaceText
                                        opacity: root.selectedCategory === modelData.key ? 1.0 : 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: root.selectedCategory === modelData.key
                                        color: root.selectedCategory === modelData.key ? Theme.primaryText : Theme.surfaceText
                                        opacity: root.selectedCategory === modelData.key ? 1.0 : 0.85
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Apps Grid
            GridView {
                id: appsGrid
                width: parent.width
                height: parent.height - 36 - 32 - Theme.spacingS * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                
                // Dynamically fit 3-5 columns based on widget width
                cellWidth: Math.floor(width / Math.max(3, Math.floor(width / 76)))
                cellHeight: 88

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
                            Quickshell.execDetached(["sh", "-c", appExec]);
                        }

                        // App Card Hover Highlights
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadiusSmall
                            color: appCard.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"
                            border.color: appCard.containsMouse ? Theme.withAlpha(Theme.outline, 0.1) : "transparent"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            spacing: Theme.spacingXS
                            anchors.centerIn: parent

                            // App Icon
                            Item {
                                width: parent.width
                                height: 38
                                
                                Image {
                                    id: appImage
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
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
                                    anchors.centerIn: parent
                                    name: "extension"
                                    size: 32
                                    color: Theme.surfaceText
                                    visible: appIcon === "" || !appImage.visible
                                    scale: appCard.containsMouse ? 1.08 : 1.0
                                }
                            }

                            // App Name
                            StyledText {
                                width: parent.width
                                text: appName
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                                opacity: appCard.containsMouse ? 1.0 : 0.8
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

            // Placeholder when widget is empty
            StyledText {
                text: I18n.tr("Click + to add applications")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                opacity: 0.4
                anchors.centerIn: parent
                visible: filteredModel.count === 0 && searchQuery === ""
            }
        }
    }

    // Modal popup to select and add system applications
    Popup {
        id: addAppDialog
        parent: root
        width: Math.min(320, root.width - 20)
        height: Math.min(400, root.height - 20)
        anchors.centerIn: parent
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var systemAppsList: []
        property string systemAppsSearch: ""

        background: Rectangle {
            color: "transparent"
        }

        // Trigger scan only when user wants to add an app
        function openDialog() {
            systemAppsSearch = "";
            systemSearchField.text = "";
            addAppDialog.open();
            
            const homePath = Quickshell.env("HOME");
            const scriptPath = homePath + "/.config/DankMaterialShell/plugins/dmsAppLauncher/scan_apps.py";
            
            Proc.runCommand(
                "dmsAppLauncher.scanSystem",
                [scriptPath],
                (stdout, exitCode) => {
                    if (exitCode === 0) {
                        try {
                            addAppDialog.systemAppsList = JSON.parse(stdout);
                        } catch (e) {
                            console.log("Error parsing system apps: " + e);
                        }
                    }
                }
            );
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                // Dialog Header
                Row {
                    width: parent.width
                    height: 24
                    
                    StyledText {
                        text: I18n.tr("Add Applications")
                        font.bold: true
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - implicitWidth - 24
                        height: 1
                    }

                    // Close Dialog Button
                    MouseArea {
                        width: 24
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addAppDialog.close()
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
                    radius: Theme.cornerRadiusSmall
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
                        radius: Theme.cornerRadiusSmall - 2
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
