// Matsu OS: quando as telas mudam (um monitor ligado ou desligado), pede ao
// serviço matsu-telas para pôr a barra nas telas que ficaram sem nenhuma.
// Quem decide e monta é "matsu barra --telas-novas"; aqui só avisa.
function pedirBarras() {
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
             "org.freedesktop.systemd1.Manager", "StartUnit",
             "matsu-telas.service", "replace");
}

workspace.screensChanged.connect(pedirBarras);
