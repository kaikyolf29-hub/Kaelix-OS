// A página de um app, por cima da página de onde veio (como na Microsoft Store):
// a logo oficial, o nome, quem faz, o botão de obter, as fotos (clicar amplia),
// a descrição e as informações (versão, data, licença, tamanho, de onde vem).
// Esc ou "Voltar" fecham e a lista de baixo continua onde estava.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: detalhe

    readonly property string appId: janela.appAberto
    // Guarda o último, para o desenho não sumir enquanto a página fecha.
    property string mostrado: ""
    onAppIdChanged: {
        if (appId !== "") {
            mostrado = appId;
            rolagem.contentY = 0;
            descricaoAberta = false;
            confirmarRemocao = false;
        }
    }

    readonly property bool aberto: appId !== ""
    readonly property var resumo: {
        var _m = janela.mudancas;
        return janela.app(mostrado);
    }
    readonly property var info: {
        var _d = janela.detalhes;
        return janela.detalhes[mostrado] || null;
    }
    readonly property var dados: info || resumo
    readonly property var instalado: {
        var _m = janela.mudancas;
        return janela.instalados[mostrado] || null;
    }
    readonly property bool trabalhando: {
        var _m = janela.mudancas;
        return !!janela.tarefas[mostrado];
    }
    readonly property var fotos: info && info.fotos ? info.fotos : []
    readonly property int margem: Math.round(janela.gu * 1.6)
    property bool descricaoAberta: false
    property bool confirmarRemocao: false
    property int fotoAmpliada: -1

    function licenca(l) {
        if (!l)
            return "";
        if (/proprietary/i.test(l))
            return janela.t("Proprietária", "Proprietary");
        if (/(GPL|MIT|Apache|BSD|MPL|ISC|Zlib|Unlicense|CC0|EPL|Artistic)/i.test(l))
            return janela.t("Código aberto", "Open source") + " (" + l.replace(/LicenseRef-/g, "").split(" AND ")[0] + ")";
        return l.replace(/LicenseRef-/g, "");
    }
    function dataLegivel(segundos) {
        if (!segundos)
            return "";
        return new Date(segundos * 1000).toLocaleDateString(janela.local, janela.pt ? "d 'de' MMMM 'de' yyyy" : "MMMM d, yyyy");
    }
    function origem(remoto) {
        if (!remoto)
            return "";
        if (remoto === "flathub")
            return "Flathub";
        if (remoto.indexOf("matsu") === 0)
            return janela.t("Loja do Matsu", "Matsu Store");
        return remoto;
    }

    visible: opacity > 0
    opacity: aberto ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }
    focus: aberto
    Keys.onEscapePressed: {
        if (detalhe.fotoAmpliada >= 0)
            detalhe.fotoAmpliada = -1;
        else
            janela.appAberto = "";
    }
    onAbertoChanged: if (aberto) forceActiveFocus()

    // Segura os cliques e a rodinha (para não mexer na lista de baixo).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (evento) => evento.accepted = true
    }

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: conteudo.implicitHeight + detalhe.margem
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: conteudo
            x: detalhe.margem
            width: rolagem.width - 2 * detalhe.margem
            spacing: Math.round(janela.gu * 1.2)

            Botao {
                Layout.topMargin: Math.round(janela.gu * 0.9)
                Layout.leftMargin: -Math.round(janela.gu * 0.4)
                texto: janela.t("Voltar", "Back")
                icone: "matsu-voltar-symbolic"
                onClicado: janela.appAberto = ""
            }

            // ----- logo, nome, quem faz e o botão -----
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 1.2)

                IconeApp {
                    Layout.preferredWidth: Math.round(janela.gu * 6)
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignTop
                    fonte: detalhe.dados ? detalhe.dados.icone : ""
                    appId: detalhe.mostrado
                    sombra: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.25)

                    Texto {
                        Layout.fillWidth: true
                        text: detalhe.dados ? detalhe.dados.nome : janela.nomeDe(detalhe.mostrado)
                        font.pixelSize: Math.round(janela.gu * 1.65)
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        spacing: 4
                        visible: detalhe.dados !== null && !!detalhe.dados.dev
                        Texto {
                            text: detalhe.dados && detalhe.dados.dev ? detalhe.dados.dev : ""
                            opacity: 0.72
                        }
                        Kirigami.Icon {
                            visible: detalhe.dados !== null && detalhe.dados.verificado
                            implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.9)
                            implicitHeight: implicitWidth
                            source: "matsu-verificado-symbolic"
                            isMask: true
                            color: janela.corSelo
                        }
                        Texto {
                            visible: detalhe.dados !== null && detalhe.dados.verificado
                            text: janela.t("verificado", "verified")
                            color: janela.corSelo
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: detalhe.dados ? detalhe.dados.resumo : ""
                        wrapMode: Text.WordWrap
                        opacity: 0.8
                    }

                    // Etiquetas: categoria e se já vem no Matsu.
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.2)
                        spacing: Math.round(janela.gu * 0.35)
                        Repeater {
                            model: {
                                var l = [];
                                if (detalhe.dados && detalhe.dados.categoria)
                                    l.push(janela.nomeCategoria(detalhe.dados.categoria));
                                if (janela.estado(detalhe.mostrado) === "sistema")
                                    l.push(janela.t("Já vem no Matsu", "Comes with Matsu"));
                                if (detalhe.instalado)
                                    l.push(janela.t("Instalado", "Installed"));
                                return l;
                            }
                            Rectangle {
                                required property string modelData
                                height: Math.round(janela.gu * 1.4)
                                width: etiqueta.implicitWidth + Math.round(janela.gu * 1.0)
                                radius: height / 2
                                color: janela.tinta(janela.escuro ? 0.08 : 0.06)
                                Texto {
                                    id: etiqueta
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.85
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.topMargin: Math.round(janela.gu * 0.5)
                        spacing: Math.round(janela.gu * 0.5)
                        BotaoObter {
                            appId: detalhe.mostrado
                            grande: true
                        }
                        // Tirar o app: pede para confirmar uma vez.
                        Botao {
                            visible: detalhe.instalado !== null && !detalhe.trabalhando
                            texto: detalhe.confirmarRemocao ? janela.t("Confirmar: remover", "Confirm: remove") : janela.t("Remover", "Remove")
                            icone: "matsu-lixeira-symbolic"
                            onClicado: {
                                if (detalhe.confirmarRemocao) {
                                    detalhe.confirmarRemocao = false;
                                    janela.remover(detalhe.mostrado);
                                } else {
                                    detalhe.confirmarRemocao = true;
                                    voltaConfirmacao.restart();
                                }
                            }
                            Timer {
                                id: voltaConfirmacao
                                interval: 4000
                                onTriggered: detalhe.confirmarRemocao = false
                            }
                        }
                    }
                    Texto {
                        visible: {
                            var _a = janela.avisos;
                            return !!janela.avisos[detalhe.mostrado] && !detalhe.trabalhando;
                        }
                        Layout.fillWidth: true
                        text: janela.avisos[detalhe.mostrado] || ""
                        color: janela.escuro ? "#f5b26b" : "#b8621b"
                        wrapMode: Text.WordWrap
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // ----- fotos -----
            ListView {
                id: listaFotos
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.max(janela.gu * 11, Math.min(janela.gu * 17, conteudo.width * 0.3)))
                visible: detalhe.info === null || detalhe.fotos.length > 0
                orientation: ListView.Horizontal
                spacing: Math.round(janela.gu * 0.8)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: detalhe.info === null ? 3 : detalhe.fotos
                QQC2.ScrollBar.horizontal: BarraRolagem {
                    policy: listaFotos.contentWidth > listaFotos.width ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
                }

                delegate: Item {
                    id: foto
                    required property var modelData
                    required property int index
                    readonly property bool carregando: detalhe.info === null
                    height: listaFotos.height - Math.round(janela.gu * 1.0)
                    width: Math.round(height * 16 / 10)

                    Esqueleto {
                        anchors.fill: parent
                        raio: Math.round(janela.gu * 0.6)
                        visible: foto.carregando || imagem.status !== Image.Ready
                    }
                    ImagemRedonda {
                        id: imagem
                        anchors.fill: parent
                        raio: Math.round(janela.gu * 0.6)
                        source: foto.carregando ? "" : foto.modelData.url
                        fillMode: Image.PreserveAspectCrop
                        sombra: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !foto.carregando
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detalhe.fotoAmpliada = foto.index
                    }
                }
            }

            // ----- sobre -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.4)
                visible: detalhe.info !== null && detalhe.info.descricao !== ""
                Titulo {
                    Layout.fillWidth: true
                    texto: janela.t("Sobre o app", "About this app")
                }
                Texto {
                    id: descricao
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(janela.gu * 46)
                    text: detalhe.info ? detalhe.info.descricao : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    maximumLineCount: detalhe.descricaoAberta ? 1000 : 7
                    elide: Text.ElideRight
                    opacity: 0.88
                }
                Botao {
                    visible: descricao.truncated || detalhe.descricaoAberta
                    Layout.leftMargin: -Math.round(janela.gu * 0.4)
                    texto: detalhe.descricaoAberta ? janela.t("Mostrar menos", "Show less") : janela.t("Ler mais", "Read more")
                    onClicado: detalhe.descricaoAberta = !detalhe.descricaoAberta
                }
            }

            // ----- informações -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.5)
                visible: detalhe.dados !== null
                Titulo {
                    Layout.fillWidth: true
                    texto: janela.t("Informações", "Information")
                }
                Cartao {
                    Layout.fillWidth: true
                    implicitHeight: grade.implicitHeight + Math.round(janela.gu * 1.6)
                    GridLayout {
                        id: grade
                        anchors.fill: parent
                        anchors.margins: Math.round(janela.gu * 0.8)
                        columns: Math.max(1, Math.min(3, Math.floor(width / (janela.gu * 13))))
                        rowSpacing: Math.round(janela.gu * 0.8)
                        columnSpacing: Math.round(janela.gu * 1.2)
                        Repeater {
                            model: {
                                var d = detalhe.info || {};
                                var inst = detalhe.instalado || {};
                                var l = [
                                    [janela.t("Versão", "Version"), inst.versao || d.versao || ""],
                                    [janela.t("Atualizado em", "Updated on"), detalhe.dataLegivel(d.data)],
                                    [janela.t("Feito por", "Made by"), detalhe.dados ? detalhe.dados.dev || "" : ""],
                                    [janela.t("Licença", "License"), detalhe.licenca(d.licenca)],
                                    [janela.t("Tamanho", "Size"), inst.tamanho || ""],
                                    [janela.t("Vem de", "Comes from"), detalhe.origem(inst.remoto || (detalhe.dados ? detalhe.dados.remoto : ""))]
                                ];
                                return l.filter(function (x) { return x[1] !== ""; });
                            }
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 1
                                Texto {
                                    text: parent.modelData[0]
                                    opacity: 0.6
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: parent.modelData[1]
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: -Math.round(janela.gu * 0.4)
                    spacing: Math.round(janela.gu * 0.3)
                    Repeater {
                        model: {
                            var d = detalhe.info || {};
                            var l = [];
                            if (d.site)
                                l.push({ texto: janela.t("Site do app", "App website"), url: d.site, icone: "matsu-link-symbolic" });
                            if (d.ajuda)
                                l.push({ texto: janela.t("Ajuda", "Help"), url: d.ajuda, icone: "matsu-info-symbolic" });
                            if (d.doacao)
                                l.push({ texto: janela.t("Apoiar quem faz", "Support the developers"), url: d.doacao, icone: "matsu-coracao-symbolic" });
                            return l;
                        }
                        Botao {
                            required property var modelData
                            texto: modelData.texto
                            icone: modelData.icone
                            dica: modelData.url
                            onClicado: Qt.openUrlExternally(modelData.url)
                        }
                    }
                }
            }

            // Não achou o app no catálogo (endereço antigo ou repositório tirado).
            Cartao {
                Layout.fillWidth: true
                visible: detalhe.resumo === null && detalhe.info === null && janela.lido
                implicitHeight: semApp.implicitHeight + Math.round(janela.gu * 1.6)
                Texto {
                    id: semApp
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.8)
                    wrapMode: Text.WordWrap
                    text: janela.t("Este app não está no catálogo agora. Pode ter saído do repositório ou ainda estar chegando.",
                                   "This app isn't in the catalog right now. It may have left the repository or still be on its way.")
                }
            }
        }
    }

    // ----- foto ampliada -----
    Rectangle {
        id: ampliada
        anchors.fill: parent
        z: 10
        color: Qt.rgba(0, 0, 0, 0.82)
        radius: janela.raio
        opacity: detalhe.fotoAmpliada >= 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: detalhe.fotoAmpliada = -1
            onWheel: (evento) => evento.accepted = true
        }
        ImagemRedonda {
            id: grande
            anchors.fill: parent
            anchors.margins: Math.round(janela.gu * 3)
            anchors.bottomMargin: Math.round(janela.gu * (legenda.text !== "" ? 4.5 : 3))
            raio: Math.round(janela.gu * 0.6)
            fillMode: Image.PreserveAspectFit
            source: detalhe.fotoAmpliada >= 0 && detalhe.fotoAmpliada < detalhe.fotos.length ? detalhe.fotos[detalhe.fotoAmpliada].url : ""
        }
        Texto {
            id: legenda
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(janela.gu * 1.4)
            width: parent.width - janela.gu * 6
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: "#ffffff"
            text: detalhe.fotoAmpliada >= 0 && detalhe.fotoAmpliada < detalhe.fotos.length ? detalhe.fotos[detalhe.fotoAmpliada].legenda || "" : ""
        }
        Repeater {
            model: [-1, 1]
            MouseArea {
                required property int modelData
                visible: detalhe.fotos.length > 1
                width: Math.round(janela.gu * 2.4)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? Math.round(janela.gu * 0.5) : parent.width - width - Math.round(janela.gu * 0.5)
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData < 0 ? janela.t("Foto anterior", "Previous photo") : janela.t("Próxima foto", "Next photo")
                onClicked: {
                    var n = detalhe.fotos.length;
                    detalhe.fotoAmpliada = (detalhe.fotoAmpliada + modelData + n) % n;
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, parent.containsMouse ? 0.24 : 0.14)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-seta-symbolic"
                    isMask: true
                    color: "#ffffff"
                    rotation: parent.modelData < 0 ? 180 : 0
                }
            }
        }
    }
}
