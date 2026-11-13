// Sua conta: a foto e o nome da pessoa, como no topo dos Ajustes do Mac. A foto
// aparece na tela de login, na tela de bloqueio e no menu. Dá para escolher uma
// das fotos do Matsu (pixel art, no clima do papel de parede) ou uma foto sua,
// que sai quadrada e com 512 px (o recorte é feito aqui, sem programa de fora).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: pagina
    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property var fotosDoMatsu: [
        { arquivo: "lago", nome: ajustes.t("Lago", "Lake") },
        { arquivo: "pinheiro", nome: ajustes.t("Pinheiro", "Pine") },
        { arquivo: "lua", nome: ajustes.t("Lua", "Moon") },
        { arquivo: "gato", nome: ajustes.t("Gato", "Cat") },
        { arquivo: "sakura", nome: "Sakura" },
        { arquivo: "controle", nome: ajustes.t("Controle", "Controller") }
    ]

    Component.onCompleted: ajustes.lerConta()

    // A foto escolhida pela pessoa: recortada no quadrado, gravada em 512 px e
    // entregue ao ajudante (que guarda para o login e o bloqueio).
    Item {
        // Fora do layout: a imagem só serve para recortar.
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        Layout.topMargin: -pagina.spacing
    Image {
        id: recorte
        x: -100000
        width: 512
        height: 512
        sourceSize.width: 1024
        sourceSize.height: 1024
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        source: ajustes.fotoEscolhida ? "file://" + ajustes.fotoEscolhida : ""
        onStatusChanged: {
            if (status === Image.Ready && ajustes.fotoEscolhida) {
                const destino = "/tmp/matsu-foto-" + Date.now() + ".png";
                recorte.grabToImage(function (r) {
                    if (r.saveToFile(destino)) {
                        ajustes.fazer("foto " + ajustes.aspas(destino));
                    }
                    ajustes.fotoEscolhida = "";
                }, Qt.size(512, 512));
            } else if (status === Image.Error) {
                ajustes.fotoEscolhida = "";
            }
        }
    }
    }

    // A pessoa, grande, no meio.
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Avatar {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.gridUnit * 5
            implicitHeight: implicitWidth
            name: ajustes.conta.nome || ""
            source: ajustes.conta.foto ? "file://" + ajustes.conta.foto + "?v=" + ajustes.contaVersao : ""
            color: "#6e6e76"
            initialsColor: "#ffffff"
        }
        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 2
            text: ajustes.conta.nome || ""
            font.weight: Font.Bold
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: ajustes.conta.usuario || ""
            opacity: 0.6
        }
    }

    Grupo {
        titulo: ajustes.t("Foto", "Picture")
        nota: ajustes.t("Aparece na tela de login, na tela de bloqueio e no menu.",
                        "Shows on the login screen, the lock screen and the menu.")

        Flow {
            Layout.fillWidth: true
            Layout.margins: Math.round(Kirigami.Units.gridUnit * 0.8)
            spacing: Math.round(Kirigami.Units.gridUnit * 0.7)

            Repeater {
                model: pagina.fotosDoMatsu
                delegate: MouseArea {
                    id: foto
                    required property var modelData
                    readonly property string caminho: "/usr/share/matsu/avatares/" + modelData.arquivo + ".png"
                    width: Math.round(Kirigami.Units.gridUnit * 3.2)
                    height: width
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.nome
                    onClicked: ajustes.fazer("foto " + ajustes.aspas(caminho))
                    Keys.onReturnPressed: clicked(null)
                    scale: pressed ? 0.94 : (containsMouse ? 1.06 : 1)
                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                    Avatar {
                        anchors.fill: parent
                        source: "file://" + foto.caminho
                        name: foto.modelData.nome
                        borda: foto.activeFocus ? 2 : 0
                    }
                    PlasmaComponents.ToolTip {
                        text: foto.modelData.nome
                    }
                }
            }
        }
        Linha {
            primeira: false
            nome: ajustes.t("Usar uma foto minha", "Use my own picture")
            detalhe: ajustes.t("Ela fica quadrada, cortada pelo meio.", "It's cropped to a square from the center.")
            PlasmaComponents.Button {
                text: ajustes.t("Escolher…", "Choose…")
                onClicked: ajustes.fazer("foto-escolher")
            }
        }
        Linha {
            visible: !!ajustes.conta.foto
            nome: ajustes.t("Tirar a foto", "Remove picture")
            detalhe: ajustes.t("No lugar dela aparece a primeira letra do seu nome.", "Your initial shows instead.")
            PlasmaComponents.Button {
                text: ajustes.t("Tirar", "Remove")
                onClicked: ajustes.fazer("foto tirar")
            }
        }
    }

    Grupo {
        Linha {
            primeira: true
            abre: true
            nome: ajustes.t("Senha e nome", "Password and name")
            detalhe: ajustes.t("Trocar a senha, o nome e as outras pessoas do computador.",
                               "Change your password, name and the other people on this computer.")
            onAberto: ajustes.abrir("kcm kcm_users")
        }
    }
}
