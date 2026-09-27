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

    /* Adreça base dels fitxers de dades, relativa a dashboard.html. */
    dataPath: 'users/',

    /* Llistat d'alumnes que es mostren a la consola.
       IMPORTANT: el nom ha de coincidir EXACTAMENT (majúscules incloses)
       amb el fitxer que puja l'APP iOS: users/<username>.json.
       L'APP autentica amb StudentAccounts (p. ex. `EloiRomero`) i el
       GitHubSyncService puja a users/EloiRomero.json — `eloi.json` ja
       no s'actualitza. GitHub Pages no permet llistar carpetes, de
       manera que el llistat ha de ser explícit.
       Per afegir un alumne nou: creeu users/<username>.json i afegiu el
       username a aquesta llista. */
    alumnes: ['EloiRomero', 'GonzaloSchiavo', 'HugoMartinez', 'MarcVilanova', 'DavidHernandez'],

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
     var adreça = CONFIG.dataPath + encodeURIComponent(nom) + '.json';
     return window.fetch(adreça, { cache: 'no-store' }).then(function (resposta) {
       if (resposta.status === 404) return null;
       if (!resposta.ok) throw new Error('HTTP ' + resposta.status);
       return resposta.json();
     });
   }

   /* Demanda un únic fitxer d'alumne (només el que puja l'APP iOS).
      Resol sempre amb { username, dades } o { username, tipus, error }. */
   function carregaAlumne(username) {
     var cadena = Promise.resolve(null);
     cadena = cadena.then(function (trobat) {
       if (trobat) return trobat;
       return demanaFitxer(username).then(function (dades) {
         if (!dades) return null;
         return { dades: dades };
       });
     });
     return cadena.then(function (trobat) {
      cadena = cadena.then(function (trobat) {
        if (trobat) return trobat;
        return demanaFitxer(nom).then(function (dades) {
          if (!dades) return null;
          return { dades: dades };
        });
      });
    });
    return cadena.then(function (trobat) {
      if (!trobat) return { username: username, tipus: 'absent' };
      var dades = normalitza(username, trobat.dades);
      /* Slug estable per al rail i el hash (#estudiant/...): les dades
         heretades porten username en minúscules i trencarien la cerca. */
      dades.username = username;
      return { username: username, dades: dades };
    }).catch(function (error) {
      return { username: username, tipus: 'error', error: descriuError(error) };
    });
  }

  function carregaTots() {
    return Promise.all(CONFIG.alumnes.map(carregaAlumne));
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
    if (!s) return { nom: '?', cognoms: '' };
    var parts = s.replace(/([a-zà-ÿ])([A-ZÀ-Þ])/g, '$1 $2').split(' ');
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
        sessionsSetmanal: sessions
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
      var perfil = alumne.perfil || {};
      var recompenses = alumne.recompenses || {};
      item(
        '#estudiant/' + alumne.username,
        inicials(alumne),
        ((perfil.nom || '') + ' ' + (perfil.cognoms || '')).trim() || alumne.username,
        (recompenses.racha != null ? recompenses.racha : 0) + ' dies de racha',
        actiu === alumne.username
      );
    });
  }

  /* ------------------------------------------------------------------------
     Vista de fitxa (un alumne)
     ------------------------------------------------------------------------ */

  function buildFitxa(alumne) {
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
    afegeix(cap, 'h1', 'main__title',
      ((perfil.nom || '') + ' ' + (perfil.cognoms || '')).trim() || alumne.username);
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
    if (cap) {
      var sortida = el('button', 'btn-outline btn-outline--sm', 'Tancar sessió');
      sortida.type = 'button';
      sortida.addEventListener('click', function () {
        tancaSessio();
        window.location.replace('index.html#consola');
      });
      cap.appendChild(sortida);
    }

    var dadesActuals = [];
    var alumneActiu = null;

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
      var alumne = buscaAlumne(alumneActiu) || dadesActuals[0];
      if (alumne.username !== alumneActiu) {
        alumneActiu = alumne.username;
        window.history.replaceState(null, '', '#estudiant/' + alumneActiu);
      }
      return alumne;
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
      var hash = window.location.hash.replace(/^#/, '');
      alumneActiu = hash.indexOf('estudiant/') === 0 ? hash.slice('estudiant/'.length) : null;
      dibuixa();
    }

    function carrega() {
      neteja();
      buildRail([], alumneActiu);
      estatCarregant(arrel);

      /* Obert amb file:// no hi ha servidor: fetch fallaria i el missatge
         d'error seria confús, així que s'explica el problema real. */
      if (window.location.protocol === 'file:') {
        neteja();
        estatError(arrel,
          'El navegador ha obert els fitxers directament des del disc (file://). ' +
          'Per llegir els JSON cal servir el projecte per HTTP. En una terminal, ' +
          'dins de la carpeta del projecte: python3 -m http.server 8000',
          null, botRetry(carrega));
        return;
      }

      carregaTots().then(function (resultats) {
        var carregats = resultats.filter(function (r) { return r.dades; });
        var absents = resultats.filter(function (r) { return r.tipus === 'absent'; });
        var errors = resultats.filter(function (r) { return r.tipus === 'error'; });

        neteja();

        /* Sense cap fitxer: es mostra l'estat buit amb el detall dels
           noms que s'han demanat, que és el que ajuda a descobrir un error
           de nom. */
        if (!carregats.length) {
          var noms = absents.map(function (r) { return r.username + '.json'; });
          estatBuit(arrel, noms.length ? ['Fitxer(s) no trobat(s): ' + noms.join(', ')] : null, carrega);
          if (errors.length) {
            errors.forEach(function (r) {
              arrel.appendChild(el('p', 'state__hint', r.username + '.json: ' + (r.error || 'error')));
            });
          }
          buildRail([], null);
          return;
        }

        dadesActuals = carregats.map(function (r) { return r.dades; });

        /* S'ha d'aplicar el hash, no cridar dibuixa() directament: en una
           càrrega directa l'esdeveniment hashchange no s'ha disparat mai,
           així que sense això s'obriria sempre el primer alumne de la
           llista en lloc del que demana l'URL. */
        aplicaHash();

        /* Avís no bloquejant: si una part falla, la resta es mostra igual.
           S'insereix DESPRÉS de dibuixa() perquè dibuixa() buida l'arrel, i
           com a primer fill perquè quedi a sobre del resum. */
        if (absents.length || errors.length) {
          var avís = el('div', 'state state--warn');
          avís.setAttribute('role', 'status');
          var titular = absents.length + errors.length === 1
            ? '1 fitxer no s\'ha pogut carregar'
            : (absents.length + errors.length) + ' fitxers no s\'han pogut carregar';
          afegeix(avís, 'p', 'state__text', titular + ': ' +
            absents.map(function (r) { return r.username + '.json'; })
              .concat(errors.map(function (r) { return r.username + '.json (' + (r.error || 'error') + ')'; }))
              .join(', '));
          avís.appendChild(botRetry(carrega));
          arrel.insertBefore(avís, arrel.firstChild);
        }
      });
    }

    window.addEventListener('hashchange', aplicaHash);
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
    isoAData: isoAData
  };
})();
