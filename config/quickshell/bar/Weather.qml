pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clima actual desde Open-Meteo (sin clave). Ubicación en ~/.config/rice/shell.json → "weather".
Singleton {
    id: w

    property bool ok: false
    property real temp: 0
    property real feels: 0
    property real hi: 0
    property real lo: 0
    property int humidity: 0
    property real wind: 0
    property int rain: 0
    property int code: 0
    property bool isDay: true
    property date updated: new Date(0)

    readonly property string city: Cfg.weather.name ?? "—"
    readonly property string desc: describe(code)
    readonly property string glyph: iconFor(code, isDay)

    function describe(c) {
        if (c === 0) return "Despejado"
        if (c === 1) return "Poco nuboso"
        if (c === 2) return "Nubes y claros"
        if (c === 3) return "Nublado"
        if (c === 45 || c === 48) return "Niebla"
        if (c >= 51 && c <= 57) return "Llovizna"
        if (c >= 61 && c <= 67) return "Lluvia"
        if (c >= 71 && c <= 77) return "Nieve"
        if (c >= 80 && c <= 82) return "Chubascos"
        if (c === 85 || c === 86) return "Nevadas"
        if (c >= 95) return "Tormenta"
        return "—"
    }
    // Material Design Icons (Nerd Font): nf-md-weather-*
    function iconFor(c, day) {
        const g = n => String.fromCodePoint(n)
        if (c === 0 || c === 1) return day ? g(0xF0599) : g(0xF0594)
        if (c === 2) return g(0xF0595)
        if (c === 3) return g(0xF0590)
        if (c === 45 || c === 48) return g(0xF0591)
        if ((c >= 51 && c <= 57) || (c >= 61 && c <= 65)) return g(0xF0597)
        if (c === 66 || c === 67 || (c >= 80 && c <= 82)) return g(0xF0596)
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return g(0xF0598)
        if (c >= 95) return g(0xF067E)
        return g(0xF0590)
    }

    function refresh() {
        if (fetch.running) return
        const lat = Cfg.weather.lat, lon = Cfg.weather.lon
        if (lat === undefined || lon === undefined) return
        fetch.command = ["curl", "-sf", "-m", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            + "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"]
        fetch.running = true
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const c = d.current, dl = d.daily
                    w.temp = c.temperature_2m; w.feels = c.apparent_temperature
                    w.humidity = c.relative_humidity_2m; w.code = c.weather_code
                    w.isDay = c.is_day === 1; w.wind = c.wind_speed_10m
                    w.hi = dl.temperature_2m_max[0]; w.lo = dl.temperature_2m_min[0]
                    w.rain = dl.precipitation_probability_max[0] ?? 0
                    w.updated = new Date(); w.ok = true
                } catch (e) { /* sin red: se conserva el último dato */ }
            }
        }
    }
    Timer {
        interval: Math.max(5, Cfg.weather.refreshMin ?? 30) * 60000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: w.refresh()
    }
    // Reintenta al cambiar la ubicación en shell.json
    Connections { target: Cfg; function onWeatherChanged() { w.refresh() } }
}
