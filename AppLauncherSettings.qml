import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "dmsAppLauncher"

    SettingsCard {
        id: layoutSection
        SectionTitle { 
            text: I18n.tr("Layout & Dimensions")
            icon: "aspect_ratio" 
            showReset: widgetWidth.isDirty || widgetHeight.isDirty || appSize.isDirty
            onResetClicked: {
                widgetWidth.resetToDefault();
                widgetHeight.resetToDefault();
                appSize.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: widgetWidth
            settingKey: "widgetWidth"
            label: I18n.tr("Default Width")
            defaultValue: 360
            minimum: 240
            maximum: 600
            unit: "px"
            leftLabel: "240"
            rightLabel: "600"
        }

        Separator {}

        SliderSettingPlus {
            id: widgetHeight
            settingKey: "widgetHeight"
            label: I18n.tr("Default Height")
            defaultValue: 480
            minimum: 320
            maximum: 800
            unit: "px"
            leftLabel: "320"
            rightLabel: "800"
        }

        Separator {}

        SliderSettingPlus {
            id: appSize
            settingKey: "appSize"
            label: I18n.tr("App Icon Size")
            defaultValue: 88
            minimum: 64
            maximum: 128
            unit: "px"
            leftLabel: "64"
            rightLabel: "128"
        }
    }

    SettingsCard {
        id: appearanceSection
        SectionTitle { 
            text: I18n.tr("Appearance & Style")
            icon: "palette" 
            showReset: backgroundOpacity.isDirty || viewMode.isDirty || showHeader.isDirty
            onResetClicked: {
                backgroundOpacity.resetToDefault();
                viewMode.resetToDefault();
                showHeader.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: backgroundOpacity
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0%"
            rightLabel: "100%"
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: viewMode
            settingKey: "viewMode"
            label: I18n.tr("View Mode")
            options: [
                { label: I18n.tr("Grid View"), value: "grid" },
                { label: I18n.tr("List View"), value: "list" },
                { label: I18n.tr("Compact View"), value: "compact" }
            ]
            defaultValue: "grid"
        }

        Separator {}

        ToggleSettingPlus {
            id: showHeader
            settingKey: "showHeader"
            label: I18n.tr("Show Launcher Header")
            description: I18n.tr("Show a top header bar with title and search.")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Left-click</b> an app icon to launch it."),
                I18n.tr("<b>Left-click</b> a group to expand its contents."),
                I18n.tr("<b>Middle-click</b> a group to <b>launch all</b> contained apps."),
                I18n.tr("<b>Middle-click</b> the background to <b>add or manage</b> applications."),
                I18n.tr("<b>Resize</b> the launcher window directly from the corners.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-app-launcher"
    }
}
