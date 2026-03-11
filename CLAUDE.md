# CLAUDE.md — Instructions permanentes pour PubliGraphics

## Identite projet & auteur
- **Projet :** PubliGraphics for Social Researchers
- **Auteur :** Paul Wambo
- **Email :** paulwambo2@gmail.com
- **GitHub :** Paul1991-ux | https://github.com/Paul1991-ux/publigraphics
- **ORCID :** https://orcid.org/0009-0005-6062-9227
- **Affiliation :** Universite de Dschang
- **Licence :** MIT
- **Demo chercheur :** Esther Duflo (MIT, Nobel 2019, donnees publiques)

## Specifications completes
Le fichier `PROMPT_MAITRE_PUBLIGRAPHICS_CLAUDECODE.md` contient les specifications
exhaustives du projet (3365 lignes). **TOUJOURS le lire avant de generer du code.**
Le fichier `GUIDE_PRISE_EN_MAIN_PUBLIGRAPHICS.md` est le guide utilisateur.

## Environnement local (Windows 11)
- **R 4.5.2 :** `"/c/Program Files/R/R-4.5.2/bin/Rscript.exe"` (guillemets obligatoires)
- **Rtools :** `C:\rtools44\` (compilation packages C/C++)
- **MiKTeX :** installe (pdflatex disponible pour article JSS)
- **Node.js 24.14.0 :** `"/c/Program Files/nodejs/node.exe"`
- **npm 11.9.0 :** `"/c/Program Files/nodejs/npm"`
- **Git 2.53.0 :** `C:\Program Files\Git\`
- **Shell :** Git Bash — syntaxe Unix (pas CMD/PowerShell)
- **PATH Node :** ajouter `export PATH="/c/Program Files/nodejs:$PATH"` si besoin

## Connexion GitHub (SSH)
- **Remote :** `git@github.com:Paul1991-ux/publigraphics.git`
- **Cle SSH :** `~/.ssh/id_ed25519_github`
- **Branche principale :** main

## Architecture cible (generee par Claude Code)
```
publigraphics/                    # Racine du projet
├── .github/workflows/            # CI/CD GitHub Actions
│   ├── R-CMD-check.yaml
│   ├── mcp-build-test.yaml
│   └── pkgdown-deploy.yaml
├── r-package/                    # Composant 1 : Package R
│   ├── DESCRIPTION
│   ├── NAMESPACE
│   ├── R/                        # Code source R
│   ├── inst/extdata/             # Donnees demo (Duflo)
│   ├── man/                      # Documentation auto (roxygen2)
│   ├── tests/testthat/           # Tests unitaires
│   └── vignettes/                # Vignettes JSS
├── mcp-server/                   # Composant 2 : Serveur MCP
│   ├── src/                      # Code TypeScript
│   ├── dist/                     # Build compile
│   ├── package.json
│   └── tsconfig.json
├── article-jss/                  # Composant 3 : Article JSS
│   ├── publigraphics.Rnw         # Article Sweave
│   ├── replication_script.R
│   └── figures/
├── CLAUDE.md                     # CE FICHIER (ne pas ecraser)
├── PROMPT_MAITRE_*.md            # Specs (ne pas ecraser)
├── GUIDE_PRISE_EN_MAIN_*.md      # Guide (ne pas ecraser)
├── .gitignore
├── LICENSE
└── README.md
```

## Regles de code strictes

### R (r-package/)
- Tidyverse strict : pipe natif `|>`, snake_case, pas de `<-` dans les pipes
- roxygen2 pour TOUTE documentation (`@param`, `@return`, `@examples`, `@export`)
- `@examples` utilisant les donnees demo (Duflo) pour chaque fonction exportee
- Messages bilingues : `cli::cli_alert_info("Analyse en cours... | Analysis in progress...")`
- Reproductibilite : `set.seed(2024L)` partout ou il y a de l'aleatoire
- Gestion d'erreurs : `tryCatch()` avec messages bilingues FR | EN
- Pas de chemins absolus, tout relatif via `system.file()` pour les donnees internes

### TypeScript (mcp-server/)
- ESM modules (`"type": "module"` dans package.json)
- `strict: true` dans tsconfig.json
- Validation des entrees via Zod, pas de `any`
- `async/await` pour toutes les operations asynchrones
- Bridge R : `child_process.execFile()` avec timeout

### General
- Jamais de cles API dans les logs ou le code source
- Commentaires en anglais dans le code, messages utilisateur bilingues FR | EN
- Commits en anglais, conventionnels : `feat:`, `fix:`, `docs:`, `test:`, `chore:`
- Ne JAMAIS push sans demander confirmation a l'utilisateur
- Ne JAMAIS ecraser les fichiers specs (PROMPT_MAITRE, GUIDE, CLAUDE.md)

## Phases d'execution (ordre strict)
1. **Init :** Git + structure repertoires + .gitignore + LICENSE + README
2. **R Package :** r-package/ — tout le code R + tests + docs + donnees demo
3. **MCP Server :** mcp-server/ — TypeScript + bridge R + 7 outils
4. **Article JSS :** article-jss/ — Sweave + script de replication
5. **CI/CD :** GitHub Actions (3 workflows)
6. **Validation :** `devtools::check()` propre, `npm test` OK, replication < 10 min

## Commandes utiles
```bash
# R (toujours entre guillemets a cause des espaces dans le chemin)
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e "devtools::check('r-package')"
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e "devtools::document('r-package')"
"/c/Program Files/R/R-4.5.2/bin/Rscript.exe" -e "devtools::test('r-package')"

# Node/npm (ajouter au PATH si absent)
export PATH="/c/Program Files/nodejs:$PATH"
cd mcp-server && npm install && npm run build && npm test

# Git
git add -A && git status
git commit -m "feat: description"
git push origin main  # TOUJOURS demander confirmation avant
```

## Placeholders a substituer dans le prompt maitre
Les valeurs suivantes remplacent les placeholders `[AUTHOR_*]` :
- `[AUTHOR_FIRSTNAME]` → Paul
- `[AUTHOR_LASTNAME]` → Wambo
- `[AUTHOR_EMAIL]` → paulwambo2@gmail.com
- `[AUTHOR_ORCID]` → 0009-0005-6062-9227
- `[AUTHOR_AFFILIATION]` → Universite de Dschang
- `[GITHUB_USERNAME]` → Paul1991-ux

## Interdictions absolues
- Ne pas ecraser CLAUDE.md, PROMPT_MAITRE_*, GUIDE_*
- Ne pas push sans confirmation explicite
- Ne pas installer de packages globaux sans accord
- Ne pas hardcoder de chemins Windows (utiliser des chemins relatifs)
- Ne pas generer de code sans avoir lu les specs correspondantes du prompt maitre
- Ne pas laisser de `TODO` ou code mort dans le code final
