// Todas as fotos, as favoritas e as capturas de tela: a mesma grade por mês, com a
// lista de cada página (e a busca pelo nome, que vale para a página aberta).
import QtQuick
import "../comum"

Item {
    id: pagina

    readonly property string tipo: janela.pagina
    readonly property bool buscando: janela.busca.trim().length > 0
    readonly property var base: {
        if (tipo === "favoritas") {
            var fav = janela.favoritas;
            return janela.fotos.filter(function (f) { return fav[f.caminho] === true; });
        }
        if (tipo === "capturas")
            return janela.fotos.filter(function (f) { return f.captura; });
        return janela.fotos;
    }
    readonly property var lista: janela.busca2(base)

    GradeFotos {
        anchors.fill: parent
        fotos: pagina.lista
        chave: pagina.tipo + "|" + janela.busca
        titulo: pagina.buscando ? janela.t("Resultados para “" + janela.busca.trim() + "”", "Results for “" + janela.busca.trim() + "”")
                                : ({ favoritas: janela.t("Favoritas", "Favorites"), capturas: janela.t("Capturas de tela", "Screenshots") })[pagina.tipo]
                                  || janela.t("Todas as fotos", "All photos")
        detalhe: pagina.lista.length === 0 ? "" : janela.quantas(pagina.lista.length) + " · " + janela.periodo(pagina.lista)
        vazioIcone: pagina.buscando ? "matsu-busca-symbolic"
                    : (pagina.tipo === "favoritas" ? "matsu-coracao-symbolic" : (pagina.tipo === "capturas" ? String(Qt.resolvedUrl("icones/captura.svg")) : String(Qt.resolvedUrl("icones/fotos.svg"))))
        vazioTitulo: {
            if (pagina.buscando)
                return janela.t("Nada encontrado", "Nothing found");
            if (pagina.tipo === "favoritas")
                return janela.t("Nenhuma favorita ainda", "No favorites yet");
            if (pagina.tipo === "capturas")
                return janela.t("Nenhuma captura de tela", "No screenshots");
            return janela.existePasta ? janela.t("Nenhuma foto por aqui", "No photos here") : janela.t("A pasta Imagens não existe", "The Pictures folder doesn't exist");
        }
        vazioTexto: {
            if (pagina.buscando)
                return janela.t("Nenhuma foto com “" + janela.busca.trim() + "” no nome.", "No photo with “" + janela.busca.trim() + "” in its name.");
            if (pagina.tipo === "favoritas")
                return janela.t("Toque no coração de uma foto para guardar aqui as que você mais gosta.", "Tap the heart on a photo to keep your best ones here.");
            if (pagina.tipo === "capturas")
                return janela.t("Aperte Print Screen para tirar uma. Elas ficam em Imagens › Capturas de tela.", "Press Print Screen to take one. They're saved in Pictures › Screenshots.");
            return janela.t("As fotos da pasta Imagens aparecem aqui, separadas por mês. Copie suas fotos para lá e elas surgem sozinhas.",
                            "Photos in your Pictures folder show up here, by month. Copy your photos there and they appear on their own.");
        }
        vazioBotao: !pagina.buscando && pagina.tipo === "todas" && janela.existePasta && janela.raiz !== "" ? janela.t("Abrir a pasta Imagens", "Open the Pictures folder") : ""
        onVazioClicado: janela.abrirPasta(janela.raiz)
    }
}
