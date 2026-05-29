import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "dmsAppLauncher"

    SettingsCard {
        SectionTitle { text: I18n.tr("Launcher Options"); icon: "apps" }

        SliderSetting {
            settingKey: "widgetWidth"
            label: I18n.tr("Default Width")
            defaultValue: 360
            minimum: 240
            maximum: 600
            unit: "px"
        }

        SliderSetting {
            settingKey: "widgetHeight"
            label: I18n.tr("Default Height")
            defaultValue: 480
            minimum: 320
            maximum: 800
            unit: "px"
        }

        SliderSetting {
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SliderSetting {
            settingKey: "appSize"
            label: I18n.tr("App Icon Size")
            description: I18n.tr("Adjust the size of application launcher items.")
            defaultValue: 88
            minimum: 64
            maximum: 128
            unit: "px"
        }

        SelectionSetting {
            settingKey: "viewMode"
            label: I18n.tr("View Mode")
            description: I18n.tr("Choose how applications are displayed.")
            options: [
                { label: I18n.tr("Grid View"), value: "grid" },
                { label: I18n.tr("List View"), value: "list" },
                { label: I18n.tr("Compact View"), value: "compact" }
            ]
            defaultValue: "grid"
        }

        ToggleSetting {
            settingKey: "showHeader"
            label: I18n.tr("Show Launcher Header")
            description: I18n.tr("Show a top header bar with title and search.")
            defaultValue: true
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-app-launcher"
    }
}
