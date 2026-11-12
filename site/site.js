// Site do Matsu: português ou inglês, o relógio da barra, a seção atual na
// barra e a troca de estilo da barra. Funciona sem nada disso também (o texto
// em português já está no HTML).
(function () {
  "use strict";

  // ----- idioma -----
  var guardado = null;
  try { guardado = localStorage.getItem("matsu-idioma"); } catch (e) { /* sem armazenamento */ }
  var pedido = new URLSearchParams(location.search).get("lang");
  var idioma = pedido === "en" || pedido === "pt" ? pedido
    : guardado || ((navigator.language || "pt").toLowerCase().indexOf("pt") === 0 ? "pt" : "en");

  // O texto em português fica guardado no próprio elemento na primeira troca.
  function trocar(el, atributo, valorEn) {
    var chave = "pt" + atributo.replace(/-/g, "").toLowerCase();
    if (el.dataset[chave] === undefined)
      el.dataset[chave] = atributo === "Texto" ? el.innerHTML : (el.getAttribute(atributo) || "");
    var valor = idioma === "en" ? valorEn : el.dataset[chave];
    if (atributo === "Texto") el.innerHTML = valor;
    else el.setAttribute(atributo, valor);
  }

  function aplicarIdioma() {
    document.documentElement.lang = idioma === "en" ? "en" : "pt-BR";
    document.querySelectorAll("[data-en]").forEach(function (el) {
      // "matsu seguranca" continua como código nos dois idiomas.
      var en = el.getAttribute("data-en").replace("matsu seguranca", "<code>matsu seguranca</code>");
      trocar(el, "Texto", en);
    });
    document.querySelectorAll("[data-en-alt]").forEach(function (el) { trocar(el, "alt", el.dataset.enAlt); });
    document.querySelectorAll("[data-en-aria]").forEach(function (el) { trocar(el, "aria-label", el.dataset.enAria); });
    document.querySelectorAll("[data-en-rotulo]").forEach(function (el) {
      trocar(el, "data-rotulo", el.dataset.enRotulo);
      el.setAttribute("aria-label", el.getAttribute("data-rotulo"));
    });
    var botao = document.getElementById("idioma");
    botao.textContent = idioma === "en" ? "PT" : "EN";
    relogio();
  }

  document.getElementById("idioma").addEventListener("click", function () {
    idioma = idioma === "en" ? "pt" : "en";
    try { localStorage.setItem("matsu-idioma", idioma); } catch (e) { /* sem armazenamento */ }
    aplicarIdioma();
  });

  // ----- relógio, como o da barra do Matsu -----
  function relogio() {
    var agora = new Date();
    var local = idioma === "en" ? "en-US" : "pt-BR";
    document.getElementById("hora").textContent =
      agora.toLocaleTimeString(local, { hour: "2-digit", minute: "2-digit" });
    // Como na barra do Matsu: "qua. 11 de nov." (sem a vírgula do navegador).
    var partes = new Intl.DateTimeFormat(local, { weekday: "short", day: "numeric", month: "short" }).formatToParts(agora);
    var pega = function (tipo) {
      for (var i = 0; i < partes.length; i++) if (partes[i].type === tipo) return partes[i].value;
      return "";
    };
    document.getElementById("data").textContent = idioma === "en"
      ? pega("weekday") + ", " + pega("month") + " " + pega("day")
      : pega("weekday") + " " + pega("day") + " de " + pega("month");
  }
  setInterval(relogio, 15000);

  // ----- a seção na tela fica marcada na barra -----
  var links = {};
  document.querySelectorAll(".ilha-apps a").forEach(function (a) {
    links[a.getAttribute("href").slice(1)] = a;
    a.setAttribute("aria-label", a.getAttribute("data-rotulo"));
  });
  if ("IntersectionObserver" in window) {
    var visiveis = {};
    var observador = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (e) { visiveis[e.target.id] = e.isIntersecting; });
      var atual = null;
      document.querySelectorAll("main .parte").forEach(function (s) {
        if (atual === null && visiveis[s.id]) atual = s.id;
      });
      Object.keys(links).forEach(function (id) {
        links[id].classList.toggle("atual", id === atual);
        if (id === atual) links[id].setAttribute("aria-current", "true");
        else links[id].removeAttribute("aria-current");
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    document.querySelectorAll("main .parte").forEach(function (s) { observador.observe(s); });
  }

  // ----- estilo da barra -----
  var fotoBarra = document.getElementById("foto-barra");
  var nomes = {
    fusao: ["A barra no estilo do Matsu", "The bar in Matsu style"],
    windows: ["A barra no estilo do Windows", "The bar in Windows style"],
    mac: ["A barra no estilo do Mac", "The bar in Mac style"]
  };
  document.querySelectorAll(".estilos button").forEach(function (b) {
    b.addEventListener("click", function () {
      document.querySelectorAll(".estilos button").forEach(function (o) {
        o.setAttribute("aria-selected", o === b ? "true" : "false");
      });
      var estilo = b.dataset.estilo;
      fotoBarra.src = "img/barra-" + estilo + ".webp";
      fotoBarra.dataset.ptalt = nomes[estilo][0];
      fotoBarra.dataset.enAlt = nomes[estilo][1];
      fotoBarra.alt = nomes[estilo][idioma === "en" ? 1 : 0];
    });
  });

  // ----- foto que ainda não existe some -----
  document.querySelectorAll(".foto img").forEach(function (img) {
    function sumir() { img.closest(".foto").classList.add("sem-foto"); }
    img.addEventListener("error", sumir);
    if (img.complete && img.naturalWidth === 0 && img.src) sumir();
  });

  aplicarIdioma();
})();
