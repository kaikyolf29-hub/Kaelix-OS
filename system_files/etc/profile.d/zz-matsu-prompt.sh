# shellcheck shell=sh
# Matsu OS: o prompt do terminal.
#
#   ~/projetos/site main* ❯
#
# A pasta em verde-água, o ramo do git em lilás (com * quando tem mudança) e a
# setinha verde, que fica vermelha quando o último comando deu erro. Em conexão
# por SSH aparece também usuario@máquina, para saber que não é o seu computador,
# e como root aparece "root" em vermelho.
#
# Fica por último (zz-) para valer sobre o prompt padrão do Fedora. Quem quiser
# outro, muda PS1 no ~/.bashrc: aqui só se mexe em variáveis, nunca no PS1 de novo.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  # Os pedaços invisíveis (cores) vão entre \001 e \002 para o bash saber o
  # tamanho do prompt. No console de texto puro não tem a setinha: vira ">".
  if [ "${TERM}" = linux ]; then
    _matsu_simbolo='>'
  else
    _matsu_simbolo="$(printf '\342\235\257')"
  fi
  _matsu_seta_ok="$(printf '\001\033[1;32m\002%s\001\033[0m\002' "$_matsu_simbolo")"
  _matsu_seta_erro="$(printf '\001\033[1;31m\002%s\001\033[0m\002' "$_matsu_simbolo")"
  _matsu_seta="$_matsu_seta_ok"
  _matsu_ramo=""
  _matsu_sujo=""

  # Roda antes de cada prompt. Guarda o resultado do último comando primeiro,
  # antes de qualquer outra coisa mudar o $?. O nome do ramo fica numa variável
  # (o PS1 só aponta para ela): assim um ramo com nome estranho nunca vira comando.
  _matsu_prompt() {
    _matsu_status=$?
    if [ "$_matsu_status" -eq 0 ]; then
      _matsu_seta="$_matsu_seta_ok"
    else
      _matsu_seta="$_matsu_seta_erro"
    fi
    _matsu_ramo=""
    _matsu_sujo=""
    if command -v git >/dev/null 2>&1; then
      _matsu_ramo="$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
      if [ -n "$_matsu_ramo" ]; then
        git diff --no-ext-diff --quiet HEAD -- 2>/dev/null || _matsu_sujo="*"
        _matsu_ramo=" $_matsu_ramo"
      fi
    fi
    return "$_matsu_status"
  }
  case "${PROMPT_COMMAND:-}" in
    *_matsu_prompt*) ;;
    "") PROMPT_COMMAND=_matsu_prompt ;;
    *) PROMPT_COMMAND="_matsu_prompt;${PROMPT_COMMAND}" ;;
  esac

  _matsu_quem=''
  if [ "$(id -u)" = 0 ]; then
    _matsu_quem='\[\e[1;31m\]root\[\e[0m\] '
  elif [ -n "${SSH_CONNECTION:-}" ]; then
    _matsu_quem='\[\e[33m\]\u@\h\[\e[0m\] '
  fi
  # shellcheck disable=SC2016 # as variáveis são lidas a cada prompt, não agora
  PS1="${_matsu_quem}"'\[\e[1;36m\]\w\[\e[0m\]\[\e[35m\]${_matsu_ramo}\[\e[33m\]${_matsu_sujo}\[\e[0m\] ${_matsu_seta} '
  unset _matsu_quem
fi
