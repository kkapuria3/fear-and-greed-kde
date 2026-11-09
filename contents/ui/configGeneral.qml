import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: configPage

    property alias cfg_dataSource: dataSourceCombo.currentIndex
    property alias cfg_updateInterval: updateIntervalSpinBox.value
    property alias cfg_barWidth: barWidthSpinBox.value
    property alias cfg_barHeight: barHeightSpinBox.value
    property alias cfg_showIndicatorBar: showIndicatorBarCheckBox.checked
    property alias cfg_showSegmentLabels: showSegmentLabelsCheckBox.checked
    property alias cfg_segmentLabelsColor: segmentLabelsColorButton.color
    property alias cfg_showScoreNumber: showScoreNumberCheckBox.checked
    property alias cfg_showStatusText: showStatusTextCheckBox.checked

    property int cfg_dataSourceDefault: 0
    property int cfg_updateIntervalDefault: 120
    property int cfg_barWidthDefault: 360
    property int cfg_barHeightDefault: 18
    property bool cfg_showIndicatorBarDefault: true
    property bool cfg_showSegmentLabelsDefault: true
    property color cfg_segmentLabelsColorDefault: "#ffffff"
    property bool cfg_showScoreNumberDefault: true
    property bool cfg_showStatusTextDefault: true

    Kirigami.FormLayout {
        ComboBox {
            id: dataSourceCombo
            Kirigami.FormData.label: i18n("Data Source:")
            model: [
                i18n("CNN Stock Market Fear & Greed Index"),
                i18n("Crypto Fear & Greed Index (Alternative.me)")
            ]
            Layout.fillWidth: true
        }

        SpinBox {
            id: updateIntervalSpinBox
            Kirigami.FormData.label: i18n("Refresh interval (seconds):")
            from: 10
            to: 3600
            stepSize: 10
            value: 120
        }

        Label {
            text: i18n("Default is 120 seconds (2 minutes), making ~30 requests/hour — well within free API rate limits.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dimensions & Appearance")
        }

        SpinBox {
            id: barWidthSpinBox
            enabled: showIndicatorBarCheckBox.checked
            Kirigami.FormData.label: i18n("Indicator Bar Width (px):")
            from: 60
            to: 1000
            stepSize: 10
            value: 360
        }

        SpinBox {
            id: barHeightSpinBox
            enabled: showIndicatorBarCheckBox.checked
            Kirigami.FormData.label: i18n("Indicator Bar Height (px):")
            from: 8
            to: 120
            stepSize: 2
            value: 18
        }

        CheckBox {
            id: showIndicatorBarCheckBox
            Kirigami.FormData.label: i18n("Indicator Bar:")
            text: i18n("Show Fear & Greed color bar indicator")
        }

        CheckBox {
            id: showSegmentLabelsCheckBox
            enabled: showIndicatorBarCheckBox.checked
            Kirigami.FormData.label: i18n("Segment Labels:")
            text: i18n("Show text inside segments (Extreme Fear, Fear, Neutral, Greed, Extreme Greed)")
        }

        KQuickControls.ColorButton {
            id: segmentLabelsColorButton
            enabled: showIndicatorBarCheckBox.checked && showSegmentLabelsCheckBox.checked
            Kirigami.FormData.label: i18n("Segment Labels Color:")
            dialogTitle: i18n("Choose Segment Labels Color")
            showAlphaChannel: true
        }

        CheckBox {
            id: showScoreNumberCheckBox
            Kirigami.FormData.label: i18n("Score Number:")
            text: i18n("Show Fear & Greed numeric score (0–100) on the right")
        }

        CheckBox {
            id: showStatusTextCheckBox
            Kirigami.FormData.label: i18n("Status Text:")
            text: i18n("Show Fear & Greed status label (e.g. Fear, Greed) on the right")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Notes & API Guidelines")
        }

        Kirigami.InlineMessage {
            visible: true
            type: Kirigami.MessageType.Information
            showCloseButton: false
            Layout.fillWidth: true
            text: i18n("<b>Free API & Rate Limits:</b> No API key is required.<br>Multiple widgets on your panels automatically share cached responses per data source to minimize network calls.")
        }

        Label {
            text: i18n("• <b>CNN Stock Market Index:</b> Fetches live S&P 500 & market sentiment data from CNN's public dataviz endpoint.<br>" +
                       "• <b>Crypto Index (Alternative.me):</b> Fetches the live Crypto Fear & Greed Index from <code>api.alternative.me/fng/</code>.<br>" +
                       "• <b>Rate Limits:</b> At the default 120-second (2-minute) interval, the widget makes only 30 requests/hour.")
            font: Kirigami.Theme.smallFont
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            opacity: 0.85
        }
    }
}
