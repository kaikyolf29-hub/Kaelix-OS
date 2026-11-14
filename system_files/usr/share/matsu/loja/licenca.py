"""Licença da Loja do Matsu, para apps pagos feitos em Python.

Copie este arquivo para dentro do seu app (só usa a biblioteca padrão do Python,
funciona dentro do Flatpak) e chame:

    from matsu_licenca import conferir, abrir_loja

    estado = conferir("org.exemplo.MeuApp")
    if not estado.valida:
        print(estado.mensagem)          # "Este app ainda não foi liberado..."
        abrir_loja("org.exemplo.MeuApp")  # abre a Loja na tela de resgatar o código
        raise SystemExit(1)
    print("Liberado", "para sempre" if not estado.expira else f"até {estado.expira}")

Como funciona: quando a pessoa resgata o código na Loja do Matsu, a Loja guarda
um arquivo de licença assinado pelo servidor da Loja (Ed25519). Este módulo
confere a assinatura com a chave pública abaixo, sem internet, e confere se a
licença é deste app, deste computador e se ainda está no prazo.
"""
import base64
import datetime
import hashlib
import json
import os
import subprocess
import time

# A chave pública da Loja do Matsu (32 bytes em base64). Pode haver mais de uma
# (troca de chave no futuro): vale a assinatura de qualquer uma.
CHAVES_PUBLICAS = [
    "UAB0M5942punutDAPzeJyGPTLEnfZ3xymCNUWpJXA5U=",
]

__all__ = ["conferir", "abrir_loja", "Estado", "computador"]


# --------------------------------------------------------------- Ed25519 (RFC 8032)
# Conferência pura em Python (sem depender de nada instalado).
_P = 2 ** 255 - 19
_L = 2 ** 252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, _P - 2, _P) % _P
_I = pow(2, (_P - 1) // 4, _P)


def _x_de(y, sinal):
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, _P - 2, _P) % _P
    if x2 == 0:
        return None if sinal else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P:
        x = x * _I % _P
    if (x * x - x2) % _P:
        return None
    if (x & 1) != sinal:
        x = _P - x
    return x


_GY = 4 * pow(5, _P - 2, _P) % _P
_GX = _x_de(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)


def _soma(a, b):
    p_ = _P
    a_ = (a[1] - a[0]) * (b[1] - b[0]) % p_
    b_ = (a[1] + a[0]) * (b[1] + b[0]) % p_
    c_ = 2 * a[3] * b[3] * _D % p_
    d_ = 2 * a[2] * b[2] % p_
    e, f, g, h = b_ - a_, d_ - c_, d_ + c_, b_ + a_
    return (e * f % p_, g * h % p_, f * g % p_, e * h % p_)


def _vezes(n, ponto):
    q = (0, 1, 1, 0)
    while n:
        if n & 1:
            q = _soma(q, ponto)
        ponto = _soma(ponto, ponto)
        n >>= 1
    return q


def _iguais(a, b):
    return (a[0] * b[2] - b[0] * a[2]) % _P == 0 and (a[1] * b[2] - b[1] * a[2]) % _P == 0


def _ponto(b):
    if len(b) != 32:
        return None
    y = int.from_bytes(b, "little")
    sinal = y >> 255
    y &= (1 << 255) - 1
    x = _x_de(y, sinal)
    return None if x is None else (x, y, 1, x * y % _P)


def ed25519_confere(publica, mensagem, assinatura):
    """True se a assinatura (64 bytes) da mensagem vale para a chave pública (32 bytes)."""
    if len(publica) != 32 or len(assinatura) != 64:
        return False
    a = _ponto(publica)
    r = _ponto(assinatura[:32])
    if a is None or r is None:
        return False
    s = int.from_bytes(assinatura[32:], "little")
    if s >= _L:
        return False
    h = int.from_bytes(hashlib.sha512(assinatura[:32] + publica + mensagem).digest(), "little") % _L
    return _iguais(_vezes(s, _G), _soma(r, _vezes(h, a)))


