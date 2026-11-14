// A janela de resgatar o código de um app pago (comprado fora da Loja: no site de
// quem fez, Hotmart, Pix...). A pessoa digita ou cola o código MATSU-XXXX-XXXX-XXXX
// (o traço e as maiúsculas entram sozinhos), a Loja manda ao servidor e guarda a
// licença deste computador. Deu certo: o visto verde, para quanto tempo vale e os
// apps liberados já começam a instalar. Um código pode liberar vários apps (combo).
//   resgate.abrirPara("com.exemplo.App")   // ou abrirPara("") sem app
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: caixa

    property string appId: ""
    property string fase: "codigo"    // "codigo", "enviando" ou "pronto"
    property string erro: ""
    property var resultado: ({})
    readonly property var app: {
        var _m = janela.mudancas;
        return appId !== "" ? janela.app(appId) : null;
    }
    readonly property string ondeComprar: {
        var _d = janela.detalhes;
        var d = janela.detalhes[appId];
        return d && d.comprar ? d.comprar : "";
    }
    readonly property bool completo: limpo(campo.texto).length === 12
    readonly property var liberados: resultado && resultado.apps ? resultado.apps : []
    readonly property bool instalando: {
        var _m = janela.mudancas;
        for (var i = 0; i < liberados.length; i++)
            if (janela.tarefas[liberados[i]])
                return true;
        return false;
    }

    function abrirPara(id) {
        appId = id || "";
        fase = "codigo";
        erro = "";
        resultado = ({});
        campo.texto = "";
        if (appId !== "")
            janela.carregarDetalhes(appId);
        open();
    }
    // Só as letras e números do código, sem o MATSU da frente.
    function limpo(texto) {
        var s = (texto || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
        if (s.indexOf("MATSU") === 0)
            s = s.substring(5);
        return s.substring(0, 12);
    }
    function formatar(texto) {
        var bruto = (texto || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
        // Começando a digitar o "MATSU" da frente: deixa como está.
        if (bruto.length > 0 && bruto.length < 5 && "MATSU".indexOf(bruto) === 0)
            return bruto;
        var s = limpo(texto);
        if (s.length === 0)
            return bruto === "MATSU" ? "MATSU-" : "";
        var grupos = [];
        for (var i = 0; i < s.length; i += 4)
            grupos.push(s.substring(i, i + 4));
        return "MATSU-" + grupos.join("-");
    }
    function enviar() {
        if (fase === "enviando")
            return;
        if (!completo) {
            erro = janela.t("O código tem 12 letras e números depois do MATSU.", "The code has 12 letters and numbers after MATSU.");
            campo.focar();
            return;
        }
        erro = "";
        fase = "enviando";
        janela.resgatar(formatar(campo.texto));
    }
    // A resposta do ajudante (Main.qml chama).
    function resposta(d) {
        if (d && d.ok) {
            resultado = d;
            fase = "pronto";
            visto.desenhar();
        } else {
            fase = "codigo";
            erro = d && d.mensagem ? d.mensagem : janela.t("Não deu certo agora. Tente de novo daqui a pouco.", "It did not work right now. Try again in a moment.");
            campo.focar();
        }
    }
    function nomes(ids) {
        var l = ids.map(function (i) { return janela.nomeDe(i); });
        if (l.length <= 1)
            return l.join("");
        return l.slice(0, -1).join(", ") + janela.t(" e ", " and ") + l[l.length - 1];
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.3)
    width: Math.min(Math.round(janela.gu * 25), parent ? parent.width - janela.gu * 4 : janela.gu * 25)
    closePolicy: fase === "enviando" ? QQC2.Popup.NoAutoClose : (QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside)
    onOpened: if (fase === "codigo") campo.focar()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { property: "scale"; to: 0.96; duration: 120 }
        }
    }
    background: FundoBalao {
        radius: Math.round(janela.gu * 0.9)
    }

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.7)

        // ----- digitar o código -----
        ColumnLayout {
            Layout.fillWidth: true
            visible: caixa.fase !== "pronto"
            spacing: Math.round(janela.gu * 0.7)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.8)
                IconeApp {
                    visible: caixa.app !== null
                    Layout.preferredWidth: Math.round(janela.gu * 3.2)
                    Layout.preferredHeight: Layout.preferredWidth
                    fonte: caixa.app ? caixa.app.icone : ""
                    appId: caixa.appId
                    sombra: true
                }
                Rectangle {
                    visible: caixa.app === null
                    Layout.preferredWidth: Math.round(janela.gu * 3.2)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: janela.tinta(janela.escuro ? 0.1 : 0.07)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        implicitWidth: Math.round(parent.width * 0.5)
                        implicitHeight: implicitWidth
                        source: "matsu-etiqueta-symbolic"
                        isMask: true
                        color: janela.frente
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Resgatar código", "Redeem code")
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: caixa.app ? caixa.app.nome + (caixa.app.preco ? "  ·  " + caixa.app.preco : "") : ""
                        opacity: 0.68
                        elide: Text.ElideRight
                    }
                }
            }

            Texto {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.78
                text: janela.t("Digite ou cole o código que você recebeu na compra. O app fica liberado neste computador.",
                               "Type or paste the code you got with your purchase. The app gets unlocked on this computer.")
            }

            Campo {
                id: campo
                Layout.fillWidth: true
                implicitHeight: Math.round(janela.gu * 2.5)
                dica: "MATSU-XXXX-XXXX-XXXX"
                icone: "matsu-etiqueta-symbolic"
                maximo: 64
                enabled: caixa.fase === "codigo"
                onEditado: (texto) => {
                    var f = caixa.formatar(texto);
                    if (f !== texto)
                        campo.texto = f;
                    caixa.erro = "";
                }
                onConfirmado: caixa.enviar()
                Component.onCompleted: {
                    campo.entrada.font.letterSpacing = 1.2;
                    campo.entrada.font.weight = Font.DemiBold;
                }
            }

            Texto {
                Layout.fillWidth: true
                visible: caixa.erro !== ""
                text: caixa.erro
                wrapMode: Text.WordWrap
                color: janela.escuro ? "#f5b26b" : "#b8621b"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.3)
                spacing: Math.round(janela.gu * 0.5)
                Botao {
                    visible: caixa.ondeComprar !== ""
                    Layout.leftMargin: -Math.round(janela.gu * 0.4)
                    texto: janela.t("Onde comprar", "Where to buy")
                    icone: "matsu-link-symbolic"
                    dica: caixa.ondeComprar
                    onClicado: Qt.openUrlExternally(caixa.ondeComprar)
                }
                Item {
                    Layout.fillWidth: true
                }
                Botao {
                    texto: janela.t("Cancelar", "Cancel")
                    ativo: caixa.fase !== "enviando"
                    onClicado: caixa.close()
                }
                BotaoDestaque {
                    texto: janela.t("Resgatar", "Redeem")
                    ativo: caixa.completo
                    estado: caixa.fase === "enviando" ? "carregando" : ""
                    onClicado: caixa.enviar()
                }
            }
        }

        // ----- pronto -----
        ColumnLayout {
            Layout.fillWidth: true
            visible: caixa.fase === "pronto"
            spacing: Math.round(janela.gu * 0.5)

            // O visto verde, desenhando.
            Item {
                id: visto
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(janela.gu * 0.4)
                Layout.preferredWidth: Math.round(janela.gu * 3.6)
                Layout.preferredHeight: Layout.preferredWidth
                property real traco: 0
                function desenhar() {
                    animacaoVisto.restart();
                }
                Rectangle {
                    id: bola
                    anchors.fill: parent
                    radius: width / 2
                    color: janela.escuro ? "#2fa66a" : "#23915a"
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#ffffff"
                        strokeWidth: Math.max(2, visto.width / 14)
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: visto.width * 0.29
                        startY: visto.height * 0.52
                        PathLine {
                            x: visto.width * (0.29 + 0.14 * Math.min(1, visto.traco * 2))
                            y: visto.height * (0.52 + 0.15 * Math.min(1, visto.traco * 2))
                        }
                        PathLine {
                            x: visto.width * (0.43 + 0.30 * Math.max(0, visto.traco * 2 - 1))
                            y: visto.height * (0.67 - 0.32 * Math.max(0, visto.traco * 2 - 1))
                        }
                    }
                }
                SequentialAnimation {
                    id: animacaoVisto
                    PropertyAction { target: visto; property: "traco"; value: 0 }
                    NumberAnimation { target: bola; property: "scale"; from: 0.4; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    NumberAnimation { target: visto; property: "traco"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                }
            }

            Texto {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                font.weight: Font.DemiBold
                text: caixa.liberados.length > 1 ? janela.t("Apps liberados", "Apps unlocked")
                                                 : janela.t("Pronto, app liberado", "Done, app unlocked")
            }
            Texto {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.8
                text: {
                    var _m = janela.mudancas;
                    var r = caixa.resultado || {};
                    var varios = caixa.liberados.length > 1;
                    return caixa.nomes(caixa.liberados)
                           + (varios ? janela.t(" ficam liberados ", " are unlocked ") : janela.t(" fica liberado ", " is unlocked "))
                           + janela.prazoTexto(r.plano, r.expira) + janela.t(" neste computador.", " on this computer.");
                }
            }
            Texto {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: (caixa.resultado.computadores || 0) > 1
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: janela.t("O código vale em " + caixa.resultado.computadores + " computadores (já está em " + caixa.resultado.usados + ").",
                               "The code works on " + caixa.resultado.computadores + " computers (used on " + caixa.resultado.usados + " so far).")
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: caixa.instalando
                spacing: Math.round(janela.gu * 0.4)
                Girando {
                    Layout.preferredWidth: Math.round(janela.gu * 0.9)
                    Layout.preferredHeight: Layout.preferredWidth
                }
                Texto {
                    text: janela.t("Instalando agora", "Installing now")
                    opacity: 0.8
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.5)
                spacing: Math.round(janela.gu * 0.5)
                Item {
                    Layout.fillWidth: true
                }
                Botao {
                    texto: janela.t("Ver na Biblioteca", "See in Library")
                    onClicado: {
                        caixa.close();
                        janela.irPara("biblioteca");
                    }
                }
                BotaoDestaque {
                    texto: janela.t("Pronto", "Done")
                    onClicado: caixa.close()
                }
            }
        }
    }
}
