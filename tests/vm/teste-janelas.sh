#!/usr/bin/bash
# Teste da máquina virtual: lista as janelas que o KWin conhece (nome, programa,
# posição, tamanho e se aparecem), para achar janela invisível no meio da tela.
# O KWin põe uma janela nova em cascata quando ela cobriria outra por inteiro.
marca="JANELAS$$"
js="$(mktemp --suffix=.js)"
cat > "$js" <<JS
const linhas = [];
for (const w of workspace.windowList()) {
  const g = w.frameGeometry;
  linhas.push([w.resourceClass, '"' + w.caption + '"', Math.round(g.x) + "," + Math.round(g.y),
    Math.round(g.width) + "x" + Math.round(g.height), w.normalWindow ? "normal" : "outra",
    w.minimized ? "minimizada" : "", w.hidden ? "escondida" : "", "opacidade " + w.opacity].join(" "));
}
print("$marca" + linhas.join(" ## "));
JS
dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
  "string:$js" "string:janelas$$" >/dev/null
dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 1
journalctl --user -b --since "-20s" -o cat | grep -a "$marca" | tail -n1 | sed "s/.*$marca//; s/ ## /\n/g"
dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
  "string:janelas$$" >/dev/null 2>&1
rm -f "$js"
