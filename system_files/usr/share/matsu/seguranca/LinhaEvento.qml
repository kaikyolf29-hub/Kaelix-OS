// Um acontecimento do histórico: ícone redondo na cor do tipo, o que foi e quando.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

RowLayout {
    id: linha

    property var evento: ({})
    // "hora": só a hora (a lista já separa os dias); "quando": "ontem às 18:05".
    property bool soHora: false
    readonly property var d: janela.descrever(evento)

    spacing: Math.round(janela.gu * 0.7)

    IconeRedondo {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Math.round(janela.gu * 2)
        icone: linha.d.icone
        cor: linha.d.cor
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Texto {
            Layout.fillWidth: true
            text: linha.d.titulo
            elide: Text.ElideRight
        }
        Texto {
            Layout.fillWidth: true
            visible: text.length > 0
            text: linha.d.texto
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            elide: Text.ElideMiddle
        }
    }
    Texto {
        Layout.alignment: Qt.AlignVCenter
        text: linha.soHora ? janela.hora(linha.evento.data || 0) : janela.quando(linha.evento.data || 0)
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.features: { "tnum": 1 }
        opacity: 0.55
    }
}
