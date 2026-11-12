// Vídeos: os da pasta Vídeos, em cartões com a capa (uma foto do começo, feita
// com o ffmpeg quando ele existe), o nome, a data e o tamanho. Abre no visualizador.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.4)
    readonly property var lista: janela.busca2(janela.videos)

    GridView {
        id: grade
        anchors.fill: parent
        anchors.leftMargin: pagina.margem - Math.round(vao / 2)
        anchors.rightMargin: pagina.margem - Math.round(vao / 2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property int vao: Math.round(janela.gu * 1.0)
        readonly property int colunas: Math.max(1, Math.floor(width / (janela.gu * 14)))
        cellWidth: Math.floor(width / colunas)
        cellHeight: Math.round((cellWidth - vao) * 9 / 16) + Math.round(janela.gu * 3.7)
        model: pagina.lista
        cacheBuffer: Math.round(janela.gu * 20)
        QQC2.ScrollBar.vertical: BarraRolagem {
            parent: pagina
            x: pagina.width - width
            y: grade.y
            height: grade.height
        }
        Component.onCompleted: entrada.restart()
        transform: Translate {
            id: deslocamento
        }
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: grade; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: deslocamento; property: "y"; from: Math.round(janela.gu * 0.8); to: 0; duration: 340; easing.type: Easing.OutCubic }
        }

        header: Item {
            width: grade.width
            height: Math.round(janela.gu * 4.6)
            ColumnLayout {
                x: Math.round(grade.vao / 2)
                y: Math.round(janela.gu * 1.0)
                width: parent.width - grade.vao
                spacing: 1
                Texto {
                    Layout.fillWidth: true
                    text: janela.busca.trim().length > 0 ? janela.t("Vídeos com “" + janela.busca.trim() + "”", "Videos matching “" + janela.busca.trim() + "”") : janela.t("Vídeos", "Videos")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Texto {
                    Layout.fillWidth: true
                    visible: pagina.lista.length > 0
                    text: janela.quantosVideos(pagina.lista.length) + janela.t(" na pasta Vídeos", " in the Videos folder")
                    opacity: 0.62
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
        }

        delegate: Item {
            id: celula
            required property var modelData
            required property int index
            width: grade.cellWidth
            height: grade.cellHeight

            MouseArea {
                id: cartao
                anchors.fill: parent
                anchors.leftMargin: Math.round(grade.vao / 2)
                anchors.rightMargin: Math.round(grade.vao / 2)
                anchors.topMargin: Math.round(janela.gu * 0.3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                Accessible.role: Accessible.Button
                Accessible.name: celula.modelData.nome
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        menuVideo.video = celula.modelData;
                        menuVideo.abrirEm(cartao, m.x, m.y);
                    } else {
                        janela.abrirVisor(pagina.lista, celula.index, null);
                    }
                }

                Rectangle {
                    id: fundoCapa
                    width: parent.width
                    height: Math.round(width * 9 / 16)
                    radius: Math.round(janela.gu * 0.55)
                    scale: cartao.pressed ? 0.98 : 1
                    // Sem capa: um degradê escuro com o desenho do vídeo.
                    gradient: Gradient {
                        GradientStop { position: 0; color: janela.escuro ? "#2a2a30" : "#d9d9e0" }
                        GradientStop { position: 1; color: janela.escuro ? "#17171b" : "#c4c4cd" }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.large
                        height: width
                        visible: capaVideo.vazia
                        source: String(Qt.resolvedUrl("icones/video.svg"))
                        isMask: true
                        color: janela.frente
                        opacity: 0.35
                    }
                    CapaRedonda {
                        id: capaVideo
                        anchors.fill: parent
                        arquivo: celula.modelData.capa || ""
                        aproximar: cartao.containsMouse ? 1.04 : 1
                    }
                    // O "play" no meio, que cresce com o mouse em cima.
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(janela.gu * (cartao.containsMouse ? 3.2 : 2.7))
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, cartao.containsMouse ? 0.55 : 0.4)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1
                            width: Math.round(parent.width * 0.42)
                            height: width
                            source: String(Qt.resolvedUrl("icones/tocar.svg"))
                            isMask: true
                            color: "#ffffff"
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: janela.tinta(cartao.containsMouse ? 0.22 : 0.08)
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: fundoCapa.bottom
                    anchors.topMargin: Math.round(janela.gu * 0.5)
                    spacing: 0
                    Texto {
                        Layout.fillWidth: true
                        text: celula.modelData.nome
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.dataLonga(celula.modelData.data).split(",")[0] + " · " + janela.bytes(celula.modelData.tamanho)
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Vazio {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(janela.gu * 1.5)
        visible: janela.lido && pagina.lista.length === 0
        icone: janela.busca.trim().length > 0 ? "matsu-busca-symbolic" : String(Qt.resolvedUrl("icones/video.svg"))
        titulo: janela.busca.trim().length > 0 ? janela.t("Nada encontrado", "Nothing found") : janela.t("Nenhum vídeo", "No videos")
        texto: janela.busca.trim().length > 0 ? janela.t("Nenhum vídeo com “" + janela.busca.trim() + "” no nome.", "No video with “" + janela.busca.trim() + "” in its name.")
                                             : janela.t("Os vídeos da pasta Vídeos aparecem aqui.", "Videos in your Videos folder show up here.")
    }

    MenuMatsu {
        id: menuVideo
        property var video: ({})
        itens: [
            { id: "pasta", nome: janela.t("Mostrar na pasta", "Show in folder"), icone: "matsu-pasta-symbolic" },
            { id: "copiar", nome: janela.t("Copiar", "Copy"), icone: String(Qt.resolvedUrl("icones/copiar.svg")) },
            { id: "apagar", nome: janela.t("Mover para a Lixeira", "Move to Trash"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "pasta")
                janela.mostrarNaPasta(menuVideo.video.caminho);
            else if (id === "copiar")
                janela.copiar(menuVideo.video.caminho);
            else if (id === "apagar")
                janela.apagar(menuVideo.video);
        }
    }
}
