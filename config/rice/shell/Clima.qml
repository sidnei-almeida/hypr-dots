// Clima. O número vem do rice-clima (Open-Meteo, sem chave de API).
//
// O script devolve uma linha com dois campos: código WMO e temperatura.
// A tradução de código em ícone mora AQUI, e não no script, pela mesma
// razão do rice-sysstat: o script entrega dado, o QML decide aparência.
// Assim trocar o glifo não obriga a mexer em shell.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // -1 é "ainda não sei". Sem local configurado o script não imprime
    // nada, o valor nunca sai de -1 e o módulo fica invisível — é o que
    // faz o clima simplesmente não ocupar espaço até você escolher a
    // cidade, em vez de mostrar um traço ou um zero.
    property int codigo: -1
    property int temp: 0

    readonly property bool temValor: codigo >= 0

    // Códigos WMO agrupados pelo que muda o desenho. A tabela oficial
    // tem ~28 valores, mas vários são variações de intensidade que
    // dariam o mesmo ícone (chuva leve e chuva forte).
    readonly property string glifo: {
        const c = root.codigo
        if (c === 0)                 return "󰖙"   // céu limpo
        if (c === 1 || c === 2)      return "󰖕"   // parcialmente nublado
        if (c === 3)                 return "󰖐"   // encoberto
        if (c === 45 || c === 48)    return "󰖑"   // névoa
        if (c >= 51 && c <= 57)      return "󰖗"   // garoa
        if (c >= 61 && c <= 67)      return "󰖖"   // chuva
        if (c >= 71 && c <= 77)      return "󰖘"   // neve
        if (c >= 80 && c <= 82)      return "󰖖"   // pancadas
        if (c === 85 || c === 86)    return "󰖘"   // pancadas de neve
        if (c >= 95)                 return "󰖓"   // trovoada
        return "󰖐"
    }

    Process {
        id: consulta
        command: [PraxeConfig.bin + "rice-clima"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(/\s+/)
                if (p.length >= 2) {
                    root.codigo = parseInt(p[0])
                    root.temp   = parseInt(p[1])
                }
            }
        }
    }

    // Meia hora. O clima não muda em segundos e a API é de graça —
    // pedir de minuto em minuto seria só desperdício e risco de
    // rate-limit. O script ainda guarda um cache de 10min por cima
    // disto, que é o que protege contra os reloads do Quickshell.
    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: consulta.running = true
    }

    // Reconsulta quando você troca a cidade, sem esperar a meia hora.
    Connections {
        target: PraxeConfig
        function onWeatherLatChanged() { consulta.running = true }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.itemGap

        Text {
            text: root.glifo
            visible: root.temValor
            color: PraxeConfig.colMuted
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.iconSize
        }
        Text {
            text: root.temp + "°"
            visible: root.temValor
            color: PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
