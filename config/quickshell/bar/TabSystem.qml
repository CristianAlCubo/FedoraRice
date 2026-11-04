import QtQuick
import QtQuick.Layouts

// Pestaña Sistema: CPU, GPU, memoria, VRAM, disco y red.
Item {
    id: tab
    required property var stats
    property bool focused: false
    readonly property bool interactive: false
    function handleKey(k) { return false }

    function rate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024) return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }
    function temp(t) { return t > 0 ? Math.round(t) + " °C" : "—" }

    GridLayout {
        anchors.fill: parent
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "CPU"
            valueText: Math.round(tab.stats.cpu * 100) + "%"
            subText: tab.temp(tab.stats.cpuTemp)
            ratio: tab.stats.cpu
            history: tab.stats.cpuHist
        }
        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "GPU"
            tint: Theme.accent2
            valueText: Math.round(tab.stats.gpu * 100) + "%"
            subText: tab.temp(tab.stats.gpuTemp)
            ratio: tab.stats.gpu
            history: tab.stats.gpuHist
        }
        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "Memoria"
            tint: Theme.green
            valueText: tab.stats.memUsedGb.toFixed(1) + " GB"
            subText: "de " + tab.stats.memTotalGb.toFixed(1) + " GB"
            ratio: tab.stats.mem
            history: tab.stats.memHist
        }
        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "VRAM"
            tint: Theme.accent2
            valueText: tab.stats.vramUsedGb.toFixed(1) + " GB"
            subText: "de " + tab.stats.vramTotalGb.toFixed(1) + " GB"
            ratio: tab.stats.vram
            history: tab.stats.vramHist
        }
        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "Disco"
            valueText: Math.round(tab.stats.diskUsedGb) + " GB"
            subText: "de " + Math.round(tab.stats.diskTotalGb) + " GB"
            ratio: tab.stats.diskTotalGb > 0 ? tab.stats.diskUsedGb / tab.stats.diskTotalGb : 0
        }
        StatCard {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
            title: "Red"
            tint: Theme.green
            valueText: "↓ " + tab.rate(tab.stats.netDown)
            subText: "↑ " + tab.rate(tab.stats.netUp)
            history: tab.stats.netHist
            maxValue: 0
        }
    }
}
