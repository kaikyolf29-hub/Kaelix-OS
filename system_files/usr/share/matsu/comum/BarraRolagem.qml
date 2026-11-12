// Barra de rolagem dos apps do Matsu: uma pílula fina e discreta, sem trilho e
// sem a linha do tema do KDE, que engrossa e fica mais forte com o mouse em
// cima ou arrastando (como no Windows 11). Some quando não há o que rolar.
// Uso: QQC2.ScrollBar.vertical: BarraRolagem {}
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

T.ScrollBar {
    id: barra

    readonly property bool deEmPe: orientation === Qt.Vertical
    readonly property bool emUso: hovered || pressed
    readonly property int grossura: Math.round(janela.gu * 0.75)

    implicitWidth: deEmPe ? grossura : Math.round(janela.gu * 5)
    implicitHeight: deEmPe ? Math.round(janela.gu * 5) : grossura
    padding: Math.max(2, Math.round(janela.gu * 0.15))
    hoverEnabled: true
    // A pílula nunca fica pequena demais para pegar com o mouse.
    minimumSize: {
        var tamanho = deEmPe ? height : width;
        return tamanho > 0 ? Math.min(1, janela.gu * 2.4 / tamanho) : 0.1;
    }
    visible: policy !== T.ScrollBar.AlwaysOff && size < 1.0

    contentItem: Item {
        implicitWidth: barra.grossura
        implicitHeight: barra.grossura

        Rectangle {
            // Parada: um fio no canto; com o mouse: a pílula inteira.
            readonly property real fino: Math.max(3, Math.round(barra.grossura * 0.4))
            anchors.right: barra.deEmPe ? parent.right : undefined
            anchors.bottom: barra.deEmPe ? undefined : parent.bottom
            width: barra.deEmPe ? (barra.emUso ? parent.width : fino) : parent.width
            height: barra.deEmPe ? parent.height : (barra.emUso ? parent.height : fino)
            radius: Math.min(width, height) / 2
            color: janela.tinta(barra.pressed ? 0.48 : (barra.emUso ? 0.36 : 0.22))

            Behavior on width {
                enabled: barra.deEmPe
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !barra.deEmPe
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }
}
