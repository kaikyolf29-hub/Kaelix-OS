// Cartão que se clica (um app, uma categoria, um site): com o mouse em cima, sobe
// um pouco, clareia e ganha uma sombra macia; apertando, afunda de leve. O que vai
// dentro dele sobe junto. É um MouseArea: onClicked, containsMouse e pressed valem.
//   CartaoClicavel {
//       width: ...; height: ...
//       onClicked: ...
//       RowLayout { anchors.fill: parent; anchors.margins: janela.gu; ... }
//   }
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

MouseArea {
    id: cartao

    property real raio: Math.round(janela.gu * 0.6)
    // false: só clareia com o mouse (sem subir nem sombra).
    property bool elevar: true
    default property alias conteudo: fundo.data

    // 0 parado, 1 com o mouse em cima (sobe e a sombra aparece juntos).
    property real elevacao: elevar && containsMouse ? 1 : 0
    Behavior on elevacao {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button

    RectangularShadow {
        anchors.fill: fundo
        transform: Translate {
            y: deslize.y
        }
        visible: cartao.elevacao > 0.01
        opacity: cartao.elevacao
        radius: cartao.raio
        offset.y: Math.round(janela.gu * 0.35)
        blur: Math.round(janela.gu * 1.1)
        spread: -Math.round(janela.gu * 0.2)
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.5 : 0.16)
    }

    Rectangle {
        id: fundo
        anchors.fill: parent
        transform: Translate {
            id: deslize
            y: -Math.round(janela.gu * 0.2) * cartao.elevacao
        }
        scale: cartao.pressed ? 0.985 : 1
        radius: cartao.raio
        color: cartao.containsMouse ? (janela.escuro ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.85)) : janela.cartao
        border.width: 1
        border.color: cartao.activeFocus ? janela.destaque : janela.tinta(cartao.containsMouse ? 0.13 : (janela.escuro ? 0.07 : 0.08))
        Behavior on scale {
            NumberAnimation {
                duration: 120
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
