import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../code/api.js" as Api

PlasmoidItem {
    id: root

    // Render directly inline inside the panel (no popup dialog)
    preferredRepresentation: fullRepresentation

    // Unique instance ID so multiple widgets on panels share the Api.js singleton cleanly
    readonly property string instanceId: "instance_" + String(Plasmoid.id || Math.random())

    // Current index data object from Api.js
    property var indexData: null
    readonly property bool hasData: indexData !== null && indexData.score !== undefined

    // User-configurable properties
    readonly property int dataSource: Plasmoid.configuration.dataSource || 0
    readonly property int updateInterval: Math.max(10, Plasmoid.configuration.updateInterval || 120)
    readonly property int barWidth: Math.max(60, Plasmoid.configuration.barWidth || 360)
    readonly property int barHeight: Math.max(8, Plasmoid.configuration.barHeight || 18)

    readonly property bool showIndicatorBar: Plasmoid.configuration.showIndicatorBar !== undefined
        ? Plasmoid.configuration.showIndicatorBar
        : true
    readonly property bool showSegmentLabels: Plasmoid.configuration.showSegmentLabels !== undefined
        ? Plasmoid.configuration.showSegmentLabels
        : true
    readonly property color segmentLabelsColor: Plasmoid.configuration.segmentLabelsColor || "#ffffff"
    readonly property bool showScoreNumber: Plasmoid.configuration.showScoreNumber !== undefined
        ? Plasmoid.configuration.showScoreNumber
        : true
    readonly property bool showStatusText: Plasmoid.configuration.showStatusText !== undefined
        ? Plasmoid.configuration.showStatusText
        : true

    // Five segments matching example.png:
    // Red -> Orange -> Yellow -> Light Green -> Dark Green
    readonly property var segments: [
        { label: i18n("Extreme Fear"), color: "#d62828" },
        { label: i18n("Fear"),         color: "#f47920" },
        { label: i18n("Neutral"),      color: "#eab311" },
        { label: i18n("Greed"),        color: "#22c55e" },
        { label: i18n("Extreme Greed"),color: "#15803d" }
    ]

    // Return the matching segment color for a given 0-100 score
    function getScoreColor(score) {
        const s = Number(score);
        if (s < 25) return "#d62828";
        if (s < 45) return "#f47920";
        if (s <= 55) return "#eab311";
        if (s <= 75) return "#22c55e";
        return "#15803d";
    }

    readonly property color currentStatusColor: root.hasData
        ? root.getScoreColor(root.indexData.score)
        : Kirigami.Theme.textColor

    Plasmoid.icon: "org.kde.plasma.fearandgreed"
    Plasmoid.title: i18n("Fear & Greed Index")

    toolTipMainText: {
        if (!root.hasData) {
            return i18n("Fear & Greed Index (Click to Refresh)");
        }
        return `${root.indexData.sourceName} (Click to Refresh)`;
    }

    toolTipSubText: {
        if (!root.hasData) {
            return i18n("Fetching Fear & Greed Index...");
        }
        const d = root.indexData;
        const lines = [
            `${i18n("Current")}: ${Math.round(d.score)} (${d.rating})`
        ];
        if (d.previousClose !== null && d.previousClose !== undefined && !isNaN(d.previousClose)) {
            lines.push(`${i18n("Previous Close")}: ${Math.round(d.previousClose)}`);
        }
        if (d.previousWeek !== null && d.previousWeek !== undefined && !isNaN(d.previousWeek)) {
            lines.push(`${i18n("1 Week Ago")}: ${Math.round(d.previousWeek)}`);
        }
        if (d.previousMonth !== null && d.previousMonth !== undefined && !isNaN(d.previousMonth)) {
            lines.push(`${i18n("1 Month Ago")}: ${Math.round(d.previousMonth)}`);
        }
        if (d.previousYear !== null && d.previousYear !== undefined && !isNaN(d.previousYear)) {
            lines.push(`${i18n("1 Year Ago")}: ${Math.round(d.previousYear)}`);
        }
        return lines.join("\n");
    }

    function syncWithApi(forceRefresh) {
        Api.registerInstance(root.instanceId, root.dataSource, function(result) {
            root.indexData = result || null;
        });
        Api.refreshAllInstances(forceRefresh);
    }

    Component.onCompleted: {
        syncWithApi(false);
    }

    Component.onDestruction: {
        Api.unregisterInstance(root.instanceId);
    }

    // Refresh data every N seconds (default 120s / 2 minutes).
    Timer {
        id: refreshTimer
        interval: root.updateInterval * 1000
        running: true
        repeat: true
        onTriggered: {
            Api.refreshAllInstances(false);
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onDataSourceChanged() {
            syncWithApi(true);
        }
        function onUpdateIntervalChanged() {
            refreshTimer.restart();
        }
    }

    fullRepresentation: Item {
        id: panelContainer

        readonly property real targetWidth: {
            if (!root.hasData) {
                return loadingLabel.implicitWidth + Kirigami.Units.largeSpacing * 2;
            }
            return Math.max(24, contentRow.implicitWidth + Kirigami.Units.largeSpacing * 2);
        }

        readonly property real targetHeight: {
            const barH = root.showIndicatorBar ? (root.barHeight + 8) : 0;
            const textH = statusRow.visible ? (statusRow.implicitHeight + 4) : 0;
            return Math.max(16, barH, textH);
        }

        Layout.minimumWidth: targetWidth
        Layout.preferredWidth: targetWidth
        Layout.maximumWidth: targetWidth
        Layout.minimumHeight: targetHeight
        Layout.preferredHeight: targetHeight
        Layout.fillHeight: true

        // Loading indicator before first data arrives
        PlasmaComponents.Label {
            id: loadingLabel
            anchors.centerIn: parent
            visible: !root.hasData
            text: i18n("Loading Fear & Greed...")
            font.bold: true
            opacity: 0.7
        }

        // Main inline panel layout: [5-Segment Indicator Bar + White Marker] [Score & Status]
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing
            visible: root.hasData

            // =====================================================================
            // LEFT: 5-Segment Fear & Greed Bar with White Marker Line (example.png)
            // =====================================================================
            Item {
                id: gaugeWrapper
                visible: root.showIndicatorBar
                width: root.barWidth
                height: root.barHeight + 8
                anchors.verticalCenter: parent.verticalCenter

                // 5 equal colored segments placed side-by-side
                Row {
                    id: segmentsRow
                    width: root.barWidth
                    height: root.barHeight
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: root.segments

                        delegate: Rectangle {
                            readonly property real baseSegWidth: Math.floor(root.barWidth / root.segments.length)
                            width: index === (root.segments.length - 1)
                                ? (root.barWidth - baseSegWidth * (root.segments.length - 1))
                                : baseSegWidth
                            height: root.barHeight
                            color: modelData.color
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                visible: root.showIndicatorBar && root.showSegmentLabels && root.barWidth >= 180 && root.barHeight >= 12
                                text: modelData.label
                                color: root.segmentLabelsColor
                                font.bold: true
                                font.pixelSize: Math.max(7, Math.min(11, Math.floor(root.barHeight * 0.48)))
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 6
                            }
                        }
                    }
                }

                // Subtle outer border around the segmented bar
                Rectangle {
                    anchors.fill: segmentsRow
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                }

                // Dark shadow behind the white vertical marker line for high contrast
                Rectangle {
                    id: markerShadow
                    readonly property real scoreRatio: root.hasData
                        ? Math.max(0, Math.min(1, Number(root.indexData.score) / 100.0))
                        : 0.5
                    width: 5
                    height: root.barHeight + 8
                    radius: 2.5
                    color: Qt.rgba(0, 0, 0, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(root.barWidth - width, scoreRatio * root.barWidth - width / 2))

                    Behavior on x {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // White vertical marker line protruding slightly above & below the bar (as in example.png)
                Rectangle {
                    id: markerLine
                    width: 3
                    height: root.barHeight + 8
                    radius: 1.5
                    color: "#ffffff"
                    border.color: Qt.rgba(0.85, 0.85, 0.85, 0.9)
                    border.width: 0.5
                    anchors.centerIn: markerShadow
                }
            }

            // =====================================================================
            // RIGHT: Fear & Greed Number + Current Status Label
            // =====================================================================
            Row {
                id: statusRow
                visible: root.showScoreNumber || root.showStatusText
                spacing: Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter

                // Numeric Score (e.g., 28)
                PlasmaComponents.Label {
                    id: scoreLabel
                    visible: root.showScoreNumber
                    text: root.hasData ? String(Math.round(root.indexData.score)) : "--"
                    font.bold: true
                    color: root.currentStatusColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Status Text (e.g., Fear) — same color as the score and current Fear & Greed status
                PlasmaComponents.Label {
                    id: ratingLabel
                    visible: root.showStatusText
                    text: root.hasData ? root.indexData.rating : ""
                    font.bold: true
                    color: root.currentStatusColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Api.refreshAllInstances(true);
            }
        }
    }
}
