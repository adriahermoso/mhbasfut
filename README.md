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

1. Crea el fitxer seguint l'esquema d'un fitxer existent.
2. Afegeix el `username` a `CONFIG.alumnes` de `assets/js/dashboard.js`.

GitHub Pages no permet llistar el contingut d'una carpeta, de manera que el
llistat d'alumnes ha de ser explícit al codi.

Esquema: `username`, `perfil`, `pla`, `questionari`, `progresDiari`,
`historial` (12 dies, per al gràfic de la consola) i `recompenses`.

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
