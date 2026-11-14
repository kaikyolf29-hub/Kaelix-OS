// O miolo da tela de bloqueio do Matsu, no jeito do Mac: embaixo, no centro, a foto
// da pessoa, o nome, a senha numa pílula de vidro e os botões redondos (Suspender,
// Trocar de pessoa). A hora grande fica em cima (Matsu.Relogio, no LockScreenUi).
//
// Fica no lugar do MainBlock do KDE (a troca é feita na montagem por
// build_files/telas-matsu.py) e tem as mesmas propriedades que o LockScreenUi usa:
// mainPasswordBox, showPassword, lockScreenUiVisible, userListModel, actionItems,
// notificationMessage, visibleBoundary e o sinal passwordResult; do Plasma 6.8,
// passwordInputVisible (sem senha quando a pessoa escolhe a digital) e
// authenticationTypeItem (os botões para escolher senha, digital ou cartão).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import "file:///usr/share/matsu/telas" as Matsu

FocusScope {
    id: bloco

    readonly property alias mainPasswordBox: campo
    property bool lockScreenUiVisible: false
    property alias showPassword: campo.mostrar
    property var userListModel: null
    property bool showUserList: true
    readonly property alias userList: coluna
    property string notificationMessage: ""
    // Plasma 6.8: some com a senha quando o jeito escolhido não usa senha.
    property bool passwordInputVisible: true
    // Plasma 6.8: os botões de escolher senha, digital ou cartão (só aparecem com
    // mais de um jeito); ficam logo acima da senha.
    property Item authenticationTypeItem: null
    onAuthenticationTypeItemChanged: if (authenticationTypeItem) authenticationTypeItem.parent = caixaTipos
    // Os botões do KDE (Suspender, Hibernar, Trocar de usuário) ficam guardados fora
    // da tela; aqui aparecem como os botões redondos do Matsu, que chamam os deles.
    property alias actionItems: guarda.children
    default property alias extras: extrasColuna.data
    // Até onde a tela precisa aparecer quando o teclado virtual sobe.
    readonly property int visibleBoundary: coluna.y + coluna.height + Kirigami.Units.gridUnit

    signal passwordResult(string password)
    signal userSelected()

    readonly property real alturaTela: Window.window ? Window.window.height : height
    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0

    function playHighlightAnimation() {
        pulo.restart();
    }
    function startLogin() {
        const senha = campo.text;
        // Tira o foco do campo antes (contorna um defeito do Qt ao fechar com o campo focado).
        bloco.forceActiveFocus();
        passwordResult(senha);
    }
    function iconeDoMatsu(nome) {
        return ({
            "system-suspend": "matsu-lua",
            "system-suspend-hibernate": "matsu-lua",
            "system-switch-user": "matsu-trocar-usuario",
            "system-reboot": "matsu-reiniciar",
            "system-shutdown": "matsu-desligar"
        })[nome] || nome;
    }

    Item {
        id: guarda
        x: -100000
        width: 0
        height: 0
        // Fora do Tab: quem recebe o foco são os botões redondos.
        enabled: false
    }

    ColumnLayout {
        id: coluna
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(bloco.alturaTela - height - bloco.alturaTela * 0.055)
        spacing: 0

        Repeater {
            model: bloco.userListModel
            delegate: Matsu.Pessoa {
                required property var model
                Layout.alignment: Qt.AlignHCenter
                visible: model.index === 0
                lado: Math.round(bloco.alturaTela * 0.074)
                nome: model.realName || model.name || ""
                foto: model.icon || ""
            }
        }

        ColumnLayout {
            id: caixaTipos
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: children.length > 0 && children[0].visible ? Math.round(bloco.alturaTela * 0.012) : 0
        }

        Matsu.CampoSenha {
            id: campo
            visible: bloco.passwordInputVisible
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(bloco.alturaTela * 0.016)
            altura: Math.max(32, Math.round(bloco.alturaTela * 0.033))
            Layout.preferredWidth: Math.round(altura * 6.4)
            text: PasswordSync.password
            focus: true
            enabled: !authenticator.graceLocked
            // Pisca só quando aparece (acorda a tela sem gastar desenho à toa).
            cursorVisible: visible && activeFocus
            onEnviar: if (bloco.lockScreenUiVisible) bloco.startLogin()

            Connections {
                target: root
                function onClearPassword() {
                    campo.forceActiveFocus();
                    campo.text = "";
                    campo.text = Qt.binding(() => PasswordSync.password);
                }
                function onNotificationRepeated() {
                    bloco.playHighlightAnimation();
                }
            }
        }
        Binding {
            target: PasswordSync
            property: "password"
            value: campo.text
        }

        // Avisos: Caps Lock ligado, senha errada.
        Text {
            id: aviso
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(bloco.alturaTela * 0.009)
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: bloco.notificationMessage
            visible: text.length > 0
            color: "white"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.max(12, Math.round(bloco.alturaTela * 0.0125))
            font.weight: Font.Medium
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.3)
            SequentialAnimation {
                id: pulo
                NumberAnimation { target: aviso; property: "scale"; to: 1.08; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: aviso; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutBack }
            }
        }
        // Digital ou cartão, quando o computador tem.
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(bloco.alturaTela * 0.006)
            readonly property int tipos: authenticator.authenticatorTypes
            visible: (tipos & ScreenLocker.Authenticator.Fingerprint) || (tipos & ScreenLocker.Authenticator.Smartcard)
            text: (tipos & ScreenLocker.Authenticator.Fingerprint)
                ? (bloco.pt ? "Ou use a digital no leitor" : "Or use your fingerprint")
                : (bloco.pt ? "Ou use o cartão" : "Or use your smartcard")
            color: "white"
            opacity: 0.75
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.max(11, Math.round(bloco.alturaTela * 0.0115))
        }

        // Música tocando (os controles do KDE, quando ligados nos ajustes).
        ColumnLayout {
            id: extrasColuna
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(bloco.alturaTela * 0.03)
            spacing: Math.round(bloco.alturaTela * 0.02)
            Repeater {
                model: guarda.children
                delegate: Matsu.BotaoRedondo {
                    required property var modelData
                    visible: modelData.visible
                    lado: Math.max(36, Math.round(bloco.alturaTela * 0.036))
                    texto: String(modelData.text || "").replace("&", "")
                    icone: bloco.iconeDoMatsu(modelData.icon ? modelData.icon.name : "")
                    onClicado: modelData.clicked()
                }
            }
        }
    }
}
