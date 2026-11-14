// Matsu OS — o miolo das telas de login do KDE
// (org.kde.breeze.components.SessionManagementScreen), no lugar do original.
//
// A tela de login do Plasma Login Manager vem compilada dentro do programa: o
// Login.qml dela herda desta peça e põe aqui dentro o campo da senha, o botão de
// entrar e a escolha da sessão. Este arquivo arruma tudo no jeito do Mac, igual ao
// bloqueio do Matsu: a foto e o nome da pessoa mais para baixo, a senha numa
// pílula de vidro com a setinha dentro, o aviso embaixo da senha e os botões
// redondos (Suspender, Reiniciar, Desligar).
//
// Tem as mesmas propriedades, sinais e funções do original, porque o programa
// compilado usa todas: notificationMessage, actionItems, actionItemsVisible,
// userListModel, userListCurrentIndex, userListCurrentItem, showUserList,
// userList, fontSize, authenticationTypeItem, os filhos (default), userSelected()
// e playHighlightAnimation(). A lista de pessoas continua a UserList do KDE.
//
// O campo e o botão do KDE recebem só a roupa nova (fundo, cor, tamanho). Se algo
// não for como esperado, a peça fica como o KDE fez e o login continua igual:
// nada aqui mexe na senha, só no desenho.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