# --------------------------------------------------------------- a licença
class Estado:
    """O resultado de conferir(): valida, motivo, mensagem, expira (datetime ou None), plano."""

    def __init__(self, valida, motivo, dados=None):
        self.valida = valida
        self.motivo = motivo  # "ok", "sem-licenca", "assinatura", "outro-app", "outro-computador", "vencida"
        self.dados = dados or {}
        exp = int(self.dados.get("expira") or 0)
        self.expira = datetime.datetime.fromtimestamp(exp) if exp else None
        self.plano = self.dados.get("plano", "")

    @property
    def mensagem(self):
        return {
            "ok": "Liberado.",
            "sem-licenca": "Este app ainda não foi liberado neste computador. Resgate o seu código na Loja do Matsu.",
            "assinatura": "A licença deste app não é válida. Resgate o código de novo na Loja do Matsu.",
            "outro-app": "A licença encontrada é de outro app. Resgate o código deste app na Loja do Matsu.",
            "outro-computador": "A licença é de outro computador. Resgate o código de novo na Loja do Matsu.",
            "vencida": "O prazo da sua licença acabou. Resgate um código novo na Loja do Matsu.",
        }.get(self.motivo, self.motivo)

    def __bool__(self):
        return self.valida

    def __repr__(self):
        return f"Estado(valida={self.valida}, motivo={self.motivo!r}, expira={self.expira})"


def computador():
    """O resumo deste computador que vai na licença (o identificador em si nunca sai do PC)."""
    for caminho in ("/etc/machine-id", "/var/lib/dbus/machine-id"):
        try:
            with open(caminho, encoding="ascii") as f:
                ident = f.read().strip()
            if ident:
                return hashlib.sha256(("matsu-loja:" + ident).encode()).hexdigest()
        except OSError:
            continue
    return ""


def _arquivos(app_id):
    casa = os.path.expanduser("~")
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(casa, ".config")
    return [
        os.path.join(config, "matsu", "licencas", app_id + ".json"),
        os.path.join(casa, ".config", "matsu", "licencas", app_id + ".json"),
        os.path.join(casa, ".var", "app", app_id, "config", "matsu", "licencas", app_id + ".json"),
    ]


def ler_licenca(conteudo, app_id, agora=None):
    """Confere o conteúdo (dict ou texto JSON) de um arquivo de licença."""
    try:
        if isinstance(conteudo, (str, bytes)):
            conteudo = json.loads(conteudo)
        dados_b = base64.b64decode(conteudo["dados"])
        assinatura = base64.b64decode(conteudo["assinatura"])
    except (ValueError, KeyError, TypeError):
        return Estado(False, "assinatura")
    if not any(ed25519_confere(base64.b64decode(k), dados_b, assinatura) for k in CHAVES_PUBLICAS if len(k) == 44):
        return Estado(False, "assinatura")
    try:
        dados = json.loads(dados_b.decode("utf-8"))
    except ValueError:
        return Estado(False, "assinatura")
    if dados.get("app") != app_id:
        return Estado(False, "outro-app", dados)
    if dados.get("computador") != computador():
        return Estado(False, "outro-computador", dados)
    expira = int(dados.get("expira") or 0)
    if expira and expira < (agora or time.time()):
        return Estado(False, "vencida", dados)
    return Estado(True, "ok", dados)


def conferir(app_id):
    """Procura a licença do app neste computador e diz se ele está liberado."""
    melhor = Estado(False, "sem-licenca")
    for caminho in _arquivos(app_id):
        try:
            with open(caminho, encoding="utf-8") as f:
                estado = ler_licenca(f.read(), app_id)
        except OSError:
            continue
        if estado.valida:
            return estado
        melhor = estado
    return melhor


def abrir_loja(app_id):
    """Abre a Loja do Matsu na tela de resgatar o código deste app."""
    endereco = "matsu-loja://resgatar/" + app_id
    for comando in (["xdg-open", endereco], ["gio", "open", endereco]):
        try:
            subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except OSError:
            continue
    return False


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Uso: python3 matsu_licenca.py <id-do-app>")
        raise SystemExit(2)
    e = conferir(sys.argv[1])
    print(e.mensagem if not e.valida else ("Liberado para sempre." if not e.expira else f"Liberado até {e.expira:%d/%m/%Y}."))
    raise SystemExit(0 if e.valida else 1)
