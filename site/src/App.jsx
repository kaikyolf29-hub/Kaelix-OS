import Navegacao, { BarraCelular } from './componentes/Navegacao.jsx';
import Topo from './componentes/Topo.jsx';
import Telas from './componentes/Telas.jsx';
import { Aparencia, Criar, Jogos, Loja, Seguranca } from './componentes/Divisoes.jsx';
import Atalhos from './componentes/Atalhos.jsx';
import Estilos from './componentes/Estilos.jsx';
import Apps from './componentes/Apps.jsx';
import Instalar from './componentes/Instalar.jsx';
import Baixar from './componentes/Baixar.jsx';
import Apoiar from './componentes/Apoiar.jsx';
import Perguntas from './componentes/Perguntas.jsx';
import Rodape from './componentes/Rodape.jsx';
import './reactbits/GlassSurface.css';
import './reactbits/SpotlightCard.css';
import './estilo/base.css';
import './estilo/transicoes.css';
import './estilo/secoes.css';

// Uma página só, uma parte por tela: o topo (a área de trabalho), o sistema, os
// atalhos, os jogos, a barra, a aparência, a loja, os apps, programar e criar, a
// segurança, a instalação, baixar, as perguntas, apoiar (quando tem um jeito de
// apoiar) e o fim.
// O index.html já tem o header, o main, o footer e a barra do celular; cada um
// é uma raiz do React, para a página ser só essas quatro partes.
function Conteudo() {
  return (
    <>
      <Topo />
      <Telas />
      <Atalhos />
      <Jogos />
      <Estilos />
      <Aparencia />
      <Loja />
      <Apps />
      <Criar />
      <Seguranca />
      <Instalar />
      <Baixar />
      <Perguntas />
      <Apoiar />
    </>
  );
}

export const RAIZES = {
  'raiz-nav': Navegacao,
  conteudo: Conteudo,
  'raiz-rodape': Rodape,
  'raiz-celular': BarraCelular
};
