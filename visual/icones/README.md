# Ícones próprios do Matsu

`gerar.js` desenha os ícones dos apps do sistema (Arquivos, Terminal, Loja,
Monitor, Configurações, Editor de texto, Capturas e Imagens) e grava em SVG.

Para refazer depois de mudar um desenho:

    node visual/icones/gerar.js system_files/usr/share/icons/Matsu/apps/scalable

O tema claro (`Matsu-claro`) usa os mesmos arquivos. Programas de outras marcas
(Steam, navegador, VS Code) continuam com o ícone original deles.

## Ícones das Configurações e dos apps do KDE

`ajustes.js` desenha os ícones no jeito da lista dos Ajustes do Matsu (quadrado
colorido com desenho branco, como no Mac) para todas as páginas das
Configurações do sistema e para os apps do KDE que vinham com ícone genérico
(Ark, Firewall, Centro de ajuda, Carteira, KDE Connect...). Para refazer:

    node visual/icones/gerar.js system_files/usr/share/icons/Matsu/apps/scalable
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