FocusScope {
    id: root

    /*
     * Aviso para a pessoa (Caps Lock ligado, senha errada), embaixo da senha.
     */
    property alias notificationMessage: notificationsLabel.text

    /*
     * Os botões (ActionButton) que ficam embaixo de tudo.
     */
    property alias actionItems: actionItemsLayout.children

    /*
     * Mostra ou esconde os botões de uma vez.
     */
    property alias actionItemsVisible: actionItemsLayout.visible

    /*
     * A lista de pessoas (UserModel na tela de login, SessionsModel no bloqueio).
     */
    property alias userListModel: userListView.model

    property alias userListCurrentIndex: userListView.currentIndex
    property alias userListCurrentItem: userListView.currentItem
    property bool showUserList: true

    property alias userList: userListView

    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2

    /*
     * Os botões de escolher senha, digital ou cartão (Plasma 6.8).
     */
    property Item authenticationTypeItem: null

    default property alias _children: innerLayout.children

    signal userSelected()

    function playHighlightAnimation() {
        bounceAnimation.start();
    }

    // Medidas do Matsu: tudo sai da altura da tela, como no bloqueio.
    readonly property real alturaTela: Window.window && Window.window.height > 0 ? Window.window.height : height
    readonly property real alturaCampo: Math.max(32, Math.round(alturaTela * 0.033))
    readonly property real ladoFoto: Math.max(Kirigami.Units.gridUnit * 3.5, Math.round(alturaTela * 0.074))
    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0

    UserList {
        id: userListView
        visible: root.showUserList && y > 0
        anchors.left: parent.left
        anchors.right: parent.right
        // A foto um pouco abaixo do meio da tela; a hora fica no meio do espaço de
        // cima (quem posiciona a hora é a tela de login, pela altura desta lista).
        y: Math.round(root.alturaTela * 0.58)
        // Só a foto e o nome: a senha vem logo embaixo (os itens da lista são mais
        // altos, mas não cortam nada e não pegam o clique da senha, que fica por cima).
        height: root.ladoFoto + Math.round(root.ladoFoto * 0.16) + Math.max(13, Math.round(root.ladoFoto * 0.2)) * 1.5
        fontSize: root.fontSize
        onUserSelected: root.userSelected()
    }

    ColumnLayout {
        id: prompts
        anchors.left: parent.left
        anchors.right: parent.right
        y: userListView.visible ? userListView.y + userListView.height + Math.round(root.alturaTela * 0.012)
                                : Math.round(root.alturaTela * 0.62)
        spacing: 0

        RowLayout {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.bottomMargin: visible ? Math.round(root.alturaTela * 0.01) : 0
            spacing: 0
            visible: root.authenticationTypeItem !== null
            children: [root.authenticationTypeItem]
        }

        // O campo da senha (e o do nome, em "Outros..."), o botão de entrar e a
        // escolha da sessão: vêm do Login.qml do KDE.
        ColumnLayout {
            id: innerLayout
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(root.alturaCampo * 6.6)
            Layout.maximumWidth: Math.round(root.alturaCampo * 6.6)
            spacing: Math.round(root.alturaTela * 0.01)
            onChildrenChanged: Qt.callLater(root.vestir)
        }

        Text {
            id: notificationsLabel
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: text.length > 0 ? Math.round(root.alturaTela * 0.009) : 0
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            visible: text.length > 0
            color: "white"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.max(12, Math.round(root.alturaTela * 0.0125))
            font.weight: Font.Medium
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.3)

            SequentialAnimation {
                id: bounceAnimation
                loops: 1
                NumberAnimation { target: notificationsLabel; property: "scale"; to: 1.08; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: notificationsLabel; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutBack }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(root.alturaTela * 0.03)
            implicitHeight: actionItemsLayout.implicitHeight
            implicitWidth: actionItemsLayout.implicitWidth
            GridLayout {
                id: actionItemsLayout
                anchors.centerIn: parent

                readonly property int spacing: Math.round(root.alturaTela * 0.012)
                rowSpacing: spacing
                columnSpacing: spacing

                readonly property int buttonCount: visibleChildren.length
                readonly property int singleRowWidth: children.length > 0
                    ? (children[0].implicitWidth * buttonCount) + (spacing * (buttonCount - 1)) : 0
                columns: singleRowWidth < root.width ? Math.max(1, buttonCount) : Math.max(1, Math.ceil(buttonCount / 2))
            }
        }
    }

    // ---- A roupa do Matsu nos campos do KDE ----

    property var vestidos: []

    Component {
        id: fundoPilula
        Rectangle {
            property Item campo: null
            implicitHeight: root.alturaCampo
            radius: height / 2
            color: Qt.rgba(1, 1, 1, campo && campo.activeFocus ? 0.2 : 0.15)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, campo && campo.activeFocus ? 0.38 : 0.22)
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    // A setinha de entrar, dentro da pílula da senha: aperta o botão do KDE.
    Component {
        id: setaDentro
        Rectangle {
            id: seta
            property Item campo: null
            property Item botao: null
            anchors.right: parent ? parent.right : undefined
            anchors.rightMargin: Math.round(root.alturaCampo * 0.14)
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: Math.round(root.alturaCampo * 0.72)
            height: width
            radius: width / 2
            visible: campo !== null && campo.text.length > 0
            color: Qt.rgba(1, 1, 1, toqueSeta.pressed ? 0.42 : (toqueSeta.containsMouse ? 0.34 : 0.25))
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.6)
                height: width
                source: "/usr/share/icons/Matsu/status/symbolic/matsu-seta-symbolic.svg"
                isMask: true
                color: "white"
            }
            MouseArea {
                id: toqueSeta
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (seta.botao) seta.botao.clicked()
            }
            Accessible.role: Accessible.Button
            Accessible.name: root.pt ? "Entrar" : "Log in"
        }
    }

    function ehCampo(item) {
        return item && ("echoMode" in item) && ("placeholderText" in item) && ("selectAll" in item);
    }
    function ehBotao(item) {
        return item && !ehCampo(item) && ("clicked" in item) && ("icon" in item) && ("flat" in item);
    }

    function vestirCampo(campo, senha) {
        campo.background = fundoPilula.createObject(campo, { campo: campo });
        campo.color = "white";
        if ("placeholderTextColor" in campo)
            campo.placeholderTextColor = Qt.rgba(1, 1, 1, 0.62);
        campo.selectionColor = Qt.rgba(1, 1, 1, 0.35);
        campo.selectedTextColor = "white";
        campo.verticalAlignment = TextInput.AlignVCenter;
        campo.font.family = Kirigami.Theme.defaultFont.family;
        campo.font.pixelSize = Math.round(root.alturaCampo * 0.36);
        campo.topPadding = 0;
        campo.bottomPadding = 0;
        campo.leftPadding = Math.round(root.alturaCampo * 0.45);
        campo.Layout.preferredHeight = root.alturaCampo;
        if (senha) {
            campo.passwordCharacter = "●";
            campo.placeholderText = root.pt ? "Digite a senha" : "Enter password";
            // Sem o olhinho: como no Mac (e no bloqueio do Matsu).
            if ("rightActions" in campo)
                campo.rightActions = [];
        } else if (root.pt) {
            campo.placeholderText = "Nome de usuário";
        }
        campo.rightPadding = Math.round(root.alturaCampo * 0.45);
    }

    function vestirBotao(botao, campo) {
        botao.background = fundoPilula.createObject(botao, { campo: botao });
        if (campo) {
            // O botão do KDE some quando há senha (a setinha fica dentro da pílula),
            // mas continua lá para receber o foco ao entrar; sem senha, vira uma
            // pílula "Entrar".
            botao.opacity = Qt.binding(() => campo.visible ? 0 : 1);
            botao.Layout.maximumWidth = Qt.binding(() => campo.visible ? 0 : Number.POSITIVE_INFINITY);
            botao.Layout.preferredHeight = root.alturaCampo;
            if (botao.parent && ("spacing" in botao.parent))
                botao.parent.spacing = Qt.binding(() => campo.visible ? 0 : Kirigami.Units.smallSpacing);
            const seta = setaDentro.createObject(campo, { campo: campo, botao: botao });
            campo.rightPadding = Qt.binding(() => Math.round(root.alturaCampo * 0.45) + (seta.visible ? seta.width : 0));
        }
    }

    function filhosDe(item) {
        let lista = [];
        for (let i = 0; item && i < item.children.length; ++i) {
            const filho = item.children[i];
            lista.push(filho);
            if (!ehCampo(filho))
                lista = lista.concat(filhosDe(filho));
        }
        return lista;
    }

    function vestir() {
        try {
            const todos = filhosDe(innerLayout);
            const campos = todos.filter(ehCampo);
            const botoes = todos.filter(ehBotao);
            for (const campo of campos) {
                if (vestidos.indexOf(campo) !== -1)
                    continue;
                vestidos.push(campo);
                vestirCampo(campo, "showPassword" in campo);
            }
            for (const botao of botoes) {
                if (vestidos.indexOf(botao) !== -1)
                    continue;
                // Só o botão de entrar, que fica ao lado da senha.
                const senha = campos.find(c => ("showPassword" in c) && c.parent === botao.parent);
                if (!senha)
                    continue;
                vestidos.push(botao);
                vestirBotao(botao, senha);
            }
        } catch (erro) {
            console.warn("Matsu: a roupa nova da tela de login não serviu (fica a do KDE):", erro);
        }
    }

    Component.onCompleted: Qt.callLater(root.vestir)
}
