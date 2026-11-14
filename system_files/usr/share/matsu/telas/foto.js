.pragma library
// A foto da pessoa só quando é uma foto dela de verdade (usado pela Pessoa.qml).
//
// Quando a pessoa não escolheu foto, o KDE às vezes manda um rosto genérico no
// lugar: o ".face.icon" que vem dentro do programa da tela de login (qrc:) ou um
// ícone do sistema em /usr. Nesses casos o Matsu mostra a primeira letra do nome,
// igual em todas as telas. As fotos escolhidas ficam na pasta da pessoa
// (~/.face.icon) ou no AccountsService (/var/lib/AccountsService/icons), nunca em /usr.
function deVerdade(caminho) {
    var c = String(caminho || "");
    if (c === "" || c.indexOf("qrc:") === 0 || c.indexOf(":/") === 0 || c.indexOf("image://") === 0)
        return "";
    var arquivo = c.indexOf("file://") === 0 ? decodeURIComponent(c.substring(7)) : c;
    if (arquivo.indexOf("/usr/") === 0)
        return "";
    return c;
}
