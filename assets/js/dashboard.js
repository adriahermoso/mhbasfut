/* ==========================================================================
   MHBASFUT - Lògica de la consola d'administració
   --------------------------------------------------------------------------
   Aquest fitxer serveix dues pàgines i evita duplicar codi:

     · index.html     -> MHBSFUT.mostraLogin(form, al fer Exit)
     · dashboard.html -> MHBSFUT.muntaConsola(arrel)

   Les credencials, la clau de sessió i el llistat d'alumnes viuen aqui, de
   manera que la comprovació d'accés i la lectura de dades no es puguin
   desincronitzar.

   AVÍS: el repositori és públic. Les credencials de baix són NOMÉS una
   aparició d'inici de sessió per a la presentació del projecte i NO
   protegeixen res: qualsevol pot llegir-les al codi font. Les dades dels
   alumnes són igualment(fitxers JSON oberts) al repositori.
   ========================================================================== */

window.MHBSFUT = (function () {
  'use strict';

  /* ------------------------------------------------------------------------
     Configuració
     ------------------------------------------------------------------------ */

  var CONFIG = {
    /* Clau de sessionStorage on es desa la sessió oberta. */
    sessionKey: 'mhbasfut.consola',

    /* Adreça base dels fitxers de dades. Utilitzem raw.githubusercontent.com
       per evitar el cau (cache) de GitHub Pages i que les dades de l'APP
       es vegin a l'instant després de sincronitzar. */
    dataPath: 'https://raw.githubusercontent.com/adriahermoso/mhbasfut/main/users/',

    /* Repositori i branca per a l'EDICIÓ manual. La consola escriu els
       fitxers amb l'API de continguts de GitHub, que demana un token
       personal (PAT) amb permís d'escriptura sobre aquest repositori. */
    apiUsuari: 'adriahermoso',
    apiRepo: 'mhbasfut',
    apiBranca: 'main',

    /* Clau de localStorage on es desa el token. Mai al codi ni al repo. */
    tokenKey: 'mhbasfut.token',

    /* Llistat d'alumnes que es mostren a la consola.

       És explícit a propòsit: GitHub Pages no deixa llistar el contingut de
       users/, i a més l'alumne ha d'aparèixer encara que no hagi sincronitzat
       mai (no existeix encara el fitxer). La clau ha de ser EXACTAMENT el
       string que l'APP iOS puja a users/<username>.json: sensible a
       majúscules i minúscules, sense tildes ni espais.

       Els noms visibles no hi són: es deriven de la clau partint-la pel
       cognom (HectorVelasco -> «Hector Velasco»). Quan calgui un nom que
       això no doni (tildes, cognoms compostes...), poseu-lo a `noms`. */
    alumnes: [
      'EloiRomero', 'GonzaloSchiavo', 'HugoMartinez', 'MarcVilanova', 'DavidHernandez',
      'MarcelRosell', 'HectorVelasco'
    ],

    /* Noms visibles que NO es deriven de l'identificador. La clau és
       l'usuari exacte del llistat de dalt. */
    noms: {
      HectorVelasco: 'Héctor Velasco'
    },

    /* Comptes d'administració de la demostració. */
    comptes: [
      { usuari: 'admin', contrasenya: 'mhbasfut2026' }
    ]
  };

  /* Etiquetes del qüestionari, en el mateix ordre que les barres del resum. */
  var PREGUNTES = [
    ['alimentacio', 'Alimentació'],
    ['recuperacio', 'Recuperació'],
    ['son', 'Son'],
    ['hidratacio', 'Hidratació'],
    ['gestioEmocional', 'Gestió emocional']
  ];

  /* Escala 1-5 de la qualitat del son. */
  var QUALITAT_SON = ['Molt baixa', 'Baixa', 'Mitjana', 'Alta', 'Molt alta'];

  /* Escala màxima de l'eix del gràfic (intensitat i hores de son). */
  var ESCALA_GRAFIC = 10;

  /* El període es divideix en dues meitats per calcular les variacions. */
  var MEITAT = 6;

  /* Text de comparació dels indicadors. Curt a propòsit: ha de caber al
     peu de la targeta al costat de «Detalls». */
  var COMPARACIO = 'vs. ' + MEITAT + ' dies';

  /* ------------------------------------------------------------------------
     Utilitats
     ------------------------------------------------------------------------ */

  /* Crea un element. El text sempre s'assigna amb textContent, de manera que
     les dades que venen dels JSON mai s'interpreten com a HTML. */
  function el(etiqueta, classe, text) {
    var node = document.createElement(etiqueta);
    if (classe) node.className = classe;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function afegeix(pare, etiqueta, classe, text) {
    var node = el(etiqueta, classe, text);
    pare.appendChild(node);
    return node;
  }

  /* '2026-09-25' -> '25/09/2026'. Es fa a mà per no depender del fus horari
     ni del navegador. Accepta ISO complet ('2026-09-27T20:15:36Z') de
     l'exportador iOS: es retalla als primers 10 caràcters. */
  function isoAData(iso) {
    if (typeof iso !== 'string') return null;
    var d = iso.length >= 10 ? iso.slice(0, 10) : iso;
    return /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null;
  }

  function dataCurta(iso) {
    var d = isoAData(iso) || (typeof iso === 'string' ? iso : null);
    if (!d) return '—';
    var p = d.split('-');
    if (p.length !== 3) return iso;
    return p[2] + '/' + p[1] + '/' + p[0];
  }

  /* El dia del mes, per etiquetes curtes dels eixos. */
  function diaDelMes(iso) {
    var d = isoAData(iso);
    if (!d) return '';
    var p = d.split('-');
    return p.length === 3 ? p[2] : iso;
  }

  /* Decimal amb coma, l'ús habitual en català. */
  function coma(valor, decimals) {
    var n = Number(valor);
    if (!isFinite(n)) return '—';
    return n.toFixed(decimals === undefined ? 1 : decimals).replace('.', ',');
  }

  /* Converteix un valor i el màxim de la seva escala en un percentatge 0-100. */
  function percentatge(a, b) {
    var x = Number(a);
    var y = Number(b);
    if (!isFinite(x) || !isFinite(y) || y === 0) return 0;
    return Math.max(0, Math.min(100, Math.round((x / y) * 100)));
  }

  function mitjana(valors) {
    var valids = (valors || []).filter(function (v) {
      return typeof v === 'number' && isFinite(v);
    });
    if (!valids.length) return 0;
    var total = valids.reduce(function (a, b) { return a + b; }, 0);
    return total / valids.length;
  }

  /* Variació percentual entre dos valors. Retorna null si no es pot calcular
     (per exemple, si el valor de referència és 0). */
  function variacio(ara, abans) {
    if (!isFinite(ara) || !isFinite(abans) || abans === 0) return null;
    return Math.round(((ara - abans) / abans) * 100);
  }

  /* Inicials per a l'avatar. */
  function inicials(alumne) {
    var perfil = (alumne && alumne.perfil) || {};
    var nom = (perfil.nom || '').trim();
    var cognoms = (perfil.cognoms || '').trim();
    if (!nom && !cognoms) return '?';
    return ((nom[0] || '') + (cognoms[0] || '')).toUpperCase();
  }

  /* Torna el text d'un error de xarxa en català, sense(stack traces). */
  function descriuError(error) {
    if (error && error.name === 'AbortError') return 'la petició s\'ha cancel·lat';
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      return 'no hi ha connexió a internet';
    }
    return 'no s\'ha pogut llegir el fitxer';
  }

  /* ------------------------------------------------------------------------
     Edició manual: token i API de continguts de GitHub
     --------------------------------------------------------------------------
     La consola llegeix les dades de raw.githubusercontent, però per DESAR
     canvis cal escriure al repositori i això demana un token personal de
     GitHub (PAT) amb permís de continguts. El token es desa a localStorage
     d'aquest navegador i mai viatja enlloc més.

     Cada desament escriu `adminRevision` (ISO-8601 sense mil·lisegons) i
     `adminOverrides` dins users/<usuari>.json. L'APP aplica les edicions la
     propera vegada que s'obre o torna a primer pla i recorda la revisió
     aplicada per no repetir-la.
     ------------------------------------------------------------------------ */

  /* Estat del panell d'ajustos, que ha de sobreviure als redibuixos. */
  var editorMissatge = null;

  function llegeixToken() {
    try {
      return window.localStorage.getItem(CONFIG.tokenKey) || '';
    } catch (e) {
      return '';
    }
  }

  function desaToken(token) {
    try {
      window.localStorage.setItem(CONFIG.tokenKey, token);
    } catch (e) {
      /* sense operació */
    }
  }

  function esborraToken() {
    try {
      window.localStorage.removeItem(CONFIG.tokenKey);
    } catch (e) {
      /* sense operació */
    }
  }

  /* Base64 <-> text UTF-8: l'API de GitHub treballa en base64 i els JSON
     porten accents, de manera que btoa/atob directes no serveixen. */
  function utf8ABase64(text) {
    var bytes = new TextEncoder().encode(text);
    var bin = '';
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return window.btoa(bin);
  }

  function base64AUtf8(b64) {
    var bin = window.atob(String(b64).replace(/\s/g, ''));
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new TextDecoder().decode(bytes);
  }

  /* Segell de revisió: ISO-8601 SENSE mil·lisegons, el format exacte que
     accepta l'APP (.iso8601 i AdminOverrideApplier). */
  function novaRevisio() {
    return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  }

  function missatgeApi(estat) {
    if (estat === 0) return 'No s\'ha pogut contactar amb GitHub.';
    if (estat === 401) return 'El token no és vàlid o ha caducat.';
    if (estat === 403) return 'El token no té permís d\'escriptura en aquest repositori.';
    if (estat === 404) return 'No s\'ha trobat el fitxer al repositori.';
    if (estat === 409 || estat === 422) return 'El fitxer ha canviat mentrestant. Torna-ho a provar.';
    return 'GitHub ha respost amb un error (' + estat + ').';
  }

  /* Una crida a l'API de continguts. Mai llança: els errors es converteixen
     en { ok:false, estat, error } perquè la interfície els pugui mostrar. */
  function cridaApi(token, metode, cami, cos) {
    var opcions = {
      method: metode,
      cache: 'no-store',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer ' + token,
        'X-GitHub-Api-Version': '2022-11-28'
      }
    };
    if (cos) {
      opcions.headers['Content-Type'] = 'application/json';
      opcions.body = JSON.stringify(cos);
    }
    return window.fetch(
      'https://api.github.com/repos/' + CONFIG.apiUsuari + '/' + CONFIG.apiRepo +
        '/contents/' + cami,
      opcions
    ).then(function (resposta) {
      return resposta.json().catch(function () { return null; }).then(function (dades) {
        return { ok: resposta.ok, estat: resposta.status, dades: dades };
      });
    }).catch(function (error) {
      return { ok: false, estat: 0, error: descriuError(error) };
    });
  }

  /* Llegeix el fitxer actual directament de l'API (raw podria servir una
     còpia amb retard). Torna { sha, dades }, { sha:null, dades:null } si el
     fitxer encara no existeix, o { error }. */
  function llegeixFitxerApi(token, cami) {
    return cridaApi(token, 'GET', cami + '?ref=' + CONFIG.apiBranca).then(function (r) {
      if (r.error) return { error: r.error };
      if (r.estat === 404) return { sha: null, dades: null };
      if (!r.ok) return { error: missatgeApi(r.estat) };
      try {
        return { sha: r.dades.sha, dades: JSON.parse(base64AUtf8(r.dades.content)) };
      } catch (e) {
        return { error: 'El fitxer remot no és JSON vàlid.' };
      }
    });
  }

  function desaFitxerApi(token, cami, objecte, sha, missatge) {
    var cos = {
      message: missatge,
      content: utf8ABase64(JSON.stringify(objecte, null, 2) + '\n'),
      branch: CONFIG.apiBranca
    };
    if (sha) cos.sha = sha;
    return cridaApi(token, 'PUT', cami, cos).then(function (r) {
      if (r.error || !r.ok) return { error: r.error || missatgeApi(r.estat) };
      return { ok: true };
    });
  }

  /* ------------------------------------------------------------------------
     Sessió (demostració, no seguretat real)
     ------------------------------------------------------------------------ */

  function sessioOberta() {
    try {
      var brut = window.sessionStorage.getItem(CONFIG.sessionKey);
      if (!brut) return null;
      var dades = JSON.parse(brut);
      if (!dades || typeof dades.usuari !== 'string') return null;
      return dades;
    } catch (e) {
      return null;
    }
  }

  function obreSessio(usuari) {
    var dades = { usuari: usuari, oberta: new Date().toISOString() };
    try {
      window.sessionStorage.setItem(CONFIG.sessionKey, JSON.stringify(dades));
    } catch (e) {
      /* Si sessionStorage està bloquejat es continua igual: la sessió
         durarà només fins que es torni a carregar la pàgina. */
    }
    return dades;
  }

  function tancaSessio() {
    try {
      window.sessionStorage.removeItem(CONFIG.sessionKey);
    } catch (e) {
      /* sense operació */
    }
  }

  function credencialsValides(usuari, contrasenya) {
    var u = String(usuari || '').trim().toLowerCase();
    var c = String(contrasenya || '');
    return CONFIG.comptes.some(function (compte) {
      return compte.usuari.toLowerCase() === u && compte.contrasenya === c;
    });
  }

  /* ------------------------------------------------------------------------
     Formulari d'inici de sessió (index.html)
     ------------------------------------------------------------------------ */

  /* Comprova les credencials, desa la sessió i crida alExit quan és correcte.
     Si fallen, es mostra un missatge d'error i el focus torna al formulari. */
  function mostraLogin(formulari, alExit) {
    if (!formulari) return;

    var campUsuari = formulari.elements.usuari;
    var campContrasenya = formulari.elements.contrasenya;
    var avís = document.getElementById('login-avís');
    if (!campUsuari || !campContrasenya) return;

    function netejaError() {
      if (avís) {
        avís.textContent = '';
        avís.hidden = true;
      }
      campContrasenya.removeAttribute('aria-invalid');
    }

    function mostraError(texte) {
      if (!avís) return;
      avís.textContent = texte;
      avís.hidden = false;
    }

    campUsuari.addEventListener('input', netejaError);
    campContrasenya.addEventListener('input', netejaError);

    formulari.addEventListener('submit', function (event) {
      event.preventDefault();
      netejaError();

      if (!credencialsValides(campUsuari.value, campContrasenya.value)) {
        mostraError('L\'usuari o la contrasenya no són correctes. Torna-ho a provar.');
        campContrasenya.value = '';
        campContrasenya.setAttribute('aria-invalid', 'true');
        campContrasenya.focus();
        return;
      }

      obreSessio(campUsuari.value.trim());
      if (typeof alExit === 'function') alExit();
    });
  }

  /* ------------------------------------------------------------------------
     Lectures dels fitxers de dades
     ------------------------------------------------------------------------ */

   function demanaFitxer(nom) {
     /* Cache-busting amb timestamp per forçar la càrrega de dades reals. */
     var adreça = CONFIG.dataPath + encodeURIComponent(nom) + '.json?t=' + new Date().getTime();
     
     /* Timeout manual per compatibilitat total. */
     return new Promise(function (resolve, reject) {
       var timeoutId = setTimeout(function () {
         reject(new Error('Timeout carregant ' + nom));
       }, 10000);

       window.fetch(adreça, { cache: 'no-store' })
         .then(function (resposta) {
           clearTimeout(timeoutId);
           if (resposta.status === 404) resolve(null);
           else if (!resposta.ok) reject(new Error('HTTP ' + resposta.status));
           else resolve(resposta.json());
         })
         .catch(function (err) {
           clearTimeout(timeoutId);
           reject(err);
         });
     });
   }

   /* Demanda un únic fitxer d'alumne (només el que puja l'APP iOS).
      Resol sempre amb { username, dades } o { username, tipus, error }. */
   function carregaAlumne(username) {
     return demanaFitxer(username).then(function (dades) {
       if (!dades) return { username: username, tipus: 'absent' };
       var n = normalitza(username, dades);
       n.username = username;
       /* `raw` és el JSON tal qual: el panell d'ajustos edita sobre ell. */
       return { username: username, dades: n, raw: dades };
     }).catch(function (error) {
       return { username: username, tipus: 'error', error: descriuError(error) };
     });
   }

   /* Carrega tots els alumnes. En lloc de Promise.all, utilitza una càrrega
      progressiva per mostrar les dades a mesura que arriben i no bloquejar
      la UI si un fitxer triga massa. */
   function carregaTots(onResultat) {
     CONFIG.alumnes.forEach(function (usuari) {
       carregaAlumne(usuari).then(onResultat);
     });
   }

  /* Model de consola per a un alumne del llistat que encara no té dades.

     Un alumne pot aparèixer a CONFIG.alumnes abans que existeixi el seu
     fitxer a users/ (encara no ha sincronitzat) o que la petició hagi fallat.
     En tots dos casos ha de conservar la fila al rail: el llistat és
     explícit al codi i no depèn de quins fitxers hi hagi al repositori.
     `problema` distingeix 'absent' (mai ha sincronitzat) de 'error'. */
  function alumneVisible(r) {
    if (r.dades) return r.dades;
    var p = parteixNom(r.username);
    return {
      username: r.username,
      senseDades: true,
      problema: r.tipus === 'error' ? 'error' : 'absent',
      perfil: { nom: p.nom, cognoms: p.cognoms }
    };
  }

  /* Text del rail segons l'estat de les dades de l'alumne. */
  function subRail(alumne) {
    if (alumne.senseDades) {
      return alumne.problema === 'error'
        ? 'No s\'ha pogut llegir'
        : 'Encara no ha sincronitzat';
    }
    var recompenses = alumne.recompenses || {};
    return (recompenses.racha != null ? recompenses.racha : 0) + ' dies de racha';
  }

  /* Nom visible d'un alumne, del perfil si en té i de la clau si no. */
  function nomVisible(alumne) {
    var perfil = alumne.perfil || {};
    return ((perfil.nom || '') + ' ' + (perfil.cognoms || '')).trim() || alumne.username;
  }

  /* ------------------------------------------------------------------------
     Adaptador del snapshot iOS (UserDataExporter, schemaVersion 1) al
     model heretat que pinta buildFitxa (perfil/pla/questionari/
     progresDiari/historial/recompenses). Els fitxers demo antics passen
     intactes. No s'inventa res: cada camp indica la font; quan l'APP no
     desa una dada (p. ex. minuts, dorsal), es deixa '—' o 0 i la fitxa
     ja sap amagar la barra.
     ------------------------------------------------------------------------ */

  var SON_HORES_ESTIMADES = { 0: 8.5, 1: 7.5, 2: 6.5, 3: 5.0 };
  var EMOCIO_ESCALA = [10, 8, 6, 4, 2];
  var EMOCIO_ESTAT = ['Genial', 'Bé', 'Normal', 'Decaigut', 'Fatal'];
  var CATEGORIA_MAX = {
    'Son i descans': 25,
    'Nutrició i hidratació': 20,
    'Recuperació muscular': 20,
    'Prevenció de lesions': 15,
    'Salut mental i benestar': 10,
    'Hàbits saludables': 10
  };

  function esNouEsquema(d) {
    return d && typeof d === 'object' &&
      d.schemaVersion !== undefined && d.questionnaireAnswers !== undefined;
  }

  function parteixNom(slug) {
    var s = String(slug || '').trim();
    /* CONFIG.noms és l'escapatori per als noms que no es deriven de la clau
       (tildes, cognoms compostes...). Sense entrada, es parteix el slug. */
    var oficial = (s && CONFIG.noms && CONFIG.noms[s]) || s;
    if (!oficial) return { nom: '?', cognoms: '' };
    var parts = oficial.replace(/([a-zà-ÿ])([A-ZÀ-Þ])/g, '$1 $2').split(' ');
    if (parts.length === 1) {
      return { nom: parts[0][0].toUpperCase() + parts[0].slice(1), cognoms: '' };
    }
    return { nom: parts[0], cognoms: parts.slice(1).join(' ') };
  }

  function avuiData() {
    var ara = new Date();
    function dos(n) { return (n < 10 ? '0' : '') + n; }
    return ara.getFullYear() + '-' + dos(ara.getMonth() + 1) + '-' + dos(ara.getDate());
  }

  function sumaDies(dataISO, n) {
    var p = String(dataISO).split('-');
    var base = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
    base.setDate(base.getDate() + n);
    function dos(x) { return (x < 10 ? '0' : '') + x; }
    return base.getFullYear() + '-' + dos(base.getMonth() + 1) + '-' + dos(base.getDate());
  }

  function diferenciaDies(aISO, bISO) {
    var pa = String(aISO).split('-');
    var pb = String(bISO).split('-');
    var a = new Date(Number(pa[0]), Number(pa[1]) - 1, Number(pa[2]));
    var b = new Date(Number(pb[0]), Number(pb[1]) - 1, Number(pb[2]));
    return Math.round((b - a) / 86400000);
  }

  /* Ratxa senzilla per a l'editor: N dates seguides acabant avui, a migdia
     UTC perquè el dia no balli amb el fus horari en passar a Date a l'APP. */
  function diesDeRatxa(dies) {
    var dates = [];
    for (var i = 0; i < dies; i++) dates.push(sumaDies(avuiData(), -i) + 'T12:00:00Z');
    return dates;
  }

  /* Data d'inici perquè avui sigui el dia 'dia' del pla (dia 1 = avui), a
     mitjanit UTC com la resta de dates del pla. */
  function iniciPerDia(dia) {
    return sumaDies(avuiData(), -(dia - 1)) + 'T00:00:00Z';
  }

  /* Dia del pla que tocaria avui segons la data d'inici desada (1 = avui). */
  function diaDelPla(planStartDate) {
    var iso = isoAData(planStartDate);
    if (!iso) return 1;
    return Math.max(1, diferenciaDies(iso, avuiData()) + 1);
  }

  function rachaMaxima(datesISO) {
    var uniq = {};
    (datesISO || []).forEach(function (d) { if (d) uniq[d] = 1; });
    var dies = Object.keys(uniq).sort();
    var max = 0;
    var actual = 0;
    var prev = null;
    dies.forEach(function (d) {
      if (prev && diferenciaDies(prev, d) === 1) { actual += 1; }
      else { actual = 1; }
      if (actual > max) max = actual;
      prev = d;
    });
    return max;
  }

  function intensitatMitjana(day) {
    if (!day || !day.intensities) return null;
    var vals = Object.keys(day.intensities).map(function (k) { return day.intensities[k]; })
      .filter(function (v) { return typeof v === 'number' && isFinite(v); });
    if (!vals.length) return null;
    return vals.reduce(function (a, b) { return a + b; }, 0) / vals.length;
  }

  function horesSonDe(rating) {
    if (rating === null || rating === undefined) return null;
    var h = SON_HORES_ESTIMADES[rating];
    return h !== undefined ? h : null;
  }

  function normalitza(slug, d) {
    if (!esNouEsquema(d)) return d;

    var respostesQ = d.questionnaireAnswers || {};
    var perCat = (d.questionnaireScore && d.questionnaireScore.perCategory) || {};
    function pctCat(nom) {
      var v = Number(perCat[nom]);
      var max = CATEGORIA_MAX[nom] || 0;
      if (!isFinite(v) || !max) return 0;
      return Math.max(0, Math.min(100, Math.round((v / max) * 100)));
    }

    var nomParts = parteixNom(d.username || slug);
    var edat = parseInt(respostesQ['1'], 10);
    var alcadaPes = {};
    try { alcadaPes = JSON.parse(respostesQ['3'] || '{}'); } catch (e) { alcadaPes = {}; }
    var alturaCm = parseFloat(alcadaPes.height);
    var pesoKg = parseFloat(alcadaPes.weight);
    var esport = d.sport || 'Futbol';
    var esportBon = esport === 'Basquet' ? 'Bàsquet' : 'Futbol';

    var dataQ = isoAData(d.questionnaireCompletedDate) || isoAData(d.exportedAt) || avuiData();
    var totalQ = (d.questionnaireScore && d.questionnaireScore.total) || 0;

    var plaNum = d.assignedPlan || 1;
    var diaActual = Math.max(1, Math.min(14, Number(d.currentDay) || 1));
    var iniciPla = isoAData(d.planStartDate) || dataQ;
    var fase = diaActual <= 5 ? 'Càrrega' : (diaActual <= 10 ? 'Manteniment' : 'Retorn');
    var sessions = parseInt(respostesQ['7'], 10);
    if (!isFinite(sessions)) sessions = 4;
    var nivellText = totalQ >= 90 ? 'Entrenament invisible excel·lent' :
      totalQ >= 80 ? 'Entrenament invisible molt bo' :
      totalQ >= 70 ? 'Entrenament invisible bo' :
      totalQ >= 60 ? 'Entrenament invisible millorable' : 'Entrenament invisible deficient';

    var dies = Array.isArray(d.days) ? d.days : [];
    function dia(num) {
      for (var i = 0; i < dies.length; i++) {
        if (dies[i] && dies[i].day === num) return dies[i];
      }
      return null;
    }
    var diaAvui = dia(diaActual) || {};
    var menjarsAvui = diaAvui.selectedMeals || {};
    var nMenjars = Object.keys(menjarsAvui).length;

    var sonHist = Array.isArray(d.sleepHistory) ? d.sleepHistory : [];
    var emoHist = Array.isArray(d.emotionHistory) ? d.emotionHistory : [];
    function ultim(list) { return list.length ? list[list.length - 1] : null; }
    var sonUlt = ultim(sonHist);
    var emoUlt = ultim(emoHist);

    var sonQualitat = sonUlt ? (4 - Math.max(0, Math.min(3, sonUlt.rating))) : null;
    var sonHores = sonUlt ? horesSonDe(sonUlt.rating) : null;
    var emoEscala = emoUlt ? EMOCIO_ESCALA[Math.max(0, Math.min(4, emoUlt.rating))] : null;
    var emoEstat = emoUlt ? EMOCIO_ESTAT[Math.max(0, Math.min(4, emoUlt.rating))] : '—';

    var dataProgres = isoAData(emoUlt && emoUlt.date) || isoAData(sonUlt && sonUlt.date) ||
      isoAData(d.exportedAt) || avuiData();

    var sonPerDia = {};
    sonHist.forEach(function (r) {
      var dd = isoAData(r.date);
      if (dd) sonPerDia[dd] = r.rating;
    });

    var historial = [];
    var mostra = dies.slice(-12);
    mostra.forEach(function (dy) {
      var num = dy.day;
      var dataDia = sumaDies(iniciPla, num - 1);
      var inten = intensitatMitjana(dy);
      var ratingDia = sonPerDia[dataDia];
      var hores = (ratingDia !== undefined) ? horesSonDe(ratingDia) : sonHores;
      historial.push({
        data: dataDia,
        intensitat: inten !== null ? Math.round(inten * 10) / 10 : 0,
        horesSon: hores !== null ? hores : 0,
        dinarsCompletats: Object.keys(dy.selectedMeals || {}).length
      });
    });

    var streakDates = (d.streakCompletedDates || []).map(isoAData).filter(Boolean);
    var rachaMax = Math.max(rachaMaxima(streakDates), Number(d.streakCount) || 0);

    return {
      username: slug,
      perfil: {
        nom: nomParts.nom,
        cognoms: nomParts.cognoms,
        edat: isFinite(edat) ? edat : null,
        posicio: respostesQ['4'] || esportBon,
        dorsal: null,
        equip: '—',
        categoria: respostesQ['5'] || '—',
        dataAlta: dataQ,
        alturaCm: isFinite(alturaCm) ? alturaCm : null,
        pesoKg: isFinite(pesoKg) ? pesoKg : null
      },
      pla: {
        nom: 'Pla ' + plaNum + ' · ' + esportBon,
        objectiu: nivellText + ' (qüestionari: ' + totalQ + '/100).',
        dataInici: iniciPla,
        dataRevisio: sumaDies(iniciPla, 30),
        fase: fase,
        sessionsSetmanal: sessions,
        cicle: Number(d.cycleNumber) >= 1 ? Number(d.cycleNumber) : 1,
        ciclesCompletats: Number(d.completedCycles) || 0,
        programaCompletat: d.programCompleted === true
      },
      questionari: {
        data: dataQ,
        puntGlobal: totalQ,
        escala: 100,
        respostes: {
          alimentacio: pctCat('Nutrició i hidratació'),
          recuperacio: pctCat('Recuperació muscular'),
          son: pctCat('Son i descans'),
          hidratacio: pctCat('Nutrició i hidratació'),
          gestioEmocional: pctCat('Salut mental i benestar')
        }
      },
      progresDiari: {
        data: dataProgres,
        dinars: { completats: nMenjars, total: 4 },
        entrenament: {
          completat: !!diaAvui.completed,
          intensitat: (function () { var m = intensitatMitjana(diaAvui); return m !== null ? Math.round(m) : null; })(),
          minuts: (diaAvui.completedStages || []).length * 15
        },
        son: { hores: sonHores, qualitat: sonQualitat },
        emocions: { escala: emoEscala !== null ? emoEscala : '—', estat: emoEstat }
      },
      historial: historial,
      recompenses: {
        racha: Number(d.streakCount) || 0,
        rachaMaxima: rachaMax,
        punts: (d.coins !== undefined && d.coins !== null) ? d.coins : 0,
        nivell: String((d.level !== undefined && d.level !== null) ? d.level : 0),
        proximaRecompensa: 'Nivell ' + ((Number(d.level) || 0) + 1) + ' a la vista',
        insignies: Array.isArray(d.ownedItems) ? d.ownedItems : []
      }
    };
  }

  /* ------------------------------------------------------------------------
     Icones (SVG en línia, cap biblioteca externa)
     ------------------------------------------------------------------------ */

  var ICONES = {
    activity: 'M3 12h4l3 8 4-16 3 8h4',
    check: 'M20 6L9 17l-5-5',
    moon: 'M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z',
    flame: 'M12 2c3 4 5 6.5 5 10.5a5 5 0 01-10 0c0-2 1-3.2 2-4.2 0 1.8 1 2.8 1.8 2.8C12 8 12 5 12 2z',
    /* Plat amb inici: dos subtraçats en un sol path. */
    plate: 'M12 3a9 9 0 100 18 9 9 0 000-18zM12 8.5a3.5 3.5 0 100 7 3.5 3.5 0 000-7z'
  };

  function svgIcon(nom) {
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');

    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', ICONES[nom] || ICONES.activity);
    svg.appendChild(path);
    return svg;
  }

  /* ------------------------------------------------------------------------
     Peces de presentació
     ------------------------------------------------------------------------ */

  /* Targeta d'indicador: etiqueta, icona, valor, variació i enllaç al detall.
     Si `delta` és null es mostra només el text comparatiu, sense percentual
     inventat. */
  function targetaKpi(etiqueta, valor, unitat, icona, delta, comparacio, enllaç) {
    var box = el('div', 'kpi');

    var cap = el('div', 'kpi__top');
    afegeix(cap, 'span', 'kpi__label', etiqueta);
    var iconaBox = el('div', 'kpi__icon');
    iconaBox.appendChild(svgIcon(icona));
    cap.appendChild(iconaBox);
    box.appendChild(cap);

    var valorBox = el('div', 'kpi__value', valor);
    if (unitat) {
      var petit = el('small', null, unitat);
      valorBox.appendChild(document.createTextNode(' '));
      valorBox.appendChild(petit);
    }
    box.appendChild(valorBox);

    var peu = el('div', 'kpi__foot');
    var deltaBox = el('span', 'kpi__delta');

    if (delta === null || delta === undefined) {
      deltaBox.appendChild(el('span', null, comparacio || ''));
    } else {
      var classe = delta > 0 ? '' : (delta < 0 ? ' is-down' : ' is-flat');
      var xifra = el('b', classe.trim() || null);
      xifra.textContent = (delta > 0 ? '+' : '') + delta + '%';
      deltaBox.appendChild(xifra);
      deltaBox.appendChild(el('span', null, comparacio || ''));
    }
    peu.appendChild(deltaBox);

    var detall = el('a', 'kpi__link', 'Detalls ↗');
    detall.href = enllaç || '#grafic';
    peu.appendChild(detall);
    box.appendChild(peu);

    return box;
  }

  /* Gràfic de columnes amb dues sèries. `seriesA` i `seriesB` són arrays de
     números de la mateixa longitud que `etiquetes`. */
  function buildChart(titol, subtitol, etiquetes, seriesA, nomA, seriesB, nomB) {
    var panel = el('section', 'panel');
    panel.id = 'grafic';

    var cap = el('div', 'panel__head');
    var t = el('div');
    afegeix(t, 'h2', 'panel__title', titol);
    if (subtitol) afegeix(t, 'p', 'panel__sub', subtitol);
    cap.appendChild(t);
    panel.appendChild(cap);

    var llegenda = el('div', 'chart__legend');
    [[nomA, ''], [nomB, ' chart__dot--alt']].forEach(function (par) {
      var item = el('span', 'chart__legend-item');
      item.appendChild(el('span', 'chart__dot' + par[1]));
      item.appendChild(el('span', null, par[0]));
      llegenda.appendChild(item);
    });
    panel.appendChild(llegenda);

    var grafic = el('div', 'chart');

    /* Eix vertical: cinc marques equiespaciades, que és el que marca el fons. */
    var eixY = el('div', 'chart__yaxis');
    for (var i = 4; i >= 0; i--) {
      afegeix(eixY, 'span', null, coma(ESCALA_GRAFIC * i / 4, i % 2 === 0 ? 0 : 1));
    }
    grafic.appendChild(eixY);

    var plot = el('div', 'chart__plot');
    var columnes = el('div', 'chart__cols');

    etiquetes.forEach(function (etiqueta, index) {
      var col = el('div', 'chart__col');

      var altA = percentatge(seriesA[index], ESCALA_GRAFIC);
      var altB = percentatge(seriesB[index], ESCALA_GRAFIC);

      var barraA = el('div', 'chart__bar');
      barraA.style.height = Math.max(altA, 1) + '%';
      col.appendChild(barraA);

      var barraB = el('div', 'chart__bar chart__bar--alt');
      barraB.style.height = Math.max(altB, 1) + '%';
      col.appendChild(barraB);

      var tip = el('div', 'chart__tip');
      /* Les columnes dels extremos anclen el requadre cap dins, perquè no
         surti del panell ni faci créixer la pàgina en horitzontal. */
      if (index === 0) tip.classList.add('chart__tip--inicio');
      if (index === etiquetes.length - 1) tip.classList.add('chart__tip--final');
      afegeix(tip, 'b', null, dataCurta(etiqueta));
      tip.appendChild(document.createElement('br'));
      tip.appendChild(el('span', null, nomA + ': '));
      tip.appendChild(el('b', null, coma(seriesA[index]) + '/' + ESCALA_GRAFIC));
      tip.appendChild(document.createElement('br'));
      tip.appendChild(el('span', null, nomB + ': '));
      tip.appendChild(el('b', null, coma(seriesB[index]) + ' h'));
      col.appendChild(tip);

      columnes.appendChild(col);
    });

    plot.appendChild(columnes);
    grafic.appendChild(plot);
    panel.appendChild(grafic);

    var eixX = el('div', 'chart__xaxis');
    etiquetes.forEach(function (etiqueta) {
      afegeix(eixX, 'span', null, diaDelMes(etiqueta));
    });
    panel.appendChild(eixX);

    return panel;
  }

  /* Barra amb etiqueta i valor. `pct` és 0-100 i `modul` és la classe de
     color, que es posa sobre la part omplerta. */
  function barra(etiqueta, valor, pct, modul) {
    var fila = el('div', 'bar');

    var cap = el('div', 'bar__head');
    afegeix(cap, 'span', 'bar__label', etiqueta);
    afegeix(cap, 'span', 'bar__value', valor);
    fila.appendChild(cap);

    var pista = el('div', 'bar__track');
    var interior = el('div', 'bar__fill' + (modul ? ' ' + modul : ''));
    interior.style.width = pct + '%';
    pista.appendChild(interior);
    fila.appendChild(pista);

    return fila;
  }

  /* Classe de color segons el percentatge: vermell si és baix, ambre si és
     mitjà, verd si és alt. */
  function modulPct(pct) {
    if (pct < 50) return 'is-low';
    if (pct < 75) return 'is-mid';
    return 'is-high';
  }

  /* Franja dels darrers dies dins de la fitxa. */
  function franja(setmana, clau, max, etiqueta) {
    if (!Array.isArray(setmana) || !setmana.length) return null;

    var box = el('div', 'spark');
    afegeix(box, 'span', 'spark__title', etiqueta + ' (darrers ' + setmana.length + ' dies)');

    var graella = el('div', 'spark__grid');
    graella.style.setProperty('--cols', String(setmana.length));

    setmana.forEach(function (dia) {
      var valor = dia[clau];
      var pct = percentatge(valor, max);

      var columna = el('div', 'spark__col');
      var pista = el('div', 'spark__track');
      var interior = el('div', 'spark__fill ' + modulPct(pct));
      interior.style.height = Math.max(pct, 4) + '%';
      pista.appendChild(interior);
      columna.appendChild(pista);

      afegeix(columna, 'span', 'spark__value', coma(valor, valor % 1 === 0 ? 0 : 1));
      afegeix(columna, 'span', 'spark__day', diaDelMes(dia.data));

      columna.title = dataCurta(dia.data) + ' · ' + etiqueta.toLowerCase() + ': ' + valor;
      graella.appendChild(columna);
    });

    box.appendChild(graella);
    return box;
  }

  /* Pila d'insígnies. */
  function pills(valors) {
    var fila = el('div', 'pills');
    (valors || []).forEach(function (valor) {
      afegeix(fila, 'span', 'pill', valor);
    });
    if (!fila.childNodes.length) {
      afegeix(fila, 'span', 'pill pill--buit', 'Cap insígnia');
    }
    return fila;
  }

  /* Fila de dada-etiqueta dins d'un panell. */
  function filaDada(etiqueta, valor) {
    var fila = el('div', 'data');
    afegeix(fila, 'span', 'data__label', etiqueta);
    afegeix(fila, 'span', 'data__value', valor);
    return fila;
  }

  function seccion(titol) {
    var sec = el('section', 'panel');
    afegeix(sec, 'h2', 'panel__title panel__title--section', titol);
    return sec;
  }

  /* ------------------------------------------------------------------------
     Rail lateral de navegació
     ------------------------------------------------------------------------ */

  function buildRail(dades, actiu) {
    var rail = document.getElementById('side-list');
    if (!rail) return;
    rail.textContent = '';

    function item(hash, avatar, nom, sub, actiuAquest) {
      var li = el('li');
      var enllaç = el('a', 'side__item' + (actiuAquest ? ' is-active' : ''));
      enllaç.href = hash;
      if (actiuAquest) enllaç.setAttribute('aria-current', 'page');

      var cercle = el('span', 'side__avatar');
      cercle.textContent = avatar;
      enllaç.appendChild(cercle);

      var id = el('span', 'side__id');
      afegeix(id, 'span', 'side__name', nom);
      afegeix(id, 'span', 'side__sub', sub);
      enllaç.appendChild(id);
      li.appendChild(enllaç);
      rail.appendChild(li);
    }

    dades.forEach(function (alumne) {
      item(
        '#estudiant/' + alumne.username,
        inicials(alumne),
        nomVisible(alumne),
        subRail(alumne),
        actiu === alumne.username
      );
    });
  }

  /* ------------------------------------------------------------------------
     Vista de fitxa (un alumne)
     ------------------------------------------------------------------------ */

  /* Fitxa d'un alumne que encara no ha sincronitzat. Es manté la capçalera
     amb el seu nom (és el que el professor ha de veure al rail) i s'explica
     què falta, en lloc de pintar indicadors a zero que semblin dades. */
  function buildFitxaSenseDades(alumne) {
    var frag = document.createDocumentFragment();

    var cap = el('div', 'main__head');
    afegeix(cap, 'h1', 'main__title', nomVisible(alumne));
    afegeix(cap, 'p', 'main__sub',
      alumne.problema === 'error'
        ? 'No s\'ha pogut llegir ' + alumne.username + '.json'
        : 'Encara no ha sincronitzat');
    frag.appendChild(cap);

    var box = el('div', 'state');
    afegeix(box, 'h2', 'state__title',
      alumne.problema === 'error' ? 'No s\'han pogut carregar les dades' : 'Encara no hi ha dades');
    afegeix(box, 'p', 'state__text', alumne.problema === 'error'
      ? 'El fitxer ' + alumne.username + '.json no s\'ha pogut llegir del repositori. ' +
        'Torna a provar-ho més tard.'
      : 'Aquest alumne no ha sincronitzat mai, així que encara no existeix el fitxer ' +
        alumne.username + '.json. La fila apareixerà igual aquí i s\'omplirà sola ' +
        'quan l\'APP del noi faci el primer sync.');
    frag.appendChild(box);
    return frag;
  }

  function buildFitxa(alumne) {
    if (alumne.senseDades) return buildFitxaSenseDades(alumne);
    var frag = document.createDocumentFragment();
    var perfil = alumne.perfil || {};
    var pla = alumne.pla || {};
    var questionari = alumne.questionari || {};
    var diari = alumne.progresDiari || {};
    var dinars = diari.dinars || {};
    var entrenament = diari.entrenament || {};
    var son = diari.son || {};
    var emocions = diari.emocions || {};
    var recompenses = alumne.recompenses || {};

    /* Capçalera */
    var cap = el('div', 'main__head');
    afegeix(cap, 'h1', 'main__title', nomVisible(alumne));
    /* Les dades iOS no sempre porten equip/dorsal: s'amaguen els buits
       (i els '—') en comptes de pintar «Dorsal null». */
    var subParts = [perfil.equip, perfil.categoria,
      (perfil.dorsal !== null && perfil.dorsal !== undefined) ? 'Dorsal ' + perfil.dorsal : null,
      perfil.posicio].filter(function (x) { return x && x !== '—'; });
    afegeix(cap, 'p', 'main__sub', subParts.length ? subParts.join(' · ') : '—');
    frag.appendChild(cap);

    /* Indicadors personals */
    var historial = alumne.historial || [];
    var intensitat = historial.map(function (d) { return d.intensitat; });
    var sonSerie = historial.map(function (d) { return d.horesSon; });
    var dinarsSerie = historial.map(function (d) { return d.dinarsCompletats; });

    var intensitatAra = mitjana(intensitat.slice(-MEITAT));
    var sonAra = mitjana(sonSerie.slice(-MEITAT));
    var dinarsAra = mitjana(dinarsSerie.slice(-MEITAT));

    var kpis = el('div', 'kpis');
    kpis.appendChild(targetaKpi('Intensitat mitjana', coma(intensitatAra), '/10', 'activity',
      variacio(intensitatAra, mitjana(intensitat.slice(-2 * MEITAT, -MEITAT))), COMPARACIO, '#grafic'));
    kpis.appendChild(targetaKpi('Son mitjà', coma(sonAra), 'h', 'moon',
      variacio(sonAra, mitjana(sonSerie.slice(-2 * MEITAT, -MEITAT))), COMPARACIO, '#grafic'));
    kpis.appendChild(targetaKpi('Àpats per dia', coma(dinarsAra), '/4', 'plate',
      variacio(dinarsAra, mitjana(dinarsSerie.slice(-2 * MEITAT, -MEITAT))), COMPARACIO, '#grafic'));
    kpis.appendChild(targetaKpi('Punts', String(recompenses.punts != null ? recompenses.punts : 0), '',
      'check', null, recompenses.nivell ? 'Nivell ' + recompenses.nivell : '', '#racha'));
    frag.appendChild(kpis);

    /* Gràfic propi */
    frag.appendChild(buildChart(
      'Progrés d\'intensitat i de son',
      historial.length ? 'Darrers ' + historial.length + ' dies' : 'Sense historial',
      historial.map(function (d) { return d.data; }),
      intensitat, 'Intensitat', sonSerie, 'Son'
    ));

    /* Seccions. «Progrés diari» ocupa tota l'amplada perquè és molt més alt
       que la resta: si compartís fila amb elles, els altres panells quedarien
       amb un forat buit enorme a sota. */
    var graella = el('div', 'grid grid--pair');

    var s4 = seccion('Progrés diari');
    s4.classList.add('panel--full');
    afegeix(s4, 'p', 'panel__text', 'Dades del ' + dataCurta(diari.data) + '.');

    var dades4 = el('div', 'data-grid');
    dades4.appendChild(filaDada('Entrenament', entrenament.completat
      ? 'Completat · ' + entrenament.minuts + ' min' : 'No completat'));
    dades4.appendChild(filaDada('Intensitat', (entrenament.intensitat != null ? entrenament.intensitat : '—') + '/10'));
    dades4.appendChild(filaDada('Àpats registrats', (dinars.completats != null ? dinars.completats : '—') + '/' + (dinars.total != null ? dinars.total : '—')));
    dades4.appendChild(filaDada('Emocions', (emocions.estat || '—') + ' (' + (emocions.escala != null ? emocions.escala : '—') + '/10)'));
    s4.appendChild(dades4);

    var pctDinars = percentatge(dinars.completats, dinars.total);
    s4.appendChild(barra('Àpats completats',
      (dinars.completats != null ? dinars.completats : 0) + '/' + (dinars.total != null ? dinars.total : 0),
      pctDinars, modulPct(pctDinars)));

    if (typeof son.hores === 'number') {
      var pctSon = percentatge(son.hores, 10);
      s4.appendChild(barra('Hores de son', coma(son.hores) + ' h', pctSon, modulPct(pctSon)));
    }
    if (typeof son.qualitat === 'number') {
      var pctQ = percentatge(son.qualitat, 5);
      s4.appendChild(barra('Qualitat del son',
        (QUALITAT_SON[son.qualitat - 1] || '—') + ' (' + son.qualitat + '/5)', pctQ, modulPct(pctQ)));
    }

    var fr1 = franja(historial, 'intensitat', 10, 'Intensitat');
    if (fr1) s4.appendChild(fr1);
    var fr2 = franja(historial, 'horesSon', 10, 'Son');
    if (fr2) s4.appendChild(fr2);

    var s1 = seccion('Perfil i esport');
    var dades1 = el('div', 'data-grid');
    dades1.appendChild(filaDada('Edat', perfil.edat != null ? perfil.edat + ' anys' : '—'));
    dades1.appendChild(filaDada('Posició', perfil.posicio || '—'));
    dades1.appendChild(filaDada('Dorsal', perfil.dorsal != null ? '#' + perfil.dorsal : '—'));
    dades1.appendChild(filaDada('Altura', perfil.alturaCm != null ? perfil.alturaCm + ' cm' : '—'));
    dades1.appendChild(filaDada('Pes', perfil.pesoKg != null ? coma(perfil.pesoKg) + ' kg' : '—'));
    dades1.appendChild(filaDada('Alta al club', dataCurta(perfil.dataAlta)));
    s1.appendChild(dades1);

    var s2 = seccion('Pla actual');
    afegeix(s2, 'p', 'panel__lead', pla.nom || 'Sense pla assignat');
    if (pla.objectiu) afegeix(s2, 'p', 'panel__text', pla.objectiu);
    var dades2 = el('div', 'data-grid');
    dades2.appendChild(filaDada('Fase', pla.fase || '—'));
    dades2.appendChild(filaDada('Sessions per setmana', pla.sessionsSetmanal != null ? String(pla.sessionsSetmanal) : '—'));
    dades2.appendChild(filaDada('Inici', dataCurta(pla.dataInici)));
    dades2.appendChild(filaDada('Revisió', dataCurta(pla.dataRevisio)));
    dades2.appendChild(filaDada('Cicle', (pla.cicle || 1) +
      (pla.ciclesCompletats ? ' · ' + pla.ciclesCompletats + ' completats' : '')));
    dades2.appendChild(filaDada('Programa', pla.programaCompletat ? 'Completat' : 'En curs'));
    s2.appendChild(dades2);

    var escala = questionari.escala || 100;
    var s3 = seccion('Qüestionari');
    var capQ = el('div', 'panel__head');
    var tQ = el('div');
    afegeix(tQ, 'span', 'panel__lead', 'Puntuació global');
    capQ.appendChild(tQ);
    afegeix(capQ, 'span', 'panel__big', (questionari.puntGlobal != null ? questionari.puntGlobal : '—') + '/' + escala);
    s3.appendChild(capQ);
    afegeix(s3, 'p', 'panel__text', 'Respostes del ' + dataCurta(questionari.data) + '.');

    var respostes = questionari.respostes || {};
    PREGUNTES.forEach(function (par) {
      var valor = respostes[par[0]];
      if (typeof valor !== 'number') return;
      var pct = percentatge(valor, escala);
      s3.appendChild(barra(par[1], valor + '/' + escala, pct, modulPct(pct)));
    });

    var s5 = seccion('Racha i recompenses');
    s5.id = 'racha';
    var racha = recompenses.racha != null ? recompenses.racha : 0;
    var capR = el('div', 'panel__head');
    var tR = el('div');
    afegeix(tR, 'span', 'panel__lead', 'Dies seguits');
    capR.appendChild(tR);
    afegeix(capR, 'span', 'panel__big' + (racha === 0 ? ' is-zero' : ''),
      racha + ' / ' + (recompenses.rachaMaxima != null ? recompenses.rachaMaxima : '—'));
    s5.appendChild(capR);
    if (racha === 0) {
      afegeix(s5, 'p', 'panel__text', 'Avui no encadena cap dia. El registre més llarg és de ' +
        (recompenses.rachaMaxima != null ? recompenses.rachaMaxima : 0) + ' dies.');
    }

    var dades5 = el('div', 'data-grid');
    dades5.appendChild(filaDada('Punts', recompenses.punts != null ? String(recompenses.punts) : '—'));
    dades5.appendChild(filaDada('Nivell', recompenses.nivell || '—'));
    dades5.appendChild(filaDada('Propera recompensa', recompenses.proximaRecompensa || '—'));
    s5.appendChild(dades5);

    var sub = el('h3', 'panel__lead panel__subhead', 'Insígnies');
    s5.appendChild(sub);
    s5.appendChild(pills(recompenses.insignies));

    /* L'ordre següent evita files amb alçades molt diferents: el progrés
       diari sol, i després les parelles de panels similars. */
    graella.appendChild(s4);
    graella.appendChild(s1);
    graella.appendChild(s2);
    graella.appendChild(s3);
    graella.appendChild(s5);

    frag.appendChild(graella);
    return frag;
  }

  /* ------------------------------------------------------------------------
     Ajustos manuals: editor de les dades d'un alumne
     ------------------------------------------------------------------------ */

  /* Panell plegable per editar el fitxer de l'alumne. `alDesar(slug, overrides)`
     torna una promesa amb { error } o { ok, revisio }. */
  function buildEditor(slug, raw, alDesar) {
    if (!raw) return null;
    var dades = raw || {};

    /* Contingut del panell d'ajustos: es dibuixa dins la barra inferior
       (sheet) quan es prem el botó «Ajustos manuals» de la capçalera. */
    var detalls = el('div', 'editor');
    detalls.id = 'edicio';

    var cos = el('div', 'editor__cos');

    /* Token de GitHub. */
    var tokenFila = el('div', 'editor__token');
    var tokenCamp = el('input', 'input-field editor__token-input');
    tokenCamp.type = 'password';
    tokenCamp.placeholder = 'Token de GitHub (PAT)';
    tokenCamp.autocomplete = 'off';
    tokenCamp.value = llegeixToken();
    tokenFila.appendChild(tokenCamp);

    var estatToken = el('span', 'editor__token-estat');
    function avisaToken() {
      var hi = tokenCamp.value.trim() !== '';
      estatToken.textContent = hi
        ? 'Token desat només en aquest navegador'
        : 'Sense token: la fitxa és de només lectura';
      estatToken.classList.toggle('is-buit', !hi);
    }

    var botoToken = el('button', 'btn-outline btn-outline--sm', 'Desa el token');
    botoToken.type = 'button';
    botoToken.addEventListener('click', function () {
      desaToken(tokenCamp.value.trim());
      avisaToken();
      pintaMissatge(false, tokenCamp.value.trim()
        ? 'Token desat. Ja pots desar canvis.'
        : 'Token esborrat.');
    });
    tokenFila.appendChild(botoToken);

    var botoNeteja = el('button', 'btn-outline btn-outline--sm', 'Esborra');
    botoNeteja.type = 'button';
    botoNeteja.addEventListener('click', function () {
      esborraToken();
      tokenCamp.value = '';
      avisaToken();
      pintaMissatge(false, 'Token esborrat.');
    });
    tokenFila.appendChild(botoNeteja);

    cos.appendChild(tokenFila);
    cos.appendChild(estatToken);
    avisaToken();

    /* Resum del que hi ha ara a l'APP, perquè sigui clar què es canvia. */
    var resumActual = el('div', 'editor__resum');
    afegeix(resumActual, 'h3', 'editor__resum-titol', 'Estat actual a l\'APP');
    var resumLinies = el('div', 'editor__resum-llista');
    function linia(etiqueta, valor) {
      var fila = el('div', 'editor__resum-fila');
      afegeix(fila, 'span', 'editor__resum-etiqueta', etiqueta);
      afegeix(fila, 'span', 'editor__resum-valor', valor);
      return fila;
    }
    var sport = dades.sport === 'Basquet' ? 'Bàsquet' : 'Futbol';
    var plaNum = (dades.assignedPlanPerSport || {})[dades.sport || 'Futbol'] || dades.assignedPlan || 1;
    var diaPla = diaDelPla(dades.planStartDate);
    var diesFets = (Array.isArray(dades.days) ? dades.days : []).filter(function (dy) { return dy && dy.completed; }).length;
    var ratxa = Number(dades.streakCount) || 0;
    var cicle = Number(dades.cycleNumber) >= 1 ? dades.cycleNumber : 1;
    var compl = Number(dades.completedCycles) || 0;
    resumLinies.appendChild(linia('Esport', sport));
    resumLinies.appendChild(linia('Pla', plaNum + ' de 4'));
    resumLinies.appendChild(linia('Dia del pla', diaPla > 14 ? String(diaPla) : diaPla + ' de 14'));
    resumLinies.appendChild(linia('Cicle', cicle + ' · ' + compl + ' completats'));
    resumLinies.appendChild(linia('Dies completats', diesFets + ' de 14'));
    resumLinies.appendChild(linia('Ratxa', ratxa + ' dies'));
    resumLinies.appendChild(linia('Punts', (dades.coins !== undefined && dades.coins !== null) ? dades.coins : 500));
    resumLinies.appendChild(linia('Qüestionari', dades.questionnaireCompleted ? 'Completat' : 'Pendent'));
    resumLinies.appendChild(linia('Programa', dades.programCompleted === true ? 'Completat' : 'En curs'));
    resumActual.appendChild(resumLinies);
    cos.appendChild(resumActual);


    /* Formulari. */
    var formulari = el('div', 'editor__form');

    function camp(etiqueta, node) {
      var box = el('label', 'editor__camp');
      afegeix(box, 'span', 'editor__etiqueta', etiqueta);
      box.appendChild(node);
      return box;
    }

    function input(nom, tipus, valor, extra) {
      var i = el('input', 'input-field');
      i.name = nom;
      i.type = tipus;
      if (valor !== undefined && valor !== null) i.value = String(valor);
      if (extra) Object.keys(extra).forEach(function (k) { i.setAttribute(k, extra[k]); });
      return i;
    }

    function casella(nom, text, marcat) {
      var l = el('label', 'editor__casella');
      var c = el('input');
      c.type = 'checkbox';
      c.name = nom;
      c.checked = !!marcat;
      l.appendChild(c);
      l.appendChild(el('span', null, text));
      return { fila: l, input: c };
    }

    var esport = el('select', 'input-field');
    esport.name = 'sport';
    [['Futbol', 'Futbol'], ['Basquet', 'Bàsquet']].forEach(function (par) {
      var o = el('option', null, par[1]);
      o.value = par[0];
      esport.appendChild(o);
    });
    esport.value = dades.sport === 'Basquet' ? 'Basquet' : 'Futbol';

    var pla = input('planNumber', 'number', (dades.assignedPlanPerSport || {})[esport.value] ||
      dades.assignedPlan || 1, { min: '1', max: '4', step: '1' });
    /* Camps senzills: l'admin pensa en dies, no en dates. El dia i la ratxa
       es tradueixen al format de l'APP (data d'inici i dates de ratxa) en desar. */
    var dia = input('dayNumber', 'number', diaPla, { min: '1', max: '99', step: '1' });
    var ratxaDies = input('streakDays', 'number', ratxa, { min: '0', max: '400', step: '1' });
    var cicle = input('cycleNumber', 'number', Number(dades.cycleNumber) >= 1 ? dades.cycleNumber : 1,
      { min: '1', step: '1' });
    var completats = input('completedCycles', 'number', Number(dades.completedCycles) || 0,
      { min: '0', step: '1' });
    var punts = input('coins', 'number',
      (dades.coins !== undefined && dades.coins !== null) ? dades.coins : 500,
      { min: '0', step: '1' });

    formulari.appendChild(camp('Esport (app)', esport));
    formulari.appendChild(camp('Pla (1-4)', pla));
    afegeix(formulari, 'p', 'editor__ajuda', 'El número de pla que l\'APP li mostrarà. 1 = bàsic, 4 = avançat.');
    formulari.appendChild(camp('Dia actual del pla', dia));
    afegeix(formulari, 'p', 'editor__ajuda', 'Avui comptarà com aquest dia del pla (1-14). Posa 1 perquè torni a començar avui.');
    formulari.appendChild(camp('Dies de ratxa', ratxaDies));
    afegeix(formulari, 'p', 'editor__ajuda', 'Quants dies seguits amb activitat vols que tingui, comptats des d\'avui cap enrere. 0 = sense ratxa.');
    formulari.appendChild(camp('Punts (coins)', punts));

    var qCompletat = casella('questionnaireCompleted', 'Qüestionari completat',
      dades.questionnaireCompleted);
    formulari.appendChild(qCompletat.fila);

    var dies = el('fieldset', 'editor__dies-camp');
    afegeix(dies, 'legend', 'editor__etiqueta', 'Dies completats');
    var diesGrid = el('div', 'editor__dies');
    var perDia = {};
    for (var n = 1; n <= 14; n++) {
      var diaDades = null;
      (Array.isArray(dades.days) ? dades.days : []).forEach(function (dy) {
        if (dy && dy.day === n) diaDades = dy;
      });
      var c = casella('dia' + n, 'Dia ' + n, diaDades && diaDades.completed);
      perDia[n] = c.input;
      diesGrid.appendChild(c.fila);
    }
    dies.appendChild(diesGrid);
    formulari.appendChild(dies);

    /* Els camps poc habituals queden plegats perquè el formulari sigui clar. */
    var avancat = el('details', 'editor__avancat');
    afegeix(avancat, 'summary', 'editor__avancat-resum', 'Opcions avançades del cicle');
    var avancatForm = el('div', 'editor__form');
    avancatForm.appendChild(camp('Cicle actual', cicle));
    avancatForm.appendChild(camp('Cicles completats', completats));
    afegeix(avancatForm, 'p', 'editor__ajuda', 'Quants plans de 14 dies ha acabat. 0-3 = segueix; 4 = programa acabat.');
    var programa = casella('programCompleted', 'Programa completat', dades.programCompleted === true);
    avancatForm.appendChild(programa.fila);
    avancat.appendChild(avancatForm);
    formulari.appendChild(avancat);

    var peu = el('div', 'editor__peu');
    var botoDesa = el('button', 'editor__desa', 'Desa els canvis');
    botoDesa.type = 'button';
    peu.appendChild(botoDesa);

    var msg = el('p', 'editor__msg');
    msg.hidden = true;
    peu.appendChild(msg);
    formulari.appendChild(peu);

    function pintaMissatge(esError, text) {
      msg.hidden = false;
      msg.classList.toggle('is-error', !!esError);
      msg.classList.toggle('is-ok', !esError);
      msg.textContent = text;
    }

    function numValid(camp_, nom, min, max) {
      var brut = camp_.value.trim();
      if (brut === '') return null;
      var v = Number(brut);
      if (!isFinite(v) || v % 1 !== 0 || v < min || (max !== undefined && v > max)) {
        throw new Error('El camp «' + nom + '» ha de ser un nombre enter' +
          (max !== undefined ? ' entre ' + min + ' i ' + max : ' ≥ ' + min) + '.');
      }
      return v;
    }

    function construeixOverrides() {
      var overrides = {
        sport: esport.value,
        questionnaireCompleted: qCompletat.input.checked,
        programCompleted: programa.input.checked,
        days: {}
      };
      for (var d = 1; d <= 14; d++) {
        overrides.days[String(d)] = { completed: !!perDia[d].checked };
      }
      var vPla = numValid(pla, 'Pla', 1, 4);
      if (vPla !== null) overrides.planNumber = vPla;
      /* El dia i la ratxa només es toquen si l'admin els ha canviat: si no,
         es respecta el que ja tenia l'alumne. */
      var vDia = numValid(dia, 'Dia actual', 1, 99);
      if (vDia !== null && vDia !== diaPla) overrides.planStartDate = iniciPerDia(vDia);
      var vRatxa = numValid(ratxaDies, 'Dies de ratxa', 0, 400);
      if (vRatxa !== null && vRatxa !== ratxa) {
        overrides.streakCompletedDates = diesDeRatxa(vRatxa);
      }
      var vCicle = numValid(cicle, 'Cicle', 1);
      if (vCicle !== null) overrides.cycleNumber = vCicle;
      var vCompletats = numValid(completats, 'Cicles completats', 0);
      if (vCompletats !== null) overrides.completedCycles = vCompletats;
      var vPunts = numValid(punts, 'Punts', 0);
      if (vPunts !== null) overrides.coins = vPunts;
      return overrides;
    }

    botoDesa.addEventListener('click', function () {
      var overrides;
      try {
        overrides = construeixOverrides();
      } catch (err) {
        pintaMissatge(true, err.message);
        return;
      }
      if (!llegeixToken()) {
        pintaMissatge(true, 'Escriu i desa primer el token de GitHub.');
        tokenCamp.focus();
        return;
      }
      botoDesa.disabled = true;
      pintaMissatge(false, 'Desant…');
      alDesar(slug, overrides).then(function (r) {
        botoDesa.disabled = false;
        if (r && r.error) {
          pintaMissatge(true, r.error);
          return;
        }
        pintaMissatge(false, 'Canvis desats al repositori' +
          (r && r.revisio ? ' (revisió ' + r.revisio + ')' : '') +
          '. S\'aplicaran quan l\'APP de l\'alumne s\'obri o faci sync.');
      });
    });

    if (editorMissatge) {
      pintaMissatge(!editorMissatge.ok, editorMissatge.text);
      editorMissatge = null;
    }

    cos.appendChild(formulari);

    var nota = 'Aquests canvis s\'escriuran al fitxer de l\'alumne al repositori. ' +
      'L\'APP els aplicarà quan s\'obri o torni a primer pla (sense reinstal·lar). ' +
      'Els camps que no canviïs es queden com estan. ' +
      'Si baixes el dia actual, desmarca els dies que quedin per davant.';
    if (dades.adminRevision) {
      nota += ' Última edició manual: ' + dades.adminRevision + '.';
    }
    afegeix(cos, 'p', 'editor__nota', nota);

    detalls.appendChild(cos);
    return detalls;
  }

  /* ------------------------------------------------------------------------
     Estats de la consola
     ------------------------------------------------------------------------ */

  function estatCarregant(arrel) {
    var box = el('div', 'state');
    box.setAttribute('role', 'status');
    box.appendChild(el('div', 'spinner'));
    afegeix(box, 'p', 'state__title', 'Carregant les dades dels alumnes…');
    arrel.appendChild(box);
  }

  function estatBuit(arrel, detalls, alRetry) {
    var box = el('div', 'state');
    box.appendChild(el('h2', 'state__title', 'Encara no hi ha dades'));
    afegeix(box, 'p', 'state__text',
      'La consola no ha trobat cap fitxer de dades. Per veure alumnes, ' +
      'crea els fitxers JSON a la carpeta users/ i afegeix el nom del fitxer ' +
      'a la llista CONFIG.alumnes de assets/js/dashboard.js.');
    if (detalls && detalls.length) {
      var llista = el('ul', 'state__list');
      detalls.forEach(function (d) { afegeix(llista, 'li', null, d); });
      box.appendChild(llista);
    }
    box.appendChild(botRetry(alRetry));
    arrel.appendChild(box);
    return box;
  }

  /* `accio` és el botó o enllaç que tanca l'estat. Si no se'n passa cap, es
     posa el botó de reintent amb la càrrega de l'emissor. */
  function estatError(arrel, missatge, detalls, accio) {
    var box = el('div', 'state state--error');
    box.setAttribute('role', 'alert');
    box.appendChild(el('h2', 'state__title', 'No s\'han pogut carregar les dades'));
    afegeix(box, 'p', 'state__text', missatge);
    if (detalls && detalls.length) {
      var llista = el('ul', 'state__list');
      detalls.forEach(function (d) { afegeix(llista, 'li', null, d); });
      box.appendChild(llista);
    }
    box.appendChild(accio || botRetry());
    arrel.appendChild(box);
    return box;
  }

  /* Botó de reintent. Rep la funció de càrrega perquè aquestes funcions
     viuen fora de muntaConsola i no tenen accés a 'carrega' directament. */
  function botRetry(alRetry) {
    var b = el('button', 'btn-outline', 'Torna a provar');
    b.type = 'button';
    b.addEventListener('click', function () {
      if (typeof alRetry === 'function') alRetry();
    });
    return b;
  }

  /* ------------------------------------------------------------------------
     Muntatge de la consola (dashboard.html)
     ------------------------------------------------------------------------ */

  function muntaConsola(arrel) {
    if (!arrel) return;

    var sessio = sessioOberta();
    if (!sessio) {
      /* Sense sessió no es mostra cap dada: es torna a la pantalla
         d'inici de sessió. */
      window.location.replace('index.html#consola');
      return;
    }

    /* Capçalera: només el botó de sortida. L'usuari no s'hi mostra perquè
       la consola és una vista d'una sola pàgina i el nom ocupa espai que no
       fa falta. */
    var cap = document.getElementById('session-box');
    var botoAjustos = null;
    if (cap) {
      botoAjustos = el('button', 'btn-outline btn-outline--sm', 'Ajustos manuals');
      botoAjustos.type = 'button';
      botoAjustos.addEventListener('click', function () {
        if (sheetObert) {
          tancaSheet();
          return;
        }
        var alumne = alumneMostrat();
        if (!alumne || !rawPerAlumne[alumne.username]) return;
        obreSheet(alumne.username);
      });
      cap.appendChild(botoAjustos);

      var sortida = el('button', 'btn-outline btn-outline--sm', 'Tancar sessió');
      sortida.type = 'button';
      sortida.addEventListener('click', function () {
        tancaSessio();
        window.location.replace('index.html#consola');
      });
      cap.appendChild(sortida);
    }

    /* Barra inferior (sheet) amb l'editor d'ajustos. És un element fixat
       al cos de la pàgina, fora de la fitxa: mai no se'n modifiquen les
       dades. Es constrúix un cop i cada aperició l'omple amb les dades de
       l'alumne actiu. */
    var sheetObert = false;
    var sheetFons = el('div', 'sheet-backdrop');
    sheetFons.hidden = true;
    var sheet = el('section', 'sheet');
    sheet.hidden = true;
    var sheetCap = el('div', 'sheet__head');
    var sheetCapTxt = el('div');
    var sheetTitol = el('h2', 'sheet__title', 'Ajustos manuals');
    var sheetSub = el('p', 'sheet__sub');
    sheetCapTxt.appendChild(sheetTitol);
    sheetCapTxt.appendChild(sheetSub);
    var sheetClose = el('button', 'sheet__close', '×');
    sheetClose.type = 'button';
    sheetClose.setAttribute('aria-label', 'Tanca els ajustos');
    sheetClose.addEventListener('click', tancaSheet);
    sheetCap.appendChild(sheetCapTxt);
    sheetCap.appendChild(sheetClose);
    var sheetCos = el('div', 'sheet__body');
    sheet.appendChild(sheetCap);
    sheet.appendChild(sheetCos);
    sheetFons.addEventListener('click', tancaSheet);
    document.body.appendChild(sheetFons);
    document.body.appendChild(sheet);

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && sheetObert) tancaSheet();
    });

    function obreSheet(username) {
      var raw = rawPerAlumne[username];
      if (!raw) return;
      sheetCos.textContent = '';
      sheetCos.appendChild(buildEditor(username, raw, desaAjustos));
      sheetSub.textContent = 'Edita les dades de ' + username +
        '. Els canvis arribaran al mòbil quan l\'APP s\'obri (sense reinstal·lar).';
      sheetFons.hidden = false;
      sheet.hidden = false;
      document.body.classList.add('is-sheet-void');
      requestAnimationFrame(function () {
        sheetFons.classList.add('is-open');
        sheet.classList.add('is-open');
      });
      sheetObert = true;
    }

    function tancaSheet() {
      if (!sheetObert) return;
      sheetObert = false;
      sheetFons.classList.remove('is-open');
      sheet.classList.remove('is-open');
      document.body.classList.remove('is-sheet-void');
      setTimeout(function () {
        sheetFons.hidden = true;
        sheet.hidden = true;
      }, 280);
    }

    var dadesActuals = [];
    var alumneActiu = null;
    /* Cert mentre l'enllaç inicial (#estudiant/X) encara no s'ha trobat a les
       dades: evita que el primer fitxer que arribi robi la selecció. */
    var pendentHash = false;
    /* JSON tal qual de cada alumne, per al panell d'ajustos. */
    var rawPerAlumne = {};

    function neteja() {
      while (arrel.firstChild) arrel.removeChild(arrel.firstChild);
    }

    function buscaAlumne(username) {
      for (var i = 0; i < dadesActuals.length; i++) {
        if (dadesActuals[i].username === username) return dadesActuals[i];
      }
      return null;
    }

    /* La consola sempre mostra la fitxa d'un alumne: si el hash no en diu cap
       (o en diu un que no existeix), s'obre el primer de la llista i
       s'escorregeix l'URL amb replaceState, que no dispara hashchange. */
    function alumneMostrat() {
      if (!dadesActuals.length) return null;
      var alumne = buscaAlumne(alumneActiu);
      if (!alumne && pendentHash) return null;
      alumne = alumne || dadesActuals[0];
      if (alumne.username !== alumneActiu) {
        alumneActiu = alumne.username;
        window.history.replaceState(null, '', '#estudiant/' + alumneActiu);
      }
      return alumne;
    }

    /* Desa les edicions del panell d'ajustos. Llegeix el fitxer fresc de
       l'API (no el raw amb cau), hi enganxa `adminRevision` + `adminOverrides`
       i el torna a pujar. En acabar, refresca la fitxa en memòria. */
    function desaAjustos(slug, overrides) {
      var token = llegeixToken();
      var cami = 'users/' + slug + '.json';
      return llegeixFitxerApi(token, cami).then(function (lectura) {
        if (lectura.error) return { error: lectura.error };
        var base = lectura.dades || { schemaVersion: 2, username: slug };
        var revisio = novaRevisio();
        base.username = base.username || slug;
        base.schemaVersion = base.schemaVersion || 2;
        base.adminRevision = revisio;
        base.adminOverrides = overrides;

        return desaFitxerApi(token, cami, base, lectura.sha,
          'admin: ajustos manuals de ' + slug + ' (' + revisio + ')'
        ).then(function (escriptura) {
          if (escriptura.error) return { error: escriptura.error };
          rawPerAlumne[slug] = base;
          var n = normalitza(slug, base);
          n.username = slug;
          for (var i = 0; i < dadesActuals.length; i++) {
            if (dadesActuals[i].username === slug) {
              dadesActuals[i] = n;
              break;
            }
          }
          editorMissatge = {
            ok: true,
            text: 'Canvis desats al repositori (revisió ' + revisio + '). ' +
              'S\'aplicaran quan l\'APP de l\'alumne s\'obri o faci sync.'
          };
          dibuixa();
          return { ok: true, revisio: revisio };
        });
      });
    }

    function dibuixa() {
      neteja();

      /* L'alumne es resol abans de pintar el rail: si es dibuqués abans,
         en una càrrega directa amb #estudiant/... el rail es construiria
         sense saber encara quin és l'alumne actiu i el destaqu de l'element
         actiu es perdria. */
      var alumne = alumneMostrat();
      buildRail(dadesActuals, alumne ? alumne.username : null);
      if (!alumne) return;

      arrel.appendChild(buildFitxa(alumne));

      /* El botó de la capçalera només serveix si l'alumne té fitxer. */
      if (botoAjustos) {
        botoAjustos.disabled = !rawPerAlumne[alumne.username];
      }

      /* Desplaça la vista a l'anchor demanat (p. ex. des d'un enllaç
         «Detalls» d'un indicador) o retorna a dalt. */
      var anchor = window.location.hash.replace(/^#estudiant\/[^#]*/, '');
      if (anchor && document.getElementById(anchor)) {
        document.getElementById(anchor).scrollIntoView({ behavior: 'smooth', block: 'start' });
      } else {
        window.scrollTo(0, 0);
      }
    }

    function aplicaHash() {
      if (sheetObert) tancaSheet();
      var hash = window.location.hash.replace(/^#/, '');
      alumneActiu = hash.indexOf('estudiant/') === 0 ? hash.slice('estudiant/'.length) : null;
      dibuixa();
    }

    function carrega() {
      if (sheetObert) tancaSheet();
      neteja();
      buildRail([], alumneActiu);
      estatCarregant(arrel);

      if (window.location.protocol === 'file:') {
        neteja();
        estatError(arrel,
          'El navegador ha obert els fitxers directament des del disc (file://). ' +
          'Per llegir els JSON cal servir el projecte per HTTP. En una terminal, ' +
          'dins de la carpeta del projecte: python3 -m http.server 8000',
          null, botRetry(carrega));
        return;
      }

      var resultats = [];
      var rebuts = 0;

      carregaTots(function (r) {
        resultats.push(r);
        rebuts += 1;
        if (r.dades && r.raw) rawPerAlumne[r.username] = r.raw;

        var carregats = resultats.filter(function (x) { return x.dades; });

        /* Entre tots els alumnes del llistat, no només els que tenen fitxer:
           els que encara no han sincronitzat també hi surten. */
        dadesActuals = resultats.map(alumneVisible);
        /* Ordenem per nom perquè el rail no balli mentre carreguen. */
        dadesActuals.sort(function (a, b) { return a.username.localeCompare(b.username); });
        dibuixa();

        if (rebuts === CONFIG.alumnes.length) {
          /* Si l'enllaç inicial apuntava a algú que no existeix, ara es pot
             deixar caure la selecció al primer alumne. */
          if (pendentHash) {
            pendentHash = false;
            dibuixa();
          }
          if (!carregats.length) {
            /* Cap fitxer llegit de tot: es conserva l'ajuda de diagnosi encara
               que el rail ja mostri tots els alumnes configurats. */
            neteja();
            buildRail(dadesActuals, null);
            var absents = resultats.filter(function (x) { return x.tipus === 'absent'; });
            var noms = absents.map(function (x) { return x.username + '.json'; });
            estatBuit(arrel, noms.length ? ['Fitxer(s) no trobat(s): ' + noms.join(', ')] : null, carrega);
          } else {
            /* Un fitxer absent és un estado normal (alumne nou), no un error:
               només s'avisa de les peticions que han fallat de debò. */
            var fallits = resultats.filter(function (x) { return x.tipus === 'error'; });
            if (fallits.length > 0) {
              var avís = el('div', 'state state--warn');
              avís.setAttribute('role', 'status');
              afegeix(avís, 'p', 'state__text', fallits.length + ' fitxer(s) no s\'han pogut llegir: ' +
                fallits.map(function (x) { return x.username + '.json'; }).join(', '));
              avís.appendChild(botRetry(carrega));
              arrel.insertBefore(avís, arrel.firstChild);
            }
          }
        }
      });
    }

    window.addEventListener('hashchange', aplicaHash);

    /* L'enllaç compartit pot portar #estudiant/X: es té en compte abans de
       carregar res perquè la fitxa que es pinti sigui la de l'enllaç. */
    if (window.location.hash.indexOf('#estudiant/') === 0) {
      alumneActiu = window.location.hash.slice('#estudiant/'.length);
      pendentHash = true;
    }
    carrega();
  }

  /* ------------------------------------------------------------------------
     API pública
     ------------------------------------------------------------------------ */

  return {
    CONFIG: CONFIG,
    mostraLogin: mostraLogin,
    muntaConsola: muntaConsola,
    obreSessio: obreSessio,
    tancaSessio: tancaSessio,
    sessioOberta: sessioOberta,
    /* Exposat per depurar des de la consola del navegador
       (p. ex. MHBSFUT.normalitza('EloiRomero', snapshot)). */
    normalitza: normalitza,
    isoAData: isoAData,
    novaRevisio: novaRevisio,
    diesDeRatxa: diesDeRatxa,
    iniciPerDia: iniciPerDia,
    diaDelPla: diaDelPla
  };
})();
