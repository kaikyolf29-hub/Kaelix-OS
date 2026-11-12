// Padrão e Científica (a mesma página: a grade troca com animação). Em cima o
// título e o botão do histórico, o visor (a conta pequena e o resultado grande,
// que encolhe quando o número é comprido), a linha da memória e a grade de teclas.
// Numa janela larga o histórico fica fixo à direita; numa estreita ele desliza
// por cima, vindo da direita.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

FocusScope {
    id: pagina

    readonly property bool cientifica: janela.pagina === "cientifica"
    readonly property bool largo: width >= janela.gu * 36
    readonly property int larguraPainel: Math.round(Math.min(janela.gu * 18, width * 0.4))
    readonly property int margem: Math.round(janela.gu * 0.5)

    focus: true
    Keys.onPressed: (e) => {
        if (janela.teclaFisica(e))
            e.accepted = true;
    }
    // Depois de uma lista ou menu, o teclado volta para a calculadora.
    Connections {
        target: janela
        function onActiveFocusItemChanged() {
            if (!janela.activeFocusItem || janela.activeFocusItem === janela.contentItem)
                pagina.forceActiveFocus();
        }
        function onTelaChanged() {
            numero.mostrar(janela.tela.erro ? "" : janela.tela.resultado, !janela.tela.digitando);
        }
        function onCopiado() {
            brilho.restart();
        }
    }

    // Entra subindo de leve.
    opacity: 0
    Component.onCompleted: {
        forceActiveFocus();
        numero.mostrar(janela.tela.erro ? "" : janela.tela.resultado, false);
        entrada.start();
    }
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: pagina; property: "opacity"; from: 0; to: 1; duration: 260 }
        NumberAnimation { target: deslocaPagina; property: "y"; from: janela.gu * 0.6; to: 0; duration: 360; easing.type: Easing.OutCubic }
    }
    transform: Translate {
        id: deslocaPagina
    }

    // ----- as teclas -----
    function n(c) {
        return { c: c, r: c, t: "numero" };
    }
    readonly property string sepDecimal: janela.t(",", ".")
    readonly property var gradePadrao: [
        [{ c: "%", r: "%", d: janela.t("Porcentagem", "Percent") + " (%)" },
         { c: "CE", r: "CE", d: janela.t("Limpar o número (Delete)", "Clear entry (Delete)") },
         { c: "C", r: "C", d: janela.t("Limpar tudo (Esc)", "Clear (Esc)") },
         { c: "apagar", i: Qt.resolvedUrl("icones/apagar.svg"), d: janela.t("Apagar (Backspace)", "Backspace"), rep: true }],
        [{ c: "inverso", r: "1/x", d: janela.t("Inverso (R)", "Reciprocal (R)") },
         { c: "quadrado", r: "x²", d: janela.t("Ao quadrado (Q)", "Square (Q)") },
         { c: "raiz", r: "√x", d: janela.t("Raiz quadrada (@)", "Square root (@)") },
         { c: "/", r: "÷", t: "operador", d: janela.t("Dividir (/)", "Divide (/)") }],
        [n("7"), n("8"), n("9"), { c: "*", r: "×", t: "operador", d: janela.t("Multiplicar (*)", "Multiply (*)") }],
        [n("4"), n("5"), n("6"), { c: "-", r: "−", t: "operador", d: janela.t("Subtrair (−)", "Subtract (−)") }],
        [n("1"), n("2"), n("3"), { c: "+", r: "+", t: "operador", d: janela.t("Somar (+)", "Add (+)") }],
        [{ c: "neg", r: "+/−", t: "numero", d: janela.t("Trocar o sinal (F9)", "Negate (F9)") }, n("0"),
         { c: "virgula", r: sepDecimal, t: "numero", d: janela.t("Vírgula (, ou .)", "Decimal point") },
         { c: "=", r: "=", t: "igual", d: janela.t("Igual (Enter)", "Equals (Enter)") }]
    ]
    readonly property var gradeCientifica: [
        [{ c: "segunda", r: janela.t("2ª", "2ⁿᵈ"), d: janela.t("Outras funções", "More functions") },
         { c: "pi", r: "π", d: "π (P)" }, { c: "e", r: "e", d: janela.t("Número de Euler", "Euler's number") },
         { c: "C", r: "C", d: janela.t("Limpar (Esc)", "Clear (Esc)") },
         { c: "apagar", i: Qt.resolvedUrl("icones/apagar.svg"), d: janela.t("Apagar (Backspace)", "Backspace"), rep: true }],
        [{ c: "sen", r: janela.t("sen", "sin"), c2: "asen", r2: janela.t("sen⁻¹", "sin⁻¹"), d: janela.t("Seno (S)", "Sine (S)") },
         { c: "cos", r: "cos", c2: "acos", r2: "cos⁻¹", d: janela.t("Cosseno (O)", "Cosine (O)") },
         { c: "tan", r: "tan", c2: "atan", r2: "tan⁻¹", d: janela.t("Tangente (T)", "Tangent (T)") },
         { c: "log", r: "log", d: janela.t("Logaritmo na base 10 (L)", "Base-10 logarithm (L)") },
         { c: "ln", r: "ln", c2: "exp", r2: "eˣ", d: janela.t("Logaritmo natural (N)", "Natural logarithm (N)") }],
        [{ c: "quadrado", r: "x²", c2: "cubo", r2: "x³", d: janela.t("Ao quadrado (Q)", "Square (Q)") },
         { c: "inverso", r: "1/x", d: janela.t("Inverso (R)", "Reciprocal (R)") },
         { c: "abs", r: "|x|", d: janela.t("Valor absoluto", "Absolute value") },
         { c: "EXP", r: "exp", d: janela.t("Notação científica: 1,5 exp 3 = 1.500 (E)", "Scientific notation: 1.5 exp 3 = 1,500 (E)") },
         { c: "mod", r: "mod", d: janela.t("Resto da divisão (M)", "Modulo (M)") }],
        [{ c: "raiz", r: "√x", c2: "raiz3", r2: "∛x", d: janela.t("Raiz quadrada (@)", "Square root (@)") },
         { c: "(", r: "(", d: janela.t("Abrir parêntese", "Open parenthesis") },
         { c: ")", r: ")", d: janela.t("Fechar parêntese", "Close parenthesis") },
         { c: "fatorial", r: "n!", d: janela.t("Fatorial (!)", "Factorial (!)") },
         { c: "/", r: "÷", t: "operador", d: janela.t("Dividir (/)", "Divide (/)") }],
        [{ c: "^", r: "xʸ", d: janela.t("Potência (^)", "Power (^)") }, n("7"), n("8"), n("9"),
         { c: "*", r: "×", t: "operador", d: janela.t("Multiplicar (*)", "Multiply (*)") }],
        [{ c: "raizy", r: "ʸ√x", d: janela.t("Raiz de índice y: x ʸ√ y", "y-th root: x ʸ√ y") }, n("4"), n("5"), n("6"),
         { c: "-", r: "−", t: "operador", d: janela.t("Subtrair (−)", "Subtract (−)") }],
        [{ c: "dez", r: "10ˣ", c2: "dois", r2: "2ˣ", d: janela.t("10 elevado a x", "10 to the power of x") }, n("1"), n("2"), n("3"),
         { c: "+", r: "+", t: "operador", d: janela.t("Somar (+)", "Add (+)") }],
        [{ c: "%", r: "%", d: janela.t("Porcentagem", "Percent") + " (%)" },
         { c: "neg", r: "+/−", t: "numero", d: janela.t("Trocar o sinal (F9)", "Negate (F9)") }, n("0"),
         { c: "virgula", r: sepDecimal, t: "numero", d: janela.t("Vírgula (, ou .)", "Decimal point") },
         { c: "=", r: "=", t: "igual", d: janela.t("Igual (Enter)", "Equals (Enter)") }]
    ]

    function apertou(chave) {
        if (chave === "segunda")
            janela.segunda = !janela.segunda;
        else
            janela.acionar(chave);
    }

    component Grade: GridLayout {
        id: grade
        property var linhas: []
        columns: linhas.length ? linhas[0].length : 4
        columnSpacing: 1
        rowSpacing: 1
        Repeater {
            model: {
                var l = [];
                for (var i = 0; i < grade.linhas.length; i++)
                    l = l.concat(grade.linhas[i]);
                return l;
            }
            BotaoCalc {
                required property var modelData
                readonly property bool trocada: janela.segunda && !!modelData.c2
                readonly property bool ehLimpar: modelData.c === "C" && pagina.cientifica
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                chave: ehLimpar ? (janela.tela.digitando ? "CE" : "C") : (trocada ? modelData.c2 : modelData.c)
                rotulo: ehLimpar ? chave : (trocada ? modelData.r2 : (modelData.r || ""))
                icone: modelData.i || ""
                tipo: modelData.t || "funcao"
                dica: modelData.d || ""
                repete: !!modelData.rep
                ligado: modelData.c === "segunda" && janela.segunda
                contador: modelData.c === "(" ? janela.tela.abertos : 0
                onAcionado: (c) => pagina.apertou(c)
            }
        }
    }

    // Botão chato da linha da memória (MC, MR, M+, M−, MS, M⌄).
    component BotaoMemoria: MouseArea {
        id: bm
        property string chave: ""
        property string rotulo: ""
        property bool ativo: true
        property string dica: ""
        property bool seta: false
        signal acionado()
        Layout.fillWidth: true
        implicitHeight: Math.round(janela.gu * 1.7)
        hoverEnabled: true
        cursorShape: ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
        Accessible.role: Accessible.Button
        Accessible.name: dica
        onClicked: if (ativo) acionado()
        function piscar() {
            if (ativo)
                pulsoM.restart();
        }
        Connections {
            target: janela
            function onPiscar(qual) {
                if (qual === bm.chave)
                    bm.piscar();
            }
        }
        Rectangle {
            id: fundoM
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.round(janela.gu * 0.32)
            color: janela.tinta(!bm.ativo ? 0 : (bm.pressed ? 0.1 : (bm.containsMouse ? 0.06 : 0)))
            scale: bm.pressed && bm.ativo ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        }
        SequentialAnimation {
            id: pulsoM
            NumberAnimation { target: fundoM; property: "scale"; to: 0.9; duration: 70 }
            NumberAnimation { target: fundoM; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }
        Row {
            anchors.centerIn: parent
            spacing: 1
            opacity: bm.ativo ? 1 : 0.32
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: bm.rotulo
                font.pixelSize: Math.round(janela.gu * 0.72)
                font.weight: Font.DemiBold
            }
            Kirigami.Icon {
                visible: bm.seta
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(janela.gu * 0.6)
                height: width
                source: "matsu-seta-symbolic"
                isMask: true
                color: janela.frente
                rotation: 90
            }
        }
        QQC2.ToolTip.visible: dica.length > 0 && containsMouse
        QQC2.ToolTip.text: dica
        QQC2.ToolTip.delay: 700
    }

    // ----- a calculadora -----
    Item {
        id: calc
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - (pagina.largo ? pagina.larguraPainel : 0)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: pagina.margem
            spacing: Math.round(janela.gu * 0.25)

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 0.35)
                Texto {
                    id: titulo
                    Layout.fillWidth: true
                    text: pagina.cientifica ? janela.t("Científica", "Scientific") : janela.t("Padrão", "Standard")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    onTextChanged: trocaTitulo.restart()
                    SequentialAnimation {
                        id: trocaTitulo
                        NumberAnimation { target: titulo; property: "opacity"; from: 0; to: 1; duration: 260 }
                    }
                }
                Botao {
                    visible: !pagina.largo
                    icone: Qt.resolvedUrl("icones/historico.svg")
                    dica: janela.t("Histórico (Ctrl+H)", "History (Ctrl+H)")
                    onClicado: janela.alternarPainel("historico")
                }
            }

            // ----- o visor -----
            Item {
                id: areaVisor
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(janela.gu * (pagina.cientifica ? 4.9 : 6.2))
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                readonly property real maior: Math.round(janela.gu * (pagina.cientifica ? 2.5 : 2.9))
                readonly property real menor: Math.round(janela.gu * 1.1)
                readonly property real largura: width - Math.round(janela.gu * 0.6)
                // O resultado encolhe para caber.
                readonly property real alvoFonte: Math.max(menor, Math.min(maior, Math.floor(maior * largura / Math.max(1, medida.advanceWidth * 1.04))))
                property real tamanhoFonte: alvoFonte
                Behavior on tamanhoFonte { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                TextMetrics {
                    id: medida
                    font.family: modeloFonte.font.family
                    font.pixelSize: areaVisor.maior
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    text: janela.tela.resultado
                }
                Text {
                    id: modeloFonte
                    visible: false
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pixelSize: Math.max(1, Math.round(areaVisor.tamanhoFonte))
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }

                // Copiou (Ctrl+C): o visor brilha de leve.
                Rectangle {
                    id: fundoBrilho
                    anchors.fill: parent
                    radius: Math.round(janela.gu * 0.45)
                    color: janela.tinta(0.09)
                    opacity: 0
                    SequentialAnimation {
                        id: brilho
                        NumberAnimation { target: fundoBrilho; property: "opacity"; to: 1; duration: 90 }
                        NumberAnimation { target: fundoBrilho; property: "opacity"; to: 0; duration: 650; easing.type: Easing.InQuad }
                    }
                }

                Texto {
                    id: textoConta
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: Math.round(janela.gu * 0.2)
                    anchors.rightMargin: Math.round(janela.gu * 0.3)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: janela.tela.expressao
                    opacity: 0.6
                    font.features: { "tnum": 1 }
                    transform: Translate {
                        id: deslocaConta
                    }
                    onTextChanged: trocaConta.restart()
                    ParallelAnimation {
                        id: trocaConta
                        NumberAnimation { target: deslocaConta; property: "x"; from: janela.gu * 0.5; to: 0; duration: 220; easing.type: Easing.OutCubic }
                        NumberAnimation { target: textoConta; property: "opacity"; from: 0.15; to: 0.6; duration: 220 }
                    }
                }
                VisorNumero {
                    id: numero
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(janela.gu * 0.3)
                    width: Math.min(implicitWidth, parent.width)
                    visible: !janela.tela.erro
                    fonte: modeloFonte.font
                }
                Texto {
                    id: textoErro
                    anchors.right: parent.right
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(janela.gu * 0.3)
                    horizontalAlignment: Text.AlignRight
                    visible: janela.tela.erro
                    text: janela.tela.erro ? janela.tela.resultado : ""
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Math.round(janela.gu * 0.85)
                    font.pixelSize: Math.round(janela.gu * (pagina.cientifica ? 1.4 : 1.6))
                    font.weight: Font.DemiBold
                    onVisibleChanged: if (visible) tremer.restart()
                    transform: Translate {
                        id: deslocaErro
                    }
                    SequentialAnimation {
                        id: tremer
                        NumberAnimation { target: deslocaErro; property: "x"; to: -janela.gu * 0.35; duration: 60 }
                        NumberAnimation { target: deslocaErro; property: "x"; to: janela.gu * 0.25; duration: 80 }
                        NumberAnimation { target: deslocaErro; property: "x"; to: 0; duration: 200; easing.type: Easing.OutBack }
                    }
                }
            }

            // Graus ou radianos (só na Científica).
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: pagina.cientifica ? seletorAngulo.implicitHeight + Math.round(janela.gu * 0.2) : 0
                clip: true
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                Seletor {
                    id: seletorAngulo
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: pagina.cientifica ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    opcoes: [{ id: "graus", nome: janela.t("Graus", "Degrees") }, { id: "radianos", nome: janela.t("Radianos", "Radians") }]
                    escolhido: janela.angulo
                    onEscolher: (id) => janela.angulo = id
                }
            }

            // ----- memória -----
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                BotaoMemoria {
                    chave: "MC"
                    rotulo: "MC"
                    ativo: janela.temMemoria
                    dica: janela.t("Limpar a memória (Ctrl+L)", "Memory clear (Ctrl+L)")
                    onAcionado: janela.memoria_("MC")
                }
                BotaoMemoria {
                    chave: "MR"
                    rotulo: "MR"
                    ativo: janela.temMemoria
                    dica: janela.t("Usar o número da memória (Ctrl+R)", "Memory recall (Ctrl+R)")
                    onAcionado: janela.memoria_("MR")
                }
                BotaoMemoria {
                    chave: "M+"
                    rotulo: "M+"
                    dica: janela.t("Somar à memória (Ctrl+P)", "Memory add (Ctrl+P)")
                    onAcionado: janela.memoria_("M+")
                }
                BotaoMemoria {
                    chave: "M-"
                    rotulo: "M−"
                    dica: janela.t("Tirar da memória (Ctrl+Q)", "Memory subtract (Ctrl+Q)")
                    onAcionado: janela.memoria_("M-")
                }
                BotaoMemoria {
                    chave: "MS"
                    rotulo: "MS"
                    dica: janela.t("Guardar na memória (Ctrl+M)", "Memory store (Ctrl+M)")
                    onAcionado: janela.memoria_("MS")
                }
                BotaoMemoria {
                    rotulo: "M"
                    seta: true
                    ativo: janela.temMemoria && !pagina.largo
                    visible: !pagina.largo
                    dica: janela.t("Ver a memória", "Show memory")
                    onAcionado: janela.alternarPainel("memoria")
                }
            }

            // ----- as teclas -----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Grade {
                    anchors.fill: parent
                    linhas: pagina.gradePadrao
                    opacity: pagina.cientifica ? 0 : 1
                    scale: pagina.cientifica ? 0.96 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                }
                Grade {
                    anchors.fill: parent
                    linhas: pagina.gradeCientifica
                    opacity: pagina.cientifica ? 1 : 0
                    scale: pagina.cientifica ? 1 : 1.04
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // ----- histórico fixo (janela larga) -----
    Item {
        visible: pagina.largo
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: pagina.larguraPainel
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Math.round(janela.gu * 0.8)
            anchors.bottomMargin: Math.round(janela.gu * 0.8)
            width: 1
            color: janela.tinta(0.08)
        }
        PainelHistorico {
            anchors.fill: parent
            anchors.leftMargin: 1
        }
    }

    // ----- histórico que desliza por cima (janela estreita) -----
    Rectangle {
        id: veu
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.4 : 0.18)
        readonly property bool aberto: janela.painelAberto && !pagina.largo
        opacity: aberto ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        MouseArea {
            anchors.fill: parent
            onClicked: janela.painelAberto = false
        }
    }
    Item {
        id: gaveta
        readonly property bool aberto: janela.painelAberto && !pagina.largo
        width: Math.min(pagina.width - janela.gu * 2.5, janela.gu * 17)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(janela.gu * 0.4)
        x: aberto ? pagina.width - width - Math.round(janela.gu * 0.4) : pagina.width + janela.gu
        visible: x < pagina.width
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        FundoBalao {
            anchors.fill: parent
        }
        PainelHistorico {
            anchors.fill: parent
            flutuante: true
            onEscolheu: janela.painelAberto = false
        }
    }
}
