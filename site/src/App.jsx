import Navegacao, { BarraCelular } from './componentes/Navegacao.jsx';
import Topo from './componentes/Topo.jsx';
import Telas from './componentes/Telas.jsx';
import { Jogos, Loja, Seguranca } from './componentes/Divisoes.jsx';
import Estilos from './componentes/Estilos.jsx';
import Apps from './componentes/Apps.jsx';
import Instalar from './componentes/Instalar.jsx';
import Baixar from './componentes/Baixar.jsx';
import Rodape from './componentes/Rodape.jsx';
import './reactbits/GlassSurface.css';
import './reactbits/SpotlightCard.css';
import './estilo/base.css';
import './estilo/transicoes.css';
import './estilo/secoes.css';

// Uma página só, uma parte por tela: o topo (a área de trabalho), o sistema, os
// jogos, a barra, a loja, os apps, a segurança, a instalação, baixar e o fim.
// O index.html já tem o header, o main, o footer e a barra do celular; cada um
// é uma raiz do React, para a página ser só essas quatro partes.
function Conteudo() {
  return (
    <>
      <Topo />
      <Telas />
      <Jogos />
      <Estilos />
      <Loja />
      <Apps />
      <Seguranca />
      <Instalar />
      <Baixar />
    </>
  );
}

export const RAIZES = {
  'raiz-nav': Navegacao,
  conteudo: Conteudo,
  'raiz-rodape': Rodape,
  'raiz-celular': BarraCelular
};
