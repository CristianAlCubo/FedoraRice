import QtQuick
import Quickshell
import Quickshell.Io

// Métricas del sistema con historial (60 muestras = 2 min a 2 s).
// CPU, RAM y red se leen siempre de /proc (barato). GPU, disco y temperatura
// se consultan solo mientras `active` sea true (cuando el dashboard está abierto).
Scope {
    id: st

    property bool active: false
    readonly property int keep: 60

    property real cpu: 0
    property real cpuTemp: 0
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real gpu: 0
    property real gpuTemp: 0
    property real vram: 0
    property real vramUsedGb: 0
    property real vramTotalGb: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property real netDown: 0      // bytes/s
    property real netUp: 0

    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    property var vramHist: []
    property var netHist: []

    function push(prop, v) {
        const a = st[prop].slice(-(keep - 1))
        a.push(v)
        st[prop] = a
    }

    property var _prevCpu: null
    property var _prevNet: null

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.reduce((a, b) => a + b, 0)
            if (st._prevCpu) {
                const dt = total - st._prevCpu.total
                if (dt > 0) st.cpu = Math.max(0, Math.min(1, 1 - (idle - st._prevCpu.idle) / dt))
            }
            st._prevCpu = { total: total, idle: idle }
            st.push("cpuHist", st.cpu)
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const m = {}
            text().split("\n").forEach(l => {
                const x = l.match(/^(\w+):\s+(\d+)/)
                if (x) m[x[1]] = Number(x[2])
            })
            if (m.MemTotal) {
                st.memTotalGb = m.MemTotal / 1048576
                st.memUsedGb = (m.MemTotal - m.MemAvailable) / 1048576
                st.mem = 1 - m.MemAvailable / m.MemTotal
                st.push("memHist", st.mem)
            }
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0
            text().split("\n").slice(2).forEach(l => {
                const m = l.trim().match(/^([^:]+):\s*(.*)$/)
                if (!m) return
                if (m[1] === "lo" || /^(br-|docker|veth|virbr)/.test(m[1])) return
                const f = m[2].split(/\s+/).map(Number)
                rx += f[0]; tx += f[8]
            })
            const now = Date.now()
            if (st._prevNet) {
                const dt = (now - st._prevNet.t) / 1000
                if (dt > 0) {
                    st.netDown = Math.max(0, (rx - st._prevNet.rx) / dt)
                    st.netUp = Math.max(0, (tx - st._prevNet.tx) / dt)
                }
            }
            st._prevNet = { rx: rx, tx: tx, t: now }
            st.push("netHist", st.netDown)
        }
    }

    Process {
        id: extra
        command: ["sh", "-c",
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | sed 's/^/gpu=/'; " +
            "df -B1 --output=used,size / 2>/dev/null | tail -1 | sed 's/^/disk=/'; " +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in k10temp|coretemp) echo \"cput=$(cat $h/temp1_input)\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(line => {
                    const i = line.indexOf("=")
                    if (i < 0) return
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "gpu") {
                        const f = v.split(",").map(s => Number(s.trim()))
                        st.gpu = f[0] / 100
                        st.vramUsedGb = f[1] / 1024
                        st.vramTotalGb = f[2] / 1024
                        st.vram = f[2] > 0 ? f[1] / f[2] : 0
                        st.gpuTemp = f[3]
                        st.push("gpuHist", st.gpu)
                        st.push("vramHist", st.vram)
                    } else if (k === "disk") {
                        const f = v.split(/\s+/).map(Number)
                        st.diskUsedGb = f[0] / 1073741824
                        st.diskTotalGb = f[1] / 1073741824
                    } else if (k === "cput") {
                        st.cpuTemp = Number(v) / 1000
                    }
                })
            }
        }
    }

    onActiveChanged: if (active && !extra.running) extra.running = true

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload(); netFile.reload()
            if (st.active && !extra.running) extra.running = true
        }
    }
}
