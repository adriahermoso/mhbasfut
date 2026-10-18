# MHBASFUT

_WEBSITE_ estàtica de **MHBASFUT**: la pàgina de la consola d'administració i la
presentació de l'aplicació mòbil d'entrenament per a clubs de futbol sala.
Publicada amb GitHub Pages, sense framework i sense cap pas de construcció.

## Pàgines

| Pàgina | Contingut |
| --- | --- |
| `index.html` | Punt d'entrada. Inici de sessió de la consola i presentació de l'APP (SPA de dues vistes). |
| `dashboard.html` | Consola d'administració. Rail lateral d'alumnes, indicadors i gràfic. Cal iniciar sessió. |
| `legal/index.html` | Política de privacitat. |
| `legal/suport.html` | Suport tècnic. |
| `legal/termes-i-condicions.html` | Terminis i condicions. |
| `assets/screens/` | Components HTML de maqueta (*app*, *console*, *privacy-policy*, *support*, *footer*). Són una minisite independent i **no** enllacen amb la resta del projecte: es mantenen com a material de treball i no s'editen des d'aquí. |

## Estructura

```
index.html                 Punt d'entrada (login + APP)
dashboard.html             Consola d'administració
legal/                     Pàgines legals
users/                     Dades d'entrenament, un JSON per alumne
assets/css/style.css       Disseny compartit per tota la web
assets/css/dashboard.css   Estils només de la consola
assets/js/nav.js           Menú desplegable de la capçalera
assets/js/dashboard.js     Credencials, sessió, lectura de dades i renderitzat
assets/fonts/              Nunito variable local
assets/images/             Logotips, icones i pantallades de l'APP
```

`style.css` és l'únic lloc on viu el sistema de disseny (variables `--bg-main`,
`--btn-bg`, `--card-border`, radis, tipografia). `dashboard.css` només afegeix
components de la consola i reutilitza aquestes variables.

## Iniciar de sessió a la consola

| Camp | Valor |
| --- | --- |
| Usuari | `admin` |
| Contrasenya | `mhbasfut2026` |

Les credencials són a `CONFIG.comptes`, al principi de `assets/js/dashboard.js`.

> **Això no és seguretat.** El repositori és públic, de manera que les
> credencials i les dades dels alumnes són llegibles per qualsevol. La sessió
> només es desa a `sessionStorage` i la comprovació es fa al navegador. És una
> funcionalitat d'aparença per al projecte, tal com s'explica a la política de
> privacitat.

## Dades dels alumnes

Cada alumne té un fitxer `users/<username>.json`. Per afegir-ne un:

1. Afegeix el `username` a `CONFIG.alumnes` de `assets/js/dashboard.js`.
2. Crea el fitxer seguint l'esquema d'un fitxer existent.

L'ordre és el que importa: el pas 1 és suficient perquè l'alumne aparegui al
rail de la consola. Si encara no ha sincronitzat mai, la fila es veu igual amb
«Encara no ha sincronitzat» i s'omplirà sola quan arribi el primer sync.

La clau de `CONFIG.alumnes` ha de ser **exactament** el mateix string que
l'APP iOS puja a `users/<username>.json`: sensible a majúscules i minúscules,
sense tildes ni espais (`HectorVelasco`, no `Hector Velasco`).

El nom visible es deriva de la clau partint-la pel cognom
(`MarcelRosell` → «Marcel Rosell»). Si cal un nom que això no doni, per exemple
amb tildes (`HectorVelasco` → «Héctor Velasco»), poseu-lo a `CONFIG.noms`.

GitHub Pages no permet llistar el contingut d'una carpeta, de manera que el
llistat d'alumnes ha de ser explícit al codi.

Esquema: els fitxers són el *snapshot* que puja l'APP iOS (`username`,
`questionnaireAnswers`, `sport`, `assignedPlanPerSport`, `planStartDate`,
`days`, `sleepHistory`/`emotionHistory`, `streakCompletedDates`, `coins`…),
amb `cycleNumber`, `completedCycles`, `programCompleted` i `planArchives` a
partir de l'esquema 2. La consola els adapta al seu model de presentació amb
`normalitza()`.

## Edició manual des de la consola

El botó **Ajustos manuals** de la capçalera obre una barra inferior (sheet)
flotant sobre la fitxa de l'alumne actiu, sense tocar les dades que es
mostren. El formulari és senzill a propòsit: esport, pla (1-4), **dia actual
del pla** (1-14), **dies de ratxa**, punts, dies completats i qüestionari
completat; les opcions del cicle (cicle actual, cicles completats, programa
completat) queden dins d'**Opcions avançades del cicle**, plegades. Es tanca
amb la ×, clicant el fons o prement Esc.

Els camps es guarden amb el format que entén l'APP sense tocar-ne el codi:
«dia actual N» es converteix en la data d'inici corresponent i «N dies de
ratxa» en N dates consecutives acabant avui. El dia i la ratxa només
s'escriuen si l'admin els canvia; la resta de camps sempre s'envien amb el
que mostri el formulari.

Per desar cal un **token personal de GitHub** (*fine-grained PAT*) amb permís
de continguts d'escriptura sobre aquest repositori. El token es desa a
`localStorage` del navegador (mai al codi ni al repositori) i la consola
l'usa per escriure el fitxer amb l'API de continguts.

Cada desament afegeix dues claus a `users/<usuari>.json`:

| Clau | Contingut |
| --- | --- |
| `adminRevision` | Segell ISO-8601 sense mil·lisegons (`2026-10-17T12:34:56Z`). |
| `adminOverrides` | Només els camps editats, amb el format que entén l'APP. |

L'APP, en obrir-se o tornar a primer pla (i abans de cada pujada), llegeix
aquestes claus i aplica les edicions si la revisió és més nova que l'última
aplicada; la pujada següent consolida l'estat nou. Si l'APP encara no s'ha
obert, les claus es queden al fitxer i s'apliquen al següent arrencament.

> El format d'`adminOverrides` (claus i tipus) està definit a
> `AdminOverrideApplier.swift` de l'APP iOS. Si es canvia allà, cal canviar
> també `buildEditor` a `assets/js/dashboard.js`.

## Com treure els fitxers en local

Els JSON no es poden llegir amb el protocol `file://`. Cal servir el projecte
per HTTP des de la carpeta arrel:

```bash
python3 -m http.server 8000
```

i obrir <http://127.0.0.1:8000/index.html>.

## Estat actual

- Les dades de `users/` són **de mostra** i no corresponen a persones reals.
- L'autenticació és aparent, tal com s'explica més amunt.
- `assets/images/bttom_app_football.png` és una còpia byte a byte de
  `bottom_app_football.png` (l'original amb el nom ben escrit) i no s'utilitza
  enlloc. Es conserva per no perdre material.
- Les pàgines de `assets/screens/` comproven `../assets/css/style.css` i
  `../assets/images/`, que des de dins d'`assets/` no existeixen. Funcionen
  només si la carpeta es mou a l'arrel del repositori.
