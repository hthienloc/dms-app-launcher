import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    id: root
    pluginId: "dmsAppLauncher"

    SettingsCard {
        SectionTitle { text: I18n.tr("Launcher Options") }

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
    }
}
