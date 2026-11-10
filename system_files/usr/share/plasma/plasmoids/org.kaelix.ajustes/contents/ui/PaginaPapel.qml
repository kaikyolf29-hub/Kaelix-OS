// Papel de parede: o atual em destaque e os outros embaixo, como no Mac, mais
// a opção de usar uma foto sua.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: pagina

    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property string atual: ajustes.texto("papel")
    readonly property var escolhido: {
        for (var i = 0; i < ajustes.papeis.length; i++) {
            if (ajustes.papeis[i].pasta === atual) {
                return ajustes.papeis[i];
            }
        }
        return null;
    }

    function arquivo(caminho) {
        return caminho.length > 0 ? "file://" + caminho : "";
    }

    Component.onCompleted: ajustes.fazer("papeis")

    // O papel de parede de agora, grande.
    Grupo {
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            spacing: Kirigami.Units.gridUnit

            Kirigami.ShadowedImage {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                Layout.preferredHeight: Math.round(Layout.preferredWidth * 9 / 16)
                radius: Math.round(Kirigami.Units.gridUnit * 0.4)
                source: pagina.escolhido ? pagina.arquivo(pagina.escolhido.miniatura)
                      : (pagina.atual.length > 0 && pagina.atual.indexOf("/usr/share/wallpapers/") !== 0 ? pagina.arquivo(pagina.atual) : "")
                sourceSize.width: 400
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: pagina.escolhido ? pagina.escolhido.nome
                        : pagina.atual.length > 0 ? pagina.atual.substring(pagina.atual.lastIndexOf("/") + 1)
                        : ajustes.t("Papel de parede do Kaelix", "Kaelix wallpaper")
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.t("Em todas as telas. O do Kaelix muda sozinho com o tema claro e o escuro.",
                                    "On every screen. The Kaelix one follows the light and dark theme.")
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    opacity: 0.65
                }
                PlasmaComponents.Button {
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    text: ajustes.t("Usar uma foto minha…", "Use my own photo…")
                    onClicked: ajustes.fazer("papel escolher")
                }
            }
        }
    }

    Grupo {
        titulo: ajustes.t("Papéis de parede", "Wallpapers")

        Flow {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            spacing: Math.round(Kirigami.Units.gridUnit * 0.8)

            Repeater {
                model: ajustes.papeis
                Miniatura {
                    id: papel
                    required property var modelData
                    largura: Kirigami.Units.gridUnit * 7
                    nome: modelData.nome
                    escolhida: pagina.atual === modelData.pasta
                    onClicked: {
                        ajustes.definir("papel", modelData.pasta);
                        ajustes.fazer("papel " + ajustes.aspas(modelData.pasta));
                    }
                    Kirigami.ShadowedImage {
                        anchors.fill: parent
                        radius: Math.round(Kirigami.Units.gridUnit * 0.3)
                        source: pagina.arquivo(papel.modelData.miniatura)
                        sourceSize.width: 320
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            visible: ajustes.papeis.length === 0
            text: ajustes.t("Procurando os papéis de parede…", "Looking for wallpapers…")
            opacity: 0.6
        }
    }
}
