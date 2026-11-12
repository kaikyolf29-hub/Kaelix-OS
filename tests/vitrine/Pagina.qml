import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../system_files/usr/share/matsu/comum"

QQC2.ScrollView {
    id: pagina
    contentWidth: availableWidth
    QQC2.ScrollBar.vertical: BarraRolagem {}

    GridLayout {
        width: pagina.availableWidth - janela.gu * 2.4
        x: janela.gu * 1.2
        y: janela.gu * 1.2
        columns: 3
        columnSpacing: janela.gu
        rowSpacing: janela.gu

        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                Texto { text: "Saldo"; opacity: 0.6 }
                NumeroRolante {
                    texto: "R$ " + janela.num(janela.total, 2)
                    font.pixelSize: janela.gu * 2.2
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
                RowLayout {
                    Contador { valor: janela.passo; minimo: 1; maximo: 9; onMudou: (v) => janela.passo = v }
                    Contador { valor: 10; minimo: 5; maximo: 60; passo: 5; sufixo: " min" }
                }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            RowLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                spacing: janela.gu
                Anel { valor: janela.passo / 4; texto: janela.passo + "/4"; subtexto: "tarefas"; Layout.preferredWidth: janela.gu * 6 }
                ColumnLayout {
                    spacing: janela.gu * 0.5
                    RowLayout { Marca { marcada: janela.marcadaA; onTrocada: (m) => janela.marcadaA = m } Texto { text: "Comprar café" } }
                    RowLayout { Marca { marcada: janela.marcadaB; redonda: true; onTrocada: (m) => janela.marcadaB = m } Texto { text: "Responder e-mail" } }
                    RowLayout { Chave { ligada: janela.marcadaB; onTrocada: (l) => janela.marcadaB = l } Texto { text: "Chave" } }
                    Girando {}
                }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                Flow {
                    Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
                    spacing: janela.gu * 0.4
                    Repeater {
                        model: [["rock", "Rock"], ["jazz", "Jazz"], ["pop", "Pop"], ["lofi", "Lo-fi"]]
                        Etiqueta {
                            required property var modelData
                            texto: modelData[1]
                            escolhida: !!janela.chips[modelData[0]]
                            onTrocada: (e) => { var c = Object.assign({}, janela.chips); c[modelData[0]] = e; janela.chips = c; }
                        }
                    }
                }
                Deslizante { Layout.fillWidth: true; valor: janela.volume; onMovido: (v) => janela.volume = v; formato: (v) => janela.num(v) + "%" }
                Seletor { opcoes: [{ id: "a", nome: "Dia" }, { id: "b", nome: "Semana" }, { id: "c", nome: "Mês" }]; escolhido: "b" }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.columnSpan: 2
            Layout.preferredHeight: janela.gu * 5.6
            RowLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                spacing: janela.gu
                Rectangle {
                    Layout.preferredWidth: janela.gu * 2.6; Layout.preferredHeight: width; radius: width / 2; color: janela.frente
                    Kirigami.Icon { anchors.centerIn: parent; width: janela.gu; height: width; source: "matsu-jogar-symbolic"; isMask: true; color: janela.escuro ? "#1a1a1e" : "#fff" }
                }
                Onda {
                    Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
                    amostras: { var r = []; for (var i = 0; i < 120; i++) r.push(0.25 + 0.75 * Math.abs(Math.sin(i * 0.37) * Math.cos(i * 0.11))); return r; }
                    progresso: 0.42
                }
                Texto { text: "1:12 / 2:48"; opacity: 0.65; font.features: { "tnum": 1 } }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 5.6
            RowLayout {
                anchors.centerIn: parent
                spacing: janela.gu * 0.6
                BotaoDestaque { texto: "Enviar"; estado: janela.estadoBotao; textoFeito: "Enviado"; onClicado: janela.estadoBotao = "carregando" }
                BotaoDestaque { texto: "Apagar"; perigo: true; onClicado: dialogo.perguntar({ titulo: "Apagar a nota?", texto: "Não dá para desfazer.", sim: "Apagar", perigo: true }, function () { janela.avisoRapido("Nota apagada", "certo", "Desfazer", function () {}); }) }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 6.5
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                Campo { Layout.fillWidth: true; dica: "Nome do alarme"; icone: "matsu-sino-symbolic"; texto: "Acordar" }
                Suspensa {
                    Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
                    opcoes: [{ id: "nome", nome: "Ordenar por nome" }, { id: "data", nome: "Ordenar por data" }, { id: "tam", nome: "Ordenar por tamanho" }]
                    escolhido: janela.ordem
                    onEscolher: (id) => janela.ordem = id
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.columnSpan: 2
            spacing: janela.gu * 0.4
            Sanfona {
                titulo: "Como funciona o alarme?"
                aberta: true
                Texto { width: parent.width; wrapMode: Text.WordWrap; opacity: 0.75; text: "O alarme toca mesmo com o Relógio fechado: o Matsu guarda cada alarme e avisa na hora, com som." }
            }
            Sanfona {
                titulo: "Dá para usar sem internet?"
                Texto { width: parent.width; wrapMode: Text.WordWrap; text: "Sim." }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            Vazio {
                anchors.centerIn: parent
                icone: "matsu-pasta-symbolic"
                titulo: "Nenhuma música"
                texto: "Ponha músicas na pasta Música."
            }
        }
    }

    Dialogo { id: dialogo }
    MenuMatsu {
        id: menu
        itens: [{ id: "a", nome: "Abrir", icone: "matsu-pasta-symbolic", atalho: "Ctrl+O" }, { id: "b", nome: "Renomear", icone: "matsu-texto-symbolic" }, { id: "c", nome: "Apagar", icone: "matsu-lixeira-symbolic", perigo: true, separador: true }]
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (p) => menu.abrirEm(pagina, p.position.x, p.position.y)
    }
    Component.onCompleted: if (matsu.argumentos.indexOf("--aviso") >= 0) janela.avisoRapido("Alarme criado para 07:30", "certo", "Desfazer", function () {})
}
