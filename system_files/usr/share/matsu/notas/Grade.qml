// As notas em grade de cartões (como no Google Keep): as fixadas em cima, as
// outras embaixo. O número de colunas acompanha a largura da janela.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Flickable {
    id: grade

    property var modelo: null
    property bool agrupar: false

    signal abrir(string nid)
    signal pedirMenu(string nid, Item item, real px, real py)

    readonly property int vao: Math.round(janela.gu * 0.75)
    readonly property int margem: Math.round(janela.gu * 1.1)
    readonly property int colunas: Math.max(1, Math.floor((width - 2 * margem + vao) / (janela.gu * 12.5 + vao)))
    readonly property real largura: Math.floor((width - 2 * margem - (colunas - 1) * vao) / colunas)
    readonly property real altura: Math.round(janela.gu * 10.5)

    clip: true
    contentWidth: width
    contentHeight: coluna.height + margem
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: BarraRolagem {}

    Column {
        id: coluna
        x: grade.margem
        y: Math.round(janela.gu * 0.2)
        width: grade.width - 2 * grade.margem
        spacing: Math.round(janela.gu * 0.5)

        Repeater {
            model: grade.agrupar ? ["fixadas", "outras"] : [""]

            Column {
                id: bloco
                required property string modelData
                width: coluna.width
                spacing: Math.round(janela.gu * 0.45)
                visible: fluxo.temAlgum

                Texto {
                    visible: bloco.modelData !== ""
                    text: bloco.modelData === "fixadas" ? janela.t("Fixadas", "Pinned") : janela.t("Outras notas", "Other notes")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    opacity: 0.55
                    topPadding: Math.round(janela.gu * 0.3)
                }
                Flow {
                    id: fluxo
                    property bool temAlgum: {
                        grade.modelo.count;
                        for (var i = 0; i < grade.modelo.count; i++)
                            if (bloco.modelData === "" || grade.modelo.get(i).grupo === bloco.modelData)
                                return true;
                        return false;
                    }
                    width: coluna.width
                    spacing: grade.vao
                    move: Transition {
                        NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    }
                    Repeater {
                        model: grade.modelo
                        CartaoNota {
                            id: cartaoGrade
                            visible: bloco.modelData === "" || grupo === bloco.modelData
                            width: grade.largura
                            height: grade.altura
                            escolhido: janela.selecionada === nid
                            onAbrir: grade.abrir(nid)
                            onPedirMenu: (px, py) => grade.pedirMenu(nid, cartaoGrade, px, py)
                        }
                    }
                }
            }
        }
    }
}
