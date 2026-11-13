// Lista suspensa: o botão mostra a escolha e a setinha; ao abrir, a lista desce
// com as opções e o visto na escolhida (como o "dropdown" do vídeo de referência).
// Lista comprida não passa da janela: abre para o lado que tiver mais espaço (para
// baixo ou para cima), rola, e a escolhida já aparece no meio ao abrir.
// Teclado: setas trocam a escolha (fechada) ou andam na lista (aberta), Enter ou
// espaço escolhe, Esc fecha.
//   Suspensa { opcoes: [{ id: "nome", nome: "Nome" }, ...]; escolhido: "nome"; onEscolher: (id) => ... }
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

MouseArea {
    id: suspensa

    property var opcoes: []
    property var escolhido
    property string nome: ""
    property string icone: ""
    property bool ativo: true

    signal escolher(var id)

    readonly property int indiceAtual: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].id === escolhido)
                return i;
        return opcoes.length > 0 ? 0 : -1;
    }
    readonly property var atual: indiceAtual >= 0 ? opcoes[indiceAtual] : null

    function abrir() {
        if (!lista.opened)
            lista.open();
    }
    // Fechada, as setas trocam a escolha direto (como no Windows).
    function andar(d) {
        var n = indiceAtual + d;
        if (n >= 0 && n < opcoes.length)
            escolher(opcoes[n].id);
    }

    implicitWidth: Math.max(Math.round(janela.gu * 8), linha.implicitWidth + Math.round(janela.gu * 1.4))
    implicitHeight: Math.round(janela.gu * 2)
    hoverEnabled: true
    enabled: ativo
    opacity: ativo ? 1 : 0.5
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: nome
    Accessible.description: atual ? atual.nome : ""
    onClicked: lista.opened ? lista.close() : lista.open()
    Keys.onSpacePressed: abrir()
    Keys.onReturnPressed: abrir()
    Keys.onEnterPressed: abrir()
    Keys.onUpPressed: andar(-1)
    Keys.onDownPressed: (e) => {
        if (e.modifiers & Qt.AltModifier)
            abrir();
        else
            andar(1);
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.4)
        scale: suspensa.pressed ? 0.985 : 1
        color: janela.tinta(suspensa.pressed ? 0.1 : (suspensa.containsMouse || lista.opened ? 0.075 : (janela.escuro ? 0.05 : 0.04)))
        border.width: 1
        border.color: suspensa.activeFocus || lista.opened ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
    }
    RowLayout {
        id: linha
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.7)
        anchors.rightMargin: Math.round(janela.gu * 0.55)
        spacing: Math.round(janela.gu * 0.45)
        Kirigami.Icon {
            visible: suspensa.icone.length > 0 || (suspensa.atual && (suspensa.atual.icone || "").length > 0)
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: suspensa.atual && suspensa.atual.icone ? suspensa.atual.icone : suspensa.icone
            isMask: true
            color: janela.frente
        }
        Texto {
            Layout.fillWidth: true
            text: suspensa.atual ? suspensa.atual.nome : ""
            elide: Text.ElideRight
        }
        Kirigami.Icon {
            Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.small * 0.8)
            Layout.preferredHeight: Layout.preferredWidth
            source: "matsu-seta-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.7
            rotation: lista.opened ? -90 : 90
            Behavior on rotation {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    QQC2.Popup {
        id: lista

        // Para cima quando embaixo não cabe e em cima tem mais espaço.
        property bool paraCima: false
        property real alturaMax: 100000
        // A opção acesa (mouse ou setas); Enter escolhe ela.
        property int realce: -1
        readonly property int folga: Math.round(janela.gu * 0.5)
        readonly property real alturaNatural: coluna.implicitHeight + 2 * padding

        function medir() {
            var p = suspensa.mapToItem(null, 0, 0);
            var embaixo = janela.height - (p.y + suspensa.height + 4) - folga;
            var emCima = p.y - 4 - folga;
            paraCima = alturaNatural > embaixo && emCima > embaixo;
            alturaMax = Math.max(suspensa.height * 2, paraCima ? emCima : embaixo);
        }
        // Deixa a opção i à vista (no meio, se "centrar").
        function mostrar(i, centrar) {
            var item = i >= 0 ? repetidor.itemAt(i) : null;
            if (!item)
                return;
            var vista = rolagem.height;
            var max = Math.max(0, rolagem.contentHeight - vista);
            var y = rolagem.contentY;
            if (centrar)
                y = item.y - (vista - item.height) / 2;
            else if (item.y < y)
                y = item.y;
            else if (item.y + item.height > y + vista)
                y = item.y + item.height - vista;
            rolagem.contentY = Math.max(0, Math.min(max, y));
        }
        function andar(d) {
            var n = realce < 0 ? suspensa.indiceAtual : realce + d;
            realce = Math.max(0, Math.min(suspensa.opcoes.length - 1, n));
            mostrar(realce, false);
        }
        function escolherRealce() {
            if (realce < 0 || realce >= suspensa.opcoes.length)
                return;
            var id = suspensa.opcoes[realce].id;
            close();
            suspensa.escolher(id);
        }

        y: paraCima ? -height - 4 : suspensa.height + 4
        width: Math.max(suspensa.width, coluna.implicitWidth + 2 * padding + (rolagem.rola ? barra.width : 0))
        height: Math.min(alturaNatural, alturaMax)
        padding: 4
        focus: true
        transformOrigin: paraCima ? QQC2.Popup.Bottom : QQC2.Popup.Top
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        onAboutToShow: {
            medir();
            realce = suspensa.indiceAtual;
            mostrar(suspensa.indiceAtual, true);
        }
        onOpened: mostrar(suspensa.indiceAtual, true)
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 110 }
        }
        background: FundoBalao {}
        contentItem: Flickable {
            id: rolagem
            readonly property bool rola: contentHeight > height + 1
            implicitWidth: coluna.implicitWidth
            implicitHeight: coluna.implicitHeight
            contentWidth: width
            contentHeight: coluna.implicitHeight
            clip: rola
            boundsBehavior: Flickable.StopAtBounds
            interactive: rola
            focus: true
            QQC2.ScrollBar.vertical: BarraRolagem {
                id: barra
            }
            Keys.onUpPressed: lista.andar(-1)
            Keys.onDownPressed: lista.andar(1)
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Home) {
                    lista.realce = 0;
                    lista.mostrar(0, false);
                    e.accepted = true;
                } else if (e.key === Qt.Key_End) {
                    lista.realce = suspensa.opcoes.length - 1;
                    lista.mostrar(lista.realce, false);
                    e.accepted = true;
                } else if (e.key === Qt.Key_PageDown || e.key === Qt.Key_PageUp) {
                    lista.andar(e.key === Qt.Key_PageDown ? 6 : -6);
                    e.accepted = true;
                }
            }
            Keys.onReturnPressed: lista.escolherRealce()
            Keys.onEnterPressed: lista.escolherRealce()
            Keys.onSpacePressed: lista.escolherRealce()

            ColumnLayout {
                id: coluna
                width: rolagem.width - (rolagem.rola ? barra.width : 0)
                spacing: 1
                Repeater {
                    id: repetidor
                    model: suspensa.opcoes
                    MouseArea {
                        id: opcao
                        required property var modelData
                        required property int index
                        readonly property bool escolhida: suspensa.indiceAtual === index
                        readonly property bool acesa: lista.realce === index
                        Layout.fillWidth: true
                        implicitWidth: linhaOpcao.implicitWidth + Math.round(janela.gu * 1.2)
                        implicitHeight: Math.round(janela.gu * 1.95)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.MenuItem
                        Accessible.name: modelData.nome
                        Accessible.checked: escolhida
                        onContainsMouseChanged: if (containsMouse) lista.realce = index
                        onClicked: { lista.close(); suspensa.escolher(modelData.id); }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.3)
                            color: janela.tinta(opcao.pressed ? 0.1 : (opcao.acesa ? 0.07 : (opcao.escolhida ? 0.045 : 0)))
                            Behavior on color {
                                ColorAnimation {
                                    duration: 90
                                }
                            }
                        }
                        RowLayout {
                            id: linhaOpcao
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(janela.gu * 0.6)
                            anchors.rightMargin: Math.round(janela.gu * 0.6)
                            spacing: Math.round(janela.gu * 0.5)
                            Kirigami.Icon {
                                visible: (opcao.modelData.icone || "").length > 0
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: opcao.modelData.icone || ""
                                isMask: true
                                color: janela.frente
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: opcao.modelData.nome
                                font.weight: opcao.escolhida ? Font.DemiBold : Font.Normal
                            }
                            Shape {
                                Layout.preferredWidth: Math.round(janela.gu * 0.8)
                                Layout.preferredHeight: Layout.preferredWidth
                                opacity: opcao.escolhida ? 1 : 0
                                scale: opcao.escolhida ? 1 : 0.5
                                preferredRendererType: Shape.CurveRenderer
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Kirigami.Units.longDuration
                                        easing.type: Easing.OutBack
                                    }
                                }
                                ShapePath {
                                    fillColor: "transparent"
                                    strokeColor: janela.frente
                                    strokeWidth: 2
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: janela.gu * 0.8 * 0.12
                                    startY: janela.gu * 0.8 * 0.52
                                    PathLine { x: janela.gu * 0.8 * 0.4; y: janela.gu * 0.8 * 0.8 }
                                    PathLine { x: janela.gu * 0.8 * 0.9; y: janela.gu * 0.8 * 0.22 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
