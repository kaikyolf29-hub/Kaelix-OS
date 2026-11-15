# Ícones próprios do Matsu

`gerar.js` desenha os ícones dos apps do Matsu e grava em SVG. Cada app do
Matsu tem um arquivo em `apps/` (Arquivos, Loja, Central de jogos, Gerenciador
de tarefas, Ajustes, Terminal, Notas, Calendário, Relógio, Música, Fotos,
Câmera, Calculadora, Bloco de notas, Central de segurança, Atualizações,
Boas-vindas e as duas Lixeiras); no próprio `gerar.js` ficam os apps do KDE que
o Matsu cobre (Configurações do sistema, Monitor, Kate, Capturas, Gwenview).

A família de 15/11/2026 saiu dos desenhos que o Kaiky gerou no Google
Antigravity a partir de um pedido com as regras da família, redesenhados aqui:
quadrado arredondado com o degradê do app, brilho de vidro na metade de cima,
desenho branco do Matsu (`#F4F6FF`) de traço grosso e um detalhe rosa de
cerejeira (`#F0A6CC`). Os desenhos usam a grade de 1024 dos originais (`grade()`
encaixa no quadrado de 256 do tema).

Cada app tem duas versões:

- `apps/scalable/matsu-<app>.svg`: a normal, de 25 px para cima (barra, doca, menu);
- `apps/pequeno/matsu-<app>.svg`: de 16 a 24 px (lista do Gerenciador de tarefas,
  avisos, buscas), com o desenho maior e sem os detalhes que viram borrão. O
  `index.theme` lista `apps/pequeno` antes de `apps/scalable` (o KDE e o Qt
  pegam a primeira pasta que serve no tamanho pedido).

Para refazer depois de mudar um desenho (a segunda pasta recebe a cópia dos
ícones `org.matsu.*`, para quem trocar o tema de ícones):

    node visual/icones/gerar.js system_files/usr/share/icons/Matsu/apps/scalable system_files/usr/share/icons/hicolor/scalable/apps

e copie os que aparecem no site para `site/public/icones/<app>.svg` (o teste
`tests/test_icones.sh` confere que estão iguais).

O tema claro (`Matsu-claro`) usa os mesmos arquivos. Programas de outras marcas
(Steam, navegador, VS Code) continuam com o ícone original deles.

## Ícones das Configurações e dos apps do KDE

`ajustes.js` desenha os ícones no jeito da lista dos Ajustes do Matsu (quadrado
colorido com desenho branco, como no Mac) para todas as páginas das
Configurações do sistema e para os apps do KDE que vinham com ícone genérico
(Ark, Firewall, Centro de ajuda, Carteira, KDE Connect...). Para refazer:

    node visual/icones/gerar.js system_files/usr/share/icons/Matsu/apps/scalable system_files/usr/share/icons/hicolor/scalable/apps
    node visual/icones/ajustes.js system_files/usr/share/icons/Matsu system_files/usr/share/icons/Matsu-claro

O tema claro usa a pasta `apps` do escuro (é uma ligação). Os nomes de ícone de
cada página e de cada app vêm do inventário da imagem: `tests/vm/inventario.sh`,
que roda no GitHub quando a mensagem do commit tem `[inventario]`.

Cuidados (conferidos por `tests/test_icones.sh`):

- Nome que também é ícone de ação do KDE (`system-run`, `tools-check-spelling`,
  `lighttable`) fica na pasta `ajustes/scalable`, que só vale de 20 px para
  cima. No tamanho de menu (16 px) a pasta `actions/16` aponta para o original
  do Breeze, que é o certo no menu dos apps.
- Nomes de aparelho e de estado (`input-keyboard`, `drive-removable-media`,
  `battery`, `system-log-out`...) não entram: trocar mudaria o pendrive no
  Arquivos, o teclado no Bluetooth e o "Sair" na tela de sair.
- O visualizador de falhas e as configurações do KDebug pedem ícone de ação
  (`tools-report-bug`, `debug-run`, que aparecem no menu Ajuda de todo app):
  o `build.sh` troca o ícone direto no `.desktop` deles.
- Programas de outras marcas (Steam, Firefox, VS Code, CoreCtrl, htop, nvtop e
  os Flatpak) ficam com a logo oficial deles.
