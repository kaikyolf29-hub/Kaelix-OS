import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../system_files/usr/share/matsu/comum"

QQC2.ScrollView {
    id: pagina
    contentWidth: availableWidth
    contentHeight: grade.implicitHeight + janela.gu * 2.4
    QQC2.ScrollBar.vertical: BarraRolagem {}

    GridLayout {
        id: grade
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

        // ----- cartão que se clica (sobe com sombra) e gráfico suave (curva que desliza) -----
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                spacing: janela.gu * 0.5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: janela.gu * 0.5
                    Repeater {
                        model: [{ n: "Música", i: "matsu-volume-2-symbolic" }, { n: "Fotos", i: "matsu-papel-symbolic" }]
                        CartaoClicavel {
                            id: atalho
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: janela.gu * 2.4
                            onClicked: janela.avisoRapido("Abriu " + modelData.n, "certo")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: janela.gu * 0.6
                                spacing: janela.gu * 0.4
                                Kirigami.Icon { implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth; source: atalho.modelData.i; isMask: true; color: janela.frente }
                                Texto { Layout.fillWidth: true; text: atalho.modelData.n }
                            }
                        }
                    }
                }
                Grafico {
                    id: graficoDemo
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    suave: true
                    cor: "#5ec4a8"
                    pontos: 30
                    property var serie: [30, 42, 38, 55, 61, 48, 52, 70, 66, 58, 63, 49, 44, 57, 72, 80, 68, 60]
                    valores: serie
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            var s = graficoDemo.serie.slice(-29);
                            s.push(Math.max(5, Math.min(95, s[s.length - 1] + (Math.random() - 0.5) * 30)));
                            graficoDemo.serie = s;
                            graficoDemo.tique++;
                        }
                    }
                }
            }
        }

        // ----- peças novas: carregando, botões de ícone, abas, número que ganha casas -----
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                spacing: janela.gu * 0.5
                RowLayout {
                    spacing: janela.gu * 0.6
                    Esqueleto { Layout.preferredWidth: janela.gu * 2.6; Layout.preferredHeight: width; raio: width / 2 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: janela.gu * 0.35
                        Esqueleto { Layout.preferredWidth: janela.gu * 8; Layout.preferredHeight: janela.gu * 0.8 }
                        Esqueleto { Layout.preferredWidth: janela.gu * 5; Layout.preferredHeight: janela.gu * 0.6 }
                    }
                }
                Esqueleto { Layout.fillWidth: true; Layout.fillHeight: true; raio: janela.gu * 0.6 }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.preferredHeight: janela.gu * 9
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: janela.gu
                spacing: janela.gu * 0.5
                Texto { text: "Pedidos hoje"; opacity: 0.6 }
                NumeroRolante {
                    texto: janela.num(janela.contas[janela.conta])
                    font.pixelSize: janela.gu * 2.2
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
                RowLayout {
                    spacing: janela.gu * 0.2
                    BotaoSimbolo { icone: "matsu-busca-symbolic"; dica: "Localizar" }
                    BotaoSimbolo { icone: "matsu-texto-symbolic"; dica: "Negrito"; ligado: janela.negrito; onClicado: janela.negrito = !janela.negrito }
                    BotaoSimbolo { icone: "matsu-etiqueta-symbolic"; dica: "Cor"; pingo: "#f2c861" }
                    BotaoSimbolo { icone: "matsu-seta-symbolic"; dica: "Mais"; redondo: true; giro: janela.negrito ? 90 : 0 }
                }
                RowLayout {
                    spacing: janela.gu * 0.3
                    BotaoCirculo { icone: "matsu-relogio-symbolic"; dica: "Temporizador"; ligado: janela.temporizador > 0; selo: janela.temporizador > 0 ? String(janela.temporizador) : ""; onClicado: janela.temporizador = (janela.temporizador + 3) % 12 }
                    BotaoCirculo { icone: "matsu-ajustes-symbolic"; dica: "Ajustes" }
                    BotaoCoracao { ligado: janela.favorita; onClicado: janela.favorita = !janela.favorita }
                }
            }
        }
        Cartao {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            Layout.columnSpan: 2
            Layout.preferredHeight: janela.gu * 9
            clip: true
            ListModel {
                id: abas
                ListElement { nome: "compras.txt"; dica: "~/Documentos/compras.txt"; modificado: false }
                ListElement { nome: "ideias.md"; dica: "~/Documentos/ideias.md"; modificado: true }
                ListElement { nome: "Sem título"; dica: ""; modificado: false }
            }
            FaixaAbas {
                id: faixaAbas
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                modelo: abas
                atual: janela.atualAba
                corFolha: janela.escuro ? Qt.rgba(1, 1, 1, 0.045) : "#ffffff"
                onEscolher: (i) => janela.atualAba = i
                onFechar: (i) => { abas.remove(i); janela.atualAba = Math.min(janela.atualAba, abas.count - 1); }
                onMover: (de, para) => { abas.move(de, para, 1); janela.atualAba = para; }
                onNova: { abas.append({ nome: "Sem título", dica: "", modificado: false }); janela.atualAba = abas.count - 1; }
            }
            Rectangle {
                anchors.top: faixaAbas.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                color: faixaAbas.corFolha
                bottomLeftRadius: parent.radius - 1
                bottomRightRadius: parent.radius - 1
                Texto {
                    anchors.fill: parent
                    anchors.margins: janela.gu * 0.8
                    text: abas.count > 0 && janela.atualAba >= 0 ? "Texto de " + abas.get(janela.atualAba).nome : ""
                    opacity: 0.6
                    font.family: "monospace"
                }
            }
        }
        LinhaEscolha {
            Layout.fillWidth: true
            Layout.preferredWidth: janela.gu * 12
            icone: "matsu-relogio-symbolic"
            nome: "Fuso horário"
            texto: "Lista comprida: abre para o lado que cabe e rola."
            Suspensa {
                Layout.fillWidth: true
                readonly property var fusos: ["America/Noronha", "America/Belem", "America/Fortaleza", "America/Recife", "America/Araguaina",
                    "America/Maceio", "America/Bahia", "America/Sao_Paulo", "America/Campo_Grande", "America/Cuiaba", "America/Santarem",
                    "America/Porto_Velho", "America/Boa_Vista", "America/Manaus", "America/Eirunepe", "America/Rio_Branco",
                    "America/Argentina/Buenos_Aires", "America/Montevideo", "America/Asuncion", "America/Santiago", "America/Lima",
                    "America/Bogota", "America/Caracas", "America/Mexico_City", "America/New_York", "Europe/Lisbon", "Europe/London",
                    "Europe/Madrid", "Europe/Paris", "Europe/Berlin", "Africa/Luanda", "Africa/Maputo", "Asia/Tokyo"]
                opcoes: fusos.map((f) => ({ id: f, nome: f.split("/").pop().replace(/_/g, " ") }))
                escolhido: janela.fuso
                onEscolher: (id) => janela.fuso = id
            }
        }
    }

    Dialogo { id: dialogo }
    MenuMatsu {
        id: menu
        onEscolhido: (id) => janela.avisoRapido("Escolheu: " + id, "certo")
        itens: [{ id: "a", nome: "Abrir", icone: "matsu-pasta-symbolic", atalho: "Ctrl+O" }, { id: "b", nome: "Renomear", icone: "matsu-texto-symbolic" }, { id: "x", nome: "Compartilhar", icone: "matsu-link-symbolic", ativo: false }, { id: "c", nome: "Apagar", icone: "matsu-lixeira-symbolic", perigo: true, separador: true }]
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (p) => menu.abrirEm(pagina, p.position.x, p.position.y)
    }
    Component.onCompleted: if (matsu.argumentos.indexOf("--aviso") >= 0) janela.avisoRapido("Alarme criado para 07:30", "certo", "Desfazer", function () {})
}
