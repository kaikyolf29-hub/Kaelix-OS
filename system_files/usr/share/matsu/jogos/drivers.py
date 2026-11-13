"""Central de jogos do Matsu: os drivers de vídeo (AMD, Intel e NVIDIA).

Carregado pelo ajudante.py. Lê, sem pedir senha:
  - cada placa de vídeo (também as duas de um notebook) e o driver em uso
    (amdgpu, i915, xe, nvidia, nouveau, radeon);
  - o Mesa, o Vulkan (versão da API e do driver, pelo vulkaninfo; sem ele, pelos
    arquivos ICD em /usr/share/vulkan/icd.d), o OpenGL (glxinfo, se tiver), o
    driver da NVIDIA (/proc/driver/nvidia/version ou nvidia-smi) e o kernel;
  - se o Vulkan de 32 bits está lá (jogos antigos e muitos jogos do Proton);
  - se o Anti-Lag da AMD (VK_AMD_anti_lag) está no driver;
  - qual imagem do Matsu está instalada (matsu-os ou matsu-os-nvidia) e, se ela
    não combina com a placa, para qual trocar (o mesmo canal).

No Matsu (Fedora Atomic) o driver vem dentro da imagem do sistema: atualizar o
sistema atualiza o driver. Não há instalador de driver avulso.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import time

SYS = os.environ.get("MATSU_SYS", "/sys")
PROC = os.environ.get("MATSU_PROC", "/proc")
RAIZ = os.environ.get("MATSU_RAIZ", "")  # "/" de mentira nos testes
INFO_IMAGEM = os.environ.get("MATSU_IMAGE_INFO", "/usr/share/matsu/image-info.json")

FORNECEDORES = {"1002": "AMD", "10de": "NVIDIA", "8086": "Intel"}
# Placas de máquina virtual: Red Hat (virtio/QXL), VMware, VirtualBox e o Bochs.
FORNECEDORES_VIRTUAIS = {"1af4", "1b36", "15ad", "80ee", "1234"}
DRIVERS_VIRTUAIS = {"virtio-pci", "virtio_gpu", "virtio-gpu", "qxl", "vmwgfx", "vboxvideo", "bochs", "bochs-drm"}
NOMES_DRIVER = {
    "amdgpu": "amdgpu", "radeon": "radeon (antigo)", "i915": "i915", "xe": "xe", "nvidia": "nvidia",
    "nouveau": "nouveau (livre)", "vfio-pci": "vfio-pci", "": "",
}
DRIVER_VULKAN = {  # nome do arquivo ICD -> nome do driver Vulkan
    "radeon": "RADV (Mesa)", "intel": "ANV (Mesa)", "intel_hasvk": "HASVK (Mesa)", "nouveau": "NVK (Mesa)",
    "nvidia": "NVIDIA", "lvp": "lavapipe (sem placa)", "virtio": "Venus (máquina virtual)",
    "asahi": "Honeykrisp (Mesa)", "freedreno": "Turnip (Mesa)", "panfrost": "PanVK (Mesa)",
}
ICDS_DE_PC = {"radeon", "intel", "intel_hasvk", "nouveau", "nvidia"}


def r(caminho):
    """O caminho dentro da raiz (nos testes, uma pasta de mentira)."""
    return RAIZ + caminho if RAIZ else caminho


def ler(caminho, padrao=""):
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return padrao


def rodar(args, tempo=10):
    if not shutil.which(args[0]):
        return None
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=tempo, env=dict(os.environ, LC_ALL="C"))
    except (OSError, subprocess.SubprocessError):
        return None
    return p.stdout if p.returncode == 0 else None


# ----- as placas -----
def placas(nome_da_placa=None, lingua="pt"):
    """[{pci, fornecedor, marca, modelo_id, nome, driver, principal}] de todas as placas de vídeo."""
    lista = []
    for pasta in sorted(glob.glob(os.path.join(SYS, "bus", "pci", "devices", "*"))):
        classe = ler(os.path.join(pasta, "class")).strip()
        if not classe.startswith("0x03"):
            continue
        f = ler(os.path.join(pasta, "vendor")).strip().replace("0x", "")
        a = ler(os.path.join(pasta, "device")).strip().replace("0x", "")
        sf = ler(os.path.join(pasta, "subsystem_vendor")).strip().replace("0x", "")
        sa = ler(os.path.join(pasta, "subsystem_device")).strip().replace("0x", "")
        ligacao = os.path.join(pasta, "driver")
        driver = os.path.basename(os.path.realpath(ligacao)) if os.path.exists(ligacao) else ""
        nome = nome_da_placa(f, a, sf, sa, lingua) if nome_da_placa else FORNECEDORES.get(f, f)
        try:
            vram = int(ler(os.path.join(pasta, "mem_info_vram_total")).strip() or 0)
        except ValueError:
            vram = 0
        lista.append({"pci": os.path.basename(pasta), "fornecedor": f, "marca": FORNECEDORES.get(f, ""),
                      "modelo_id": a, "nome": nome, "driver": driver, "vram": vram,
                      "principal": ler(os.path.join(pasta, "boot_vga")).strip() == "1"})
    # A placa da tela primeiro; num notebook, a integrada costuma ser a principal.
    lista.sort(key=lambda p: (not p["principal"], p["pci"]))
    return lista


def tipo_placa(p):
    """integrada ou dedicada, quando o Vulkan não diz: a da Intel no barramento 00 é a
    integrada (as Arc ficam fora dele); a da AMD com até 2 GiB de memória própria é a
    do processador (a parte que a BIOS separa da RAM). As de máquina virtual (virtio,
    VMware, VirtualBox, QXL) são "virtual"."""
    if p["fornecedor"] in FORNECEDORES_VIRTUAIS or p.get("driver") in DRIVERS_VIRTUAIS:
        return "virtual"
    if p["fornecedor"] == "8086":
        partes = p["pci"].split(":")
        return "integrada" if len(partes) > 1 and partes[1] == "00" else "dedicada"
    if p["fornecedor"] == "1002" and 0 < p.get("vram", 0) <= 2 * 1024 ** 3:
        return "integrada"
    return "dedicada"


def nvidia_moderna(modelo_id):
    """Turing (GTX 16 e RTX 20) ou mais nova: as que o driver aberto novo da NVIDIA aceita."""
    try:
        return int(modelo_id, 16) >= 0x1E00
    except ValueError:
        return True


# ----- Vulkan -----
def ler_vulkaninfo(texto):
    """'vulkaninfo --summary' -> {instancia, gpus: [{nome, api, driver, versao_driver, info, tipo, fornecedor}]}."""
    d = {"instancia": "", "gpus": []}
    m = re.search(r"Vulkan Instance Version:\s*([\d.]+)", texto)
    if m:
        d["instancia"] = m.group(1)
    for bloco in re.split(r"\n(?=GPU\d+:)", texto):
        if not re.match(r"GPU\d+:", bloco.strip()):
            continue
        campos = dict(re.findall(r"^\s*(\w+)\s*=\s*(.+?)\s*$", bloco, re.M))
        d["gpus"].append({
            "nome": campos.get("deviceName", ""), "api": campos.get("apiVersion", ""),
            "driver": campos.get("driverName", ""), "versao_driver": campos.get("driverVersion", ""),
            "info": campos.get("driverInfo", ""), "fornecedor": campos.get("vendorID", "").replace("0x", "").lower()[-4:],
            "tipo": {"PHYSICAL_DEVICE_TYPE_DISCRETE_GPU": "dedicada", "PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU": "integrada",
                     "PHYSICAL_DEVICE_TYPE_CPU": "processador", "PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU": "virtual"}.get(
                         campos.get("deviceType", ""), ""),
        })
    return d


def icds():
    """Os drivers Vulkan instalados, pelos arquivos ICD: [{nome, arquivo, api, bits, biblioteca, existe}]."""
    achados = []
    for pasta in ("/usr/share/vulkan/icd.d", "/etc/vulkan/icd.d"):
        for arquivo in sorted(glob.glob(os.path.join(r(pasta), "*.json"))):
            try:
                with open(arquivo, encoding="utf-8") as f:
                    icd = json.load(f).get("ICD", {})
            except (OSError, ValueError, AttributeError):
                continue
            base = os.path.basename(arquivo)
            chave = re.sub(r"_icd(\.[\w]+)?\.json$", "", base)
            bits = 32 if re.search(r"\.(i686|i386|x86)\.json$", base) else 64
            biblioteca = icd.get("library_path", "")
            existe = True
            if biblioteca.startswith("/"):
                existe = os.path.exists(r(biblioteca))
            elif chave == "nvidia":
                existe = os.path.exists(r("/usr/lib64/libGLX_nvidia.so.0"))
            achados.append({"nome": DRIVER_VULKAN.get(chave, chave), "arquivo": base, "api": icd.get("api_version", ""),
                            "bits": bits, "biblioteca": biblioteca, "existe": existe, "chave": chave})
    return achados


def vulkan32(lista_icds=None):
    """O Vulkan de 32 bits: o carregador (libvulkan.so.1 em /usr/lib) e um driver de 32 bits."""
    lista_icds = icds() if lista_icds is None else lista_icds
    carregador = os.path.exists(r("/usr/lib/libvulkan.so.1"))
    de32 = [i for i in lista_icds if i["bits"] == 32 and i["existe"]]
    # Na tela vão os drivers das placas de PC (AMD, Intel, NVIDIA); os de celular e
    # placa ARM que a Mesa também instala (Turnip, PanVK, broadcom...) só entram se
    # não houver nenhum de PC.
    drivers = (sorted({i["nome"] for i in de32 if i["chave"] in ICDS_DE_PC})
               or sorted({i["nome"] for i in de32 if i["chave"] in DRIVER_VULKAN}))
    # O ICD da NVIDIA serve aos dois tamanhos: o de 32 bits é a biblioteca em /usr/lib.
    if any(i["chave"] == "nvidia" for i in lista_icds) and os.path.exists(r("/usr/lib/libGLX_nvidia.so.0")):
        drivers.append("NVIDIA")
    return {"carregador": carregador, "drivers": drivers, "ok": carregador and bool(drivers)}


def anti_lag(texto_vulkaninfo):
    """Se algum driver Vulkan oferece o Anti-Lag da AMD (VK_AMD_anti_lag)."""
    return "VK_AMD_anti_lag" in (texto_vulkaninfo or "")


# ----- OpenGL, Mesa, NVIDIA -----
def ler_glxinfo(texto):
    d = {}
    for chave, nome in (("OpenGL renderer string", "placa"), ("OpenGL core profile version string", "nucleo"),
                        ("OpenGL version string", "versao")):
        m = re.search(re.escape(chave) + r":\s*(.+)", texto or "")
        if m:
            d[nome] = m.group(1).strip()
    versao = d.get("nucleo") or d.get("versao") or ""
    m = re.match(r"([\d.]+)", versao)
    d["api"] = m.group(1) if m else ""
    m = re.search(r"Mesa ([\d.]+\S*)", versao)
    d["mesa"] = m.group(1) if m else ""
    return d


def versao_mesa():
    for pacote in ("mesa-vulkan-drivers", "mesa-dri-drivers", "mesa-libGL"):
        # Com o de 32 e o de 64 bits instalados, o rpm responde uma linha para cada.
        saida = rodar(["rpm", "-q", "--qf", "%{VERSION}\n", pacote], 5)
        if saida and saida.strip() and "not installed" not in saida:
            return saida.strip().splitlines()[0].strip()
    return ""


def versao_nvidia():
    m = re.search(r"Kernel Module(?:\s+for\s+\S+)?\s+([\d.]+)", ler(os.path.join(PROC, "driver", "nvidia", "version")))
    if m:
        return m.group(1)
    saida = rodar(["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"], 5)
    return saida.strip().splitlines()[0] if saida and saida.strip() else ""


# ----- a imagem do Matsu -----
def ler_imagem(status_json=None):
    """{nome, variante, registro, referencia, tag} da imagem instalada."""
    try:
        with open(INFO_IMAGEM, encoding="utf-8") as f:
            info = json.load(f)
    except (OSError, ValueError):
        info = {}
    d = {"nome": info.get("image-name", ""), "variante": info.get("image-variant", ""),
         "registro": info.get("image-registry", ""), "referencia": "", "tag": ""}
    if status_json is None:
        saida = rodar(["rpm-ostree", "status", "--booted", "--json"], 20)
        try:
            status_json = json.loads(saida) if saida else {}
        except ValueError:
            status_json = {}
    implantacoes = status_json.get("deployments") or []
    atual = next((x for x in implantacoes if x.get("booted")), implantacoes[0] if implantacoes else None)
    if atual:
        ref = atual.get("container-image-reference", "")
        d["referencia"] = ref
        sem_transporte = re.sub(r"^ostree-[a-z-]+:(docker://)?", "", ref)
        sem_digest = sem_transporte.split("@", 1)[0]
        ultimo = sem_digest.rsplit("/", 1)[-1]
        if ":" in ultimo:
            d["tag"] = ultimo.rsplit(":", 1)[1]
            repo = sem_digest.rsplit(":", 1)[0]
        else:
            repo = sem_digest
        if not d["nome"] and repo:
            d["nome"] = repo.rsplit("/", 1)[-1]
        if not d["registro"] and "/" in repo:
            d["registro"] = repo.rsplit("/", 1)[0]
    if not d["variante"] and d["nome"]:
        d["variante"] = "nvidia" if d["nome"].endswith("-nvidia") else "main"
    return d


def troca_de_imagem(lista_placas, imagem):
    """Se a imagem não combina com a placa: {acao, alvo, nome, aviso}. Senão None.
    instalar-nvidia: tem NVIDIA e está na imagem sem o driver dela.
    tirar-nvidia: está na imagem NVIDIA sem nenhuma placa NVIDIA."""
    if not imagem.get("registro"):
        return None
    tem_nvidia = [p for p in lista_placas if p["fornecedor"] == "10de"]
    variante = imagem.get("variante") or "main"
    tag = imagem.get("tag") or "estavel"
    if tem_nvidia and variante != "nvidia":
        aviso = "" if all(nvidia_moderna(p["modelo_id"]) for p in tem_nvidia) else "antiga"
        return {"acao": "instalar-nvidia", "nome": "matsu-os-nvidia", "aviso": aviso,
                "alvo": f"{imagem['registro']}/matsu-os-nvidia:{tag}"}
    if not tem_nvidia and variante == "nvidia" and lista_placas:
        return {"acao": "tirar-nvidia", "nome": "matsu-os", "aviso": "",
                "alvo": f"{imagem['registro']}/matsu-os:{tag}"}
    return None


def outra_imagem(imagem):
    """A outra versão do Matsu no mesmo canal: a com o driver da NVIDIA ou a comum.
    É o caminho de volta (ou de ida) mesmo quando a placa não pede a troca."""
    if not imagem.get("registro"):
        return None
    tag = imagem.get("tag") or "estavel"
    if (imagem.get("variante") or "main") == "nvidia":
        return {"acao": "tirar-nvidia", "nome": "matsu-os", "aviso": "", "alvo": f"{imagem['registro']}/matsu-os:{tag}"}
    return {"acao": "instalar-nvidia", "nome": "matsu-os-nvidia", "aviso": "",
            "alvo": f"{imagem['registro']}/matsu-os-nvidia:{tag}"}


def comando_troca(alvo):
    """O comando que troca a imagem (o mesmo do "matsu drivers --trocar"), assinatura conferida."""
    if not re.fullmatch(r"[a-z0-9.\-]+(:\d+)?(/[a-z0-9._\-]+)+:[\w.\-]+", alvo or ""):
        return None
    return ["pkexec", "bootc", "switch", "--enforce-container-sigpolicy", alvo]


# ----- tudo junto -----
def tudo(nome_da_placa=None, lingua="pt", cache="", agora=False):
    if cache and not agora:
        try:
            with open(cache, encoding="utf-8") as f:
                guardado = json.load(f)
            if time.time() - guardado.get("quando", 0) < 3600 and guardado.get("kernel") == os.uname().release:
                return guardado
        except (OSError, ValueError):
            pass
    lista = placas(nome_da_placa, lingua)
    lista_icds = icds()
    resumo = rodar(["vulkaninfo", "--summary"], 15)
    vk = ler_vulkaninfo(resumo) if resumo else {"instancia": "", "gpus": []}
    completo = rodar(["vulkaninfo"], 20) if resumo else None
    gl = ler_glxinfo(rodar(["glxinfo", "-B"], 8) or "") if os.environ.get("DISPLAY") else {}
    mesa = versao_mesa() or gl.get("mesa", "")
    if not mesa:
        for g in vk["gpus"]:
            m = re.search(r"Mesa ([\d.]+)", g.get("info", ""))
            if m:
                mesa = m.group(1)
                break
    nvidia = versao_nvidia() if any(p["driver"] == "nvidia" for p in lista) else ""
    for p in lista:
        p["tipo"] = tipo_placa(p)
        p["driver_nome"] = NOMES_DRIVER.get(p["driver"], p["driver"])
        # O Vulkan desta placa (casando pelo fabricante; com duas da mesma marca, pela ordem).
        mesma = [g for g in vk["gpus"] if g["fornecedor"] == p["fornecedor"]]
        g = mesma.pop(0) if mesma else None
        if g:
            vk["gpus"].remove(g)
        p["vulkan"] = g
        if g and g.get("tipo") in ("integrada", "dedicada"):
            p["tipo"] = g["tipo"]
        if p["driver"] == "nvidia":
            p["versao"] = f"NVIDIA {nvidia}" if nvidia else "NVIDIA"
        elif p["driver"] in ("amdgpu", "radeon", "i915", "xe", "nouveau"):
            p["versao"] = f"Mesa {mesa}" if mesa else "Mesa"
        else:
            p["versao"] = ""
    imagem = ler_imagem()
    d = {
        "quando": int(time.time()),
        "kernel": os.uname().release,
        "placas": lista,
        "mesa": mesa,
        "vulkan": {"instancia": vk["instancia"], "tem_vulkaninfo": resumo is not None,
                   "icds": [{k: i[k] for k in ("nome", "arquivo", "api", "bits", "existe")} for i in lista_icds]},
        "vulkan32": vulkan32(lista_icds),
        "opengl": gl,
        "nvidia": nvidia,
        "anti_lag": anti_lag(completo),
        "imagem": imagem,
        "troca": troca_de_imagem(lista, imagem),
        "outra": outra_imagem(imagem),
    }
    if cache:
        try:
            os.makedirs(os.path.dirname(cache), exist_ok=True)
            with open(cache + ".tmp", "w", encoding="utf-8") as f:
                json.dump(d, f, ensure_ascii=False)
            os.replace(cache + ".tmp", cache)
        except OSError:
            pass
    return d


def demo(lingua="pt"):
    """Um PC com Ryzen (integrada) e uma RX 6700 XT, para as fotos da prévia."""
    qual = os.environ.get("MATSU_DRIVERS_DEMO", "1")
    amd = {"pci": "0000:03:00.0", "fornecedor": "1002", "marca": "AMD", "modelo_id": "73df",
           "nome": "AMD Radeon RX 6700 XT", "driver": "amdgpu", "principal": True, "tipo": "dedicada",
           "driver_nome": "amdgpu", "versao": "Mesa 26.0.4",
           "vulkan": {"nome": "AMD Radeon RX 6700 XT (RADV NAVI22)", "api": "1.4.335", "driver": "radv",
                      "versao_driver": "26.0.4", "info": "Mesa 26.0.4", "fornecedor": "1002", "tipo": "dedicada"}}
    integrada = {"pci": "0000:0e:00.0", "fornecedor": "1002", "marca": "AMD", "modelo_id": "164e",
                 "nome": "AMD Radeon Graphics (Raphael)", "driver": "amdgpu", "principal": False, "tipo": "integrada",
                 "driver_nome": "amdgpu", "versao": "Mesa 26.0.4",
                 "vulkan": {"nome": "AMD Radeon Graphics (RADV RAPHAEL_MENDOCINO)", "api": "1.4.335", "driver": "radv",
                            "versao_driver": "26.0.4", "info": "Mesa 26.0.4", "fornecedor": "1002", "tipo": "integrada"}}
    nvidia = {"pci": "0000:01:00.0", "fornecedor": "10de", "marca": "NVIDIA", "modelo_id": "2684",
              "nome": "NVIDIA GeForce RTX 4090", "driver": "nouveau", "principal": True, "tipo": "dedicada",
              "driver_nome": "nouveau (livre)", "versao": "Mesa 26.0.4",
              "vulkan": {"nome": "NVIDIA GeForce RTX 4090 (NVK AD102)", "api": "1.4.335", "driver": "nvk",
                         "versao_driver": "26.0.4", "info": "Mesa 26.0.4", "fornecedor": "10de", "tipo": "dedicada"}}
    lista = [nvidia] if qual == "nvidia" else [amd, integrada]
    icd = ("NVK (Mesa)", "nouveau_icd") if qual == "nvidia" else ("RADV (Mesa)", "radeon_icd")
    imagem = {"nome": "matsu-os", "variante": "main", "registro": "ghcr.io/kaikyolf29-hub",
              "referencia": "ostree-image-signed:docker://ghcr.io/kaikyolf29-hub/matsu-os:estavel", "tag": "estavel"}
    return {
        "quando": int(time.time()), "kernel": "6.19.6-300.fc44.x86_64", "placas": lista, "mesa": "26.0.4",
        "vulkan": {"instancia": "1.4.335", "tem_vulkaninfo": True,
                   "icds": [{"nome": icd[0], "arquivo": icd[1] + ".x86_64.json", "api": "1.4.335", "bits": 64, "existe": True},
                            {"nome": icd[0], "arquivo": icd[1] + ".i686.json", "api": "1.4.335", "bits": 32, "existe": True}]},
        "vulkan32": {"carregador": True, "drivers": [icd[0]], "ok": True},
        "opengl": {"placa": "NV192 (nouveau)" if qual == "nvidia" else "AMD Radeon RX 6700 XT (radeonsi, navi22)",
                   "api": "4.6", "mesa": "26.0.4", "nucleo": "4.6 (Core Profile) Mesa 26.0.4"},
        "nvidia": "", "anti_lag": qual != "nvidia", "imagem": imagem,
        "troca": troca_de_imagem(lista, imagem),
        "outra": outra_imagem(imagem),
    }
