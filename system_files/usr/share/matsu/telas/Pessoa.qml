// A foto da pessoa num círculo com a borda de vidro, e o nome embaixo. Sem foto,
// aparece a primeira letra do nome num círculo de vidro (nada do ícone genérico).
// Com "escolhida: false" (outra pessoa na tela de login), fica menor e apagada.
import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: pessoa

    property string nome: ""
    property string foto: ""     // caminho ou URL da imagem
    property real lado: 80
    property bool escolhida: true
    property bool mostrarNome: true
    signal clicada()

    readonly property bool temFoto: foto !== "" && imagem.status === Image.Ready
    readonly property string inicial: nome.trim().length > 0 ? nome.trim().charAt(0).toUpperCase() : "?"

    implicitWidth: Math.max(lado, rotulo.implicitWidth)
    implicitHeight: lado + (mostrarNome ? rotulo.anchors.topMargin + rotulo.implicitHeight : 0)
    opacity: escolhida ? 1 : 0.62
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    Item {
        id: circulo
        anchors.horizontalCenter: parent.horizontalCenter
        width: pessoa.lado
        height: width
        scale: toque.pressed ? 0.96 : (toque.containsMouse && !pessoa.escolhida ? 1.04 : 1)
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Sombra macia embaixo do círculo.
        Rectangle {
            id: base
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.16)
            visible: false
        }
        DropShadow {
            anchors.fill: base
            source: base
            radius: 18
            samples: 25
            verticalOffset: 3
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        // A letra, quando não há foto.
        Text {
            anchors.centerIn: parent
            visible: !pessoa.temFoto
            text: pessoa.inicial
            color: "white"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.round(pessoa.lado * 0.42)
            font.weight: Font.DemiBold
        }

        // A foto, recortada no círculo.
        Image {
            id: imagem
            anchors.fill: parent
            source: pessoa.foto
            sourceSize.width: Math.round(pessoa.lado * 2)
            sourceSize.height: Math.round(pessoa.lado * 2)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            visible: false
        }
        Rectangle {
            id: mascara
            anchors.fill: parent
            radius: width / 2
            visible: false
        }
        OpacityMask {
            anchors.fill: parent
            source: imagem
            maskSource: mascara
            visible: pessoa.temFoto
        }

        // A borda de vidro por cima.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, pessoa.lado * 0.022)
            border.color: Qt.rgba(1, 1, 1, pessoa.temFoto ? 0.35 : 0.28)
        }

        MouseArea {
            id: toque
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pessoa.escolhida ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: pessoa.clicada()
        }
    }

    Text {
        id: rotulo
        visible: pessoa.mostrarNome
        anchors.top: circulo.bottom
        anchors.topMargin: Math.round(pessoa.lado * 0.16)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, pessoa.lado * 3)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: pessoa.nome
        color: "white"
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(13, Math.round(pessoa.lado * 0.2))
        font.weight: Font.DemiBold
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.25)
    }
}
