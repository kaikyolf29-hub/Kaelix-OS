// O pequeno "Salvo ✓" do alto do editor: aparece quando o arquivo é gravado
// (o visto pula) e some devagar depois de um instante.
import QtQuick
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: selo

    implicitWidth: linha.implicitWidth
    implicitHeight: linha.implicitHeight
    opacity: 0
    visible: opacity > 0

    readonly property color verde: janela.escuro ? "#5fd39a" : "#1f8a52"

    Connections {
        target: janela
        function onSalvou() {
            mostrar.restart();
        }
    }

    SequentialAnimation {
        id: mostrar
        ParallelAnimation {
            NumberAnimation { target: selo; property: "opacity"; to: 1; duration: 160 }
            NumberAnimation { target: visto; property: "scale"; from: 0.3; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
            NumberAnimation { target: linha; property: "x"; from: -4; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: selo; property: "opacity"; to: 0; duration: 500; easing.type: Easing.InQuad }
    }

    Row {
        id: linha
        spacing: Math.round(janela.gu * 0.25)
        Kirigami.Icon {
            id: visto
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Kirigami.Units.iconSizes.small * 0.85)
            height: width
            source: "matsu-certo-symbolic"
            isMask: true
            color: selo.verde
        }
        Texto {
            anchors.verticalCenter: parent.verticalCenter
            text: janela.t("Salvo", "Saved")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: selo.verde
        }
    }
}
