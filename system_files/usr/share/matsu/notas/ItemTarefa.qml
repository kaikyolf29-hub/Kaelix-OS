// Um item da lista de tarefas: o pegador (para arrastar), a Marca redonda que
// pula, o texto e o xis para tirar. Ao marcar, o risco corre da esquerda para a
// direita e o texto apaga um pouco; depois a lista leva o item para os concluídos.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: linha

    property string texto: ""
    property bool feito: false
    property bool somenteLer: false
    property bool arrastando: false

    signal alternar(bool feito)
    signal editado(string texto)
    signal enter(int posicao)
    signal apagarVazio()
    signal juntar()
    signal subir()
    signal descer()
    signal remover()
    signal arrastar(real yNaLista)
    signal soltar()

    function focar(posicao) {
        campo.forceActiveFocus();
        campo.cursorPosition = posicao < 0 ? campo.length : Math.min(posicao, campo.length);
    }
    readonly property bool emFoco: campo.activeFocus

    implicitHeight: Math.max(Math.round(janela.gu * 2.05), campo.contentHeight + Math.round(janela.gu * 0.75))

    HoverHandler {
        id: sobre
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Math.round(janela.gu * 0.3)
        radius: Math.round(janela.gu * 0.4)
        color: linha.arrastando ? (janela.escuro ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.85)) : janela.tinta(sobre.hovered && !linha.somenteLer ? 0.035 : 0)
        border.width: linha.arrastando ? 1 : 0
        border.color: janela.tinta(0.12)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    // O pegador: seis pontinhos que aparecem com o mouse.
    MouseArea {
        id: pegador
        x: -Math.round(janela.gu * 1.15)
        width: Math.round(janela.gu * 0.9)
        height: parent.height
        visible: !linha.somenteLer && !linha.feito
        enabled: visible
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        opacity: sobre.hovered || containsMouse || pressed ? (containsMouse || pressed ? 0.75 : 0.4) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        onPressed: linha.arrastando = true
        onPositionChanged: (m) => {
            if (pressed)
                linha.arrastar(mapToItem(linha.parent, m.x, m.y).y);
        }
        onReleased: {
            linha.arrastando = false;
            linha.soltar();
        }
        onCanceled: {
            linha.arrastando = false;
            linha.soltar();
        }
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 3
            Repeater {
                model: 6
                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: janela.frente
                }
            }
        }
        QQC2.ToolTip.visible: containsMouse && !pressed
        QQC2.ToolTip.text: janela.t("Arraste para mudar a ordem", "Drag to reorder")
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay * 2
    }

    Marca {
        id: marca
        x: 0
        y: Math.round((Math.round(janela.gu * 2.05) - height) / 2)
        redonda: true
        marcada: linha.feito
        enabled: !linha.somenteLer
        nome: linha.texto
        onTrocada: (m) => linha.alternar(m)
    }

    TextEdit {
        id: campo
        anchors.left: marca.right
        anchors.leftMargin: Math.round(janela.gu * 0.6)
        anchors.right: tirar.left
        anchors.rightMargin: 4
        y: Math.round((Math.round(janela.gu * 2.05) - lineHeightRef.height) / 2)
        text: linha.texto
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        color: janela.frente
        opacity: linha.feito ? 0.48 : 1
        selectionColor: janela.escuro ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.16)
        selectedTextColor: janela.frente
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.08
        font.strikeout: linha.feito && riscado
        readOnly: linha.somenteLer
        selectByMouse: true
        property bool riscado: false
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
        onTextChanged: {
            if (text.indexOf("\n") >= 0) {
                var p = cursorPosition;
                text = text.replace(/\n/g, " ");
                cursorPosition = Math.min(p, length);
                return;
            }
            if (text !== linha.texto)
                linha.editado(text);
        }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                e.accepted = true;
                linha.enter(cursorPosition);
            } else if (e.key === Qt.Key_Backspace && cursorPosition === 0 && selectedText.length === 0) {
                e.accepted = true;
                if (length === 0)
                    linha.apagarVazio();
                else
                    linha.juntar();
            } else if (e.key === Qt.Key_Up && cursorRectangle.y < lineHeightRef.height / 2) {
                e.accepted = true;
                linha.subir();
            } else if (e.key === Qt.Key_Down && cursorRectangle.y + cursorRectangle.height > contentHeight - lineHeightRef.height / 2) {
                e.accepted = true;
                linha.descer();
            }
        }
        // Uma linha de texto, para centralizar a primeira linha com a Marca.
        Text {
            id: lineHeightRef
            visible: false
            text: "Ag"
            font: campo.font
        }
        Texto {
            anchors.left: parent.left
            anchors.top: parent.top
            visible: campo.length === 0 && campo.activeFocus
            text: janela.t("Item da lista", "List item")
            font: campo.font
            opacity: 0.35
        }
        // O risco que corre ao marcar (depois vira o tachado da fonte).
        Rectangle {
            id: risco
            x: 0
            y: Math.round(lineHeightRef.height * 0.55)
            height: 1.5
            width: 0
            color: janela.frente
            visible: !campo.riscado && width > 0
        }
        NumberAnimation {
            id: correr
            target: risco
            property: "width"
            from: 0
            to: Math.min(campo.contentWidth, campo.width)
            duration: 280
            easing.type: Easing.OutCubic
            onFinished: {
                if (linha.feito)
                    campo.riscado = true;
                risco.width = 0;
            }
        }
    }

    onFeitoChanged: {
        if (feito) {
            campo.riscado = false;
            correr.restart();
        } else {
            correr.stop();
            risco.width = 0;
            campo.riscado = false;
        }
    }
    Component.onCompleted: campo.riscado = feito

    // Tirar o item.
    MouseArea {
        id: tirar
        anchors.right: parent.right
        y: Math.round((Math.round(janela.gu * 2.05) - height) / 2)
        width: Math.round(janela.gu * 1.4)
        height: width
        visible: !linha.somenteLer
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: sobre.hovered || campo.activeFocus ? 1 : 0
        onClicked: linha.remover()
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: janela.tinta(tirar.containsMouse ? 0.09 : 0)
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
            height: width
            source: "matsu-fechar-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.6
        }
        QQC2.ToolTip.visible: containsMouse
        QQC2.ToolTip.text: janela.t("Tirar da lista", "Remove from list")
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }
}
