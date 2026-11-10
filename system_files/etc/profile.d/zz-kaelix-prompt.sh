# shellcheck shell=sh
# Kaelix OS: o jeito do terminal, como no vídeo de demonstração:
#   kaiky@kaelix ~ $
# usuário@máquina em amarelo e a pasta mais apagada. Fica por último (zz-) para
# valer sobre o prompt padrão do Fedora. Quem quiser outro, muda PS1 no ~/.bashrc.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  PS1='\[\e[33m\]\u@\h\[\e[0m\] \[\e[2m\]\w\[\e[0m\] \$ '
fi
