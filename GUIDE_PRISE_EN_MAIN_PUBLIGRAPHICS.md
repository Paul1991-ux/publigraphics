# Guide Complet — Prendre en Main le Code Produit par Claude Code
## PubliGraphics for Social Researchers
### Configuration : Windows 10/11 · RStudio Desktop · GitHub actif

---

> **Comment lire ce guide**
> Chaque étape est numérotée et contient exactement ce que vous devez faire,
> ce que vous devez voir si ça marche, et quoi faire si ça ne marche pas.
> Ne sautez aucune étape. Elles sont dans le bon ordre.

---

## AVANT DE COMMENCER — Vue d'ensemble des 5 étapes

```
ÉTAPE 0 — Préparer votre machine Windows        (~30 min, une seule fois)
ÉTAPE 1 — Installer et lancer Claude Code        (~10 min)
ÉTAPE 2 — Surveiller Claude Code en action       (pendant 1-3 heures)
ÉTAPE 3 — Valider le package R dans RStudio      (~45 min)
ÉTAPE 4 — Tester le serveur MCP                  (~20 min)
ÉTAPE 5 — Votre rôle dans l'article JSS          (continu)
```

---

## ÉTAPE 0 — PRÉPARER VOTRE MACHINE WINDOWS

### 0.1 Vérifier et mettre à jour R

Ouvrez RStudio. Dans la console (panneau en bas à gauche), tapez :

```r
R.version.string
```

Vous devez voir quelque chose comme `"R version 4.4.x (...)"`

➤ **Si vous avez R < 4.3.0** : téléchargez la dernière version sur
  https://cran.r-project.org/bin/windows/base/ puis réinstallez RStudio.

➤ **Si vous avez R ≥ 4.3.0** : vous pouvez continuer.

---

### 0.2 Installer Rtools (OBLIGATOIRE sur Windows)

Rtools permet de compiler certains packages R sur Windows.
C'est indispensable pour le package `publigraphics`.

1. Allez sur : https://cran.r-project.org/bin/windows/Rtools/
2. Téléchargez **Rtools44** (ou la version correspondant à votre R)
3. Installez avec toutes les options par défaut
4. **Vérifiez** dans RStudio :

```r
Sys.which("make")
# Doit afficher quelque chose comme :
# "C:\\rtools44\\usr\\bin\\make.exe"
```

➤ **Si le résultat est vide `"""`** : redémarrez RStudio et recommencez la vérification.

---

### 0.3 Installer les packages R de développement

Dans la console RStudio, copiez-collez ce bloc entier et appuyez sur Entrée :

```r
# Installation des outils de développement de packages
install.packages(c(
  "devtools",
  "usethis",
  "roxygen2",
  "testthat",
  "pkgdown",
  "withr",
  "remotes"
), repos = "https://cran.r-project.org", dependencies = TRUE)
```

Cela prend environ 5-10 minutes. Attendez le message `> ` qui indique que c'est terminé.

**Vérification :**

```r
library(devtools)
# Si aucun message d'erreur → installation réussie
```

---

### 0.4 Installer Git pour Windows

Git est le logiciel de versioning qui communique avec GitHub.

1. Allez sur : https://git-scm.com/download/win
2. Téléchargez et installez **Git for Windows** (options par défaut)
3. **Vérifiez** dans RStudio :

```r
usethis::git_sitrep()
# Doit afficher votre nom, email, et "Git version x.x.x"
```

➤ **Si vous voyez "Git not found"** : redémarrez Windows et recommencez.

---

### 0.5 Configurer Git avec votre identité

Dans la console RStudio :

```r
# Remplacez par VOS informations — elles apparaîtront sur GitHub
usethis::use_git_config(
  user.name  = "Votre Nom Complet",
  user.email = "votre_email@exemple.com"
)
```

---

### 0.6 Configurer l'authentification GitHub

Pour que votre machine puisse envoyer du code sur GitHub :

```r
# Crée un Personal Access Token (PAT) GitHub
usethis::create_github_token()
# → Votre navigateur s'ouvre sur GitHub
# → Donnez un nom au token (ex: "publigraphics-windows")
# → Sélectionnez l'expiration : 90 days
# → Cliquez "Generate token"
# → COPIEZ le token affiché (commence par ghp_...)
# → NE FERMEZ PAS CETTE PAGE AVANT L'ÉTAPE SUIVANTE

# Enregistrez le token dans R
gitcreds::gitcreds_set()
# → Collez votre token quand demandé
```

**Vérification :**

```r
usethis::gh_token_help()
# Doit afficher "Token found" avec votre nom GitHub
```

---

### 0.7 Installer Node.js (pour le serveur MCP)

1. Allez sur : https://nodejs.org
2. Téléchargez la version **LTS** (Long Term Support)
3. Installez avec toutes les options par défaut
4. **Vérifiez** en ouvrant le terminal Windows (touche Windows + R, tapez `cmd`) :

```cmd
node --version
# Doit afficher v18.x.x ou supérieur

npm --version
# Doit afficher 9.x.x ou supérieur
```

---

### 0.8 Installer Claude Code

Claude Code est un outil en ligne de commande d'Anthropic.

1. Ouvrez le terminal Windows (cmd ou PowerShell)
2. Tapez :

```cmd
npm install -g @anthropic/claude-code
```

3. **Vérifiez** :

```cmd
claude --version
# Doit afficher un numéro de version
```

4. Connectez-vous avec votre compte Anthropic :

```cmd
claude auth login
# → Suivez les instructions (ouverture du navigateur)
```

---

### 0.9 Créer le dépôt GitHub vide AVANT de lancer Claude Code

C'est une étape critique que beaucoup oublient.

1. Allez sur https://github.com
2. Cliquez sur le bouton vert **"New"** (nouveau dépôt)
3. Remplissez :
   - **Repository name** : `publigraphics`
   - **Description** : `Visual and Narrative Profiling of Social Researchers`
   - **Visibility** : Public
   - ☐ Ne cochez PAS "Add a README" (Claude Code le créera)
4. Cliquez **"Create repository"**
5. Copiez l'URL affichée : `https://github.com/VOTRE_USERNAME/publigraphics.git`

---

### 0.10 Créer le dossier de travail local

1. Créez un dossier sur votre bureau ou dans Mes Documents :
   `C:\Users\VotreNom\Documents\publigraphics`
2. Ouvrez le terminal dans ce dossier :
   - Dans l'explorateur Windows, naviguez vers ce dossier
   - Cliquez dans la barre d'adresse, tapez `cmd`, appuyez sur Entrée
3. Initialisez Git :

```cmd
git init
git remote add origin https://github.com/VOTRE_USERNAME/publigraphics.git
```

---

### ✅ CHECKLIST ÉTAPE 0

Avant de passer à l'étape 1, vérifiez chaque point :

```
[ ] R ≥ 4.3.0 installé et vérifié dans RStudio
[ ] Rtools44 installé — Sys.which("make") retourne un chemin
[ ] devtools, usethis, roxygen2, testthat installés sans erreur
[ ] Git installé — usethis::git_sitrep() affiche la version
[ ] Git configuré avec votre nom et email
[ ] Token GitHub créé et enregistré
[ ] Node.js ≥ 18 installé — node --version fonctionne
[ ] Claude Code installé — claude --version fonctionne
[ ] Dépôt GitHub vide créé
[ ] Dossier local créé et lié au dépôt GitHub
```

---

## ÉTAPE 1 — PRÉPARER ET LANCER CLAUDE CODE

### 1.1 Préparer votre fichier prompt

1. Ouvrez le fichier `PROMPT_MAITRE_PUBLIGRAPHICS_CLAUDECODE.md`
   (le fichier que vous avez téléchargé)
2. Faites les remplacements suivants (Ctrl+H dans n'importe quel éditeur) :

| Texte à remplacer        | Remplacez par                          |
|--------------------------|----------------------------------------|
| `[AUTHOR_FIRSTNAME]`     | Votre prénom                           |
| `[AUTHOR_LASTNAME]`      | Votre nom de famille                   |
| `[AUTHOR_EMAIL]`         | Votre email académique                 |
| `[AUTHOR_ORCID]`         | Votre ORCID (ou `0000-0000-0000-0000`) |
| `[GITHUB_USERNAME]`      | Votre nom d'utilisateur GitHub         |
| `[AFFILIATION]`          | Votre université ou institution        |

3. Sauvegardez le fichier modifié dans votre dossier
   `C:\Users\VotreNom\Documents\publigraphics\`

---

### 1.2 Configurer la clé API Anthropic pour Claude Code

Dans le terminal (cmd) dans votre dossier de travail :

```cmd
setx ANTHROPIC_API_KEY "sk-ant-votre-cle-ici"
```

Fermez et rouvrez le terminal pour que la variable soit prise en compte.

---

### 1.3 Lancer Claude Code

Dans le terminal, dans votre dossier de travail :

```cmd
cd C:\Users\VotreNom\Documents\publigraphics
claude
```

Claude Code s'ouvre dans le terminal. Vous verrez une invite comme :

```
Claude Code v1.x.x
Working directory: C:\Users\VotreNom\Documents\publigraphics
>
```

---

### 1.4 Soumettre le prompt

Dans l'invite Claude Code, tapez exactement :

```
Lis attentivement le fichier PROMPT_MAITRE_PUBLIGRAPHICS_CLAUDECODE.md
qui se trouve dans ce dossier, puis exécute toutes les phases dans l'ordre.
Commence par la PHASE 1 et attends ma validation avant de passer à la PHASE 2.
```

Appuyez sur Entrée.

---

### ✅ SIGNE QUE ÇA MARCHE

Claude Code va commencer à créer des fichiers. Vous verrez dans le terminal
des messages comme :

```
Creating directory: r-package/R/
Creating file: r-package/DESCRIPTION
Creating file: r-package/R/parse_inputs.R
...
```

---

## ÉTAPE 2 — SURVEILLER CLAUDE CODE EN ACTION

### 2.1 Ce que vous devez observer

Claude Code travaille en autonomie mais vous devez rester disponible.
Il peut :
- **Vous poser des questions** → répondez dans le terminal
- **S'arrêter sur une erreur** → lisez le message et guidez-le
- **Terminer une phase** → il vous demandera de valider avant de continuer

---

### 2.2 Comment lire ce que Claude Code fait

Dans le terminal, vous verrez en temps réel :
- `Creating file: ...` → il crée un nouveau fichier
- `Editing file: ...` → il modifie un fichier existant
- `Running: Rscript ...` → il exécute du code R pour tester
- `Running: npm ...` → il exécute des commandes Node.js

**Pour voir les fichiers créés** : ouvrez l'explorateur Windows dans votre
dossier — vous pouvez voir les fichiers apparaître en temps réel.

---

### 2.3 Les 3 situations où vous devez intervenir

**Situation 1 — Claude Code vous pose une question**
→ Lisez attentivement et répondez en français ou en anglais.
   Exemple de question : "Should I use pdf or html as default output format?"
   Vous répondez : "Les deux, comme spécifié dans le prompt."

**Situation 2 — Claude Code signale une erreur et s'arrête**
→ Lisez le message d'erreur. Les plus fréquentes sur Windows :

| Message d'erreur                          | Solution                                    |
|-------------------------------------------|---------------------------------------------|
| `'make' not found`                        | Rtools non installé → refaire étape 0.2     |
| `package 'xxx' is not available`          | Tapez : `install.packages("xxx")`           |
| `Error in library(xxx)`                   | Même solution                               |
| `git: command not found`                  | Git non installé → refaire étape 0.4        |
| `ENOENT: no such file or directory`       | Vérifiez que vous êtes dans le bon dossier  |

Après avoir résolu l'erreur, dites à Claude Code :
"Le problème est résolu, tu peux continuer."

**Situation 3 — Claude Code termine une phase**
→ Il affiche un message du type :
"Phase 1 complete. Please verify before I proceed to Phase 2."
→ Suivez les instructions de validation ci-dessous (Étape 3),
  puis dites : "Phase 1 validée, tu peux passer à la Phase 2."

---

### 2.4 Ne jamais faire pendant que Claude Code tourne

- ❌ Ne fermez PAS le terminal
- ❌ Ne modifiez PAS les fichiers que Claude Code est en train d'écrire
- ❌ Ne lancez PAS RStudio pendant que Claude Code exécute du code R
  (ils peuvent entrer en conflit sur Windows)

---

## ÉTAPE 3 — VALIDER LE CODE R DANS RSTUDIO

Cette étape se fait après que Claude Code a terminé la **Phase 1** (minimum)
ou la **Phase 4** (validation complète recommandée).

### 3.1 Ouvrir le projet R dans RStudio

1. Ouvrez RStudio
2. Menu **File → Open Project**
3. Naviguez vers `C:\Users\VotreNom\Documents\publigraphics\r-package`
4. Sélectionnez le fichier `publigraphics.Rproj`
5. RStudio recharge avec le projet ouvert

---

### 3.2 Test de base — le package se charge-t-il ?

Dans la console RStudio :

```r
# Charger le package en mode développement
devtools::load_all()
```

**✅ Bon signe** : vous voyez `Loading publigraphics` sans message rouge.

**❌ Mauvais signe** : vous voyez `Error:` suivi d'un message.
→ Copiez le message d'erreur complet et dites à Claude Code :
  "J'ai cette erreur dans devtools::load_all() : [collez l'erreur]"

---

### 3.3 Test de documentation — la doc est-elle bien générée ?

```r
devtools::document()
```

**✅ Bon signe** : `Writing NAMESPACE` et une liste de fichiers `.Rd`
sans message d'erreur.

---

### 3.4 Test des données d'exemple — Esther Duflo se charge-t-elle ?

```r
# Charger les données de démonstration
bib_path   <- system.file("extdata", "duflo_articles.bib",
                           package = "publigraphics")
extra_path <- system.file("extdata", "duflo_extra.csv",
                           package = "publigraphics")

# Vérifier que les fichiers existent
file.exists(bib_path)    # Doit retourner TRUE
file.exists(extra_path)  # Doit retourner TRUE
```

```r
# Parser les données
data <- pg_read_bib(bib_path)
print(data)
# Doit afficher un tibble avec 15 lignes (les 15 articles Duflo)
```

```r
# Ajouter les données supplémentaires
data_full <- pg_merge_inputs(data, pg_read_extra(extra_path)) |>
             pg_classify()

# Vérifier le résumé
pg_summary_table(data_full)
# Doit afficher un tableau avec les 12 types de production
# et des chiffres réalistes pour Duflo
```

**Ce que vous devez voir :**

```
# A tibble: 8 × 7
  type_classified    label_fr              label_en           n first_year last_year pct_total
  <chr>              <chr>                 <chr>          <int>      <int>     <int>     <dbl>
1 article            Articles scientif...  Peer-reviewed...  15       2001      2022      37.5
2 seminar            Séminaires            Seminars          10       2009      2022      25.0
3 award              Prix et distinctions  Awards             6       2009      2019      15.0
...
```

---

### 3.5 Test des visualisations — les graphiques s'affichent-ils ?

```r
# Test du radar (graphique le plus simple)
set.seed(2024L)
p_radar <- pg_radar_productions(data_full, theme_color = "#1A5276")
print(p_radar)
# → Un graphique radar doit s'afficher dans le panneau "Plots" de RStudio
```

```r
# Test du nuage de mots
set.seed(2024L)
wc <- pg_wordcloud_articles(data_full, n_topics = 3L, lang = "en")
print(wc$plot)
# → Un nuage de mots coloré doit s'afficher
```

```r
# Test de la carte (nécessite une connexion internet)
map <- pg_map_seminars(data_full, output_type = "static",
                       theme_color = "#1A5276")
print(map)
# → Une carte du monde avec des points doit s'afficher
```

---

### 3.6 Le test le plus important — `devtools::check()`

Ce test vérifie que le package respecte les standards CRAN.
Il prend environ 5-10 minutes sur Windows.

```r
devtools::check()
```

**Pendant l'exécution**, vous verrez défiler beaucoup de texte.
Attendez le résumé final.

**✅ Résultat acceptable :**

```
── R CMD check results ──────────────────────────────
Duration: 5m 32s

0 errors ✔ | 0 warnings ✔ | 2 notes ✖
```

Les "notes" (pas les errors ni warnings) sont acceptables.
Les notes fréquentes sur Windows :

```
N  checking CRAN incoming feasibility ...
   Maintainer: 'Votre Nom <email>'
   New submission
```
→ C'est normal pour un nouveau package.

**❌ Résultat à corriger :**

Si vous voyez `errors` ou `warnings` (pas les notes), copiez
le message complet et envoyez-le à Claude Code :
"J'ai ces erreurs dans devtools::check() : [collez]"

---

### 3.7 Test de génération du notebook complet

C'est le test final qui valide tout le pipeline.
**Faites-le sans clé API d'abord** pour tester la partie non-IA :

```r
# Test sans IA (pas besoin de clé API)
result <- generate_publigraphics(
  author_name    = "Esther Duflo",
  bib_file       = bib_path,
  extra_data     = extra_path,
  affiliation    = "MIT / J-PAL / Collège de France",
  orcid          = "0000-0002-0632-6971",
  theme_color    = "#1A5276",
  output_dir     = file.path(Sys.getenv("USERPROFILE"), "Desktop",
                             "publigraphics_test"),
  language       = "en",
  output_formats = "html",
  api_key_claude = "",    # Pas de clé API = pas de résumés IA
  open_after     = TRUE   # Ouvre le HTML dans votre navigateur
)
```

**✅ Bon signe** : votre navigateur s'ouvre avec le notebook HTML d'Esther Duflo.

**Ce que vous devez voir dans le notebook :**
- Page de couverture avec les statistiques globales
- Graphique radar des productions
- Courbe temporelle 2001-2022
- Nuage de mots des articles
- Carte des séminaires (Nairobi, Paris, Stockholm, etc.)
- Galerie des livres (Poor Economics, Good Economics)
- Section awards avec le Prix Nobel 2019

---

### 3.8 Test avec la clé API Anthropic (optionnel)

Si vous avez une clé API Anthropic (`sk-ant-...`) :

```r
# Enregistrer votre clé API dans R (session courante seulement)
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-votre-cle-ici")

# Vérifier que la clé est valide
pg_check_api_key(Sys.getenv("ANTHROPIC_API_KEY"))
# Doit retourner TRUE

# Générer le notebook avec résumés IA (3 articles seulement pour le test)
result <- generate_publigraphics(
  author_name     = "Esther Duflo",
  bib_file        = bib_path,
  extra_data      = extra_path,
  affiliation     = "MIT / J-PAL",
  theme_color     = "#1A5276",
  output_dir      = file.path(Sys.getenv("USERPROFILE"), "Desktop",
                               "publigraphics_test_ai"),
  language        = "en",
  output_formats  = "html",
  n_narrative_max = 3L,    # Limite à 3 pour contrôler les coûts
  open_after      = TRUE
)
```

**Ce que vous devez voir en plus** : dans les fiches des 3 premiers articles,
4 encadrés colorés avec la problématique, pertinence, résultat et question
ouverte générés par Claude.

---

### ✅ CHECKLIST ÉTAPE 3 — Validation R

```
[ ] devtools::load_all() → aucun message d'erreur
[ ] devtools::document() → NAMESPACE et fichiers man/ générés
[ ] file.exists(bib_path) → TRUE (données Duflo présentes)
[ ] pg_read_bib() → tibble 15 lignes affiché
[ ] pg_summary_table() → tableau avec les 12 types
[ ] pg_radar_productions() → graphique radar affiché
[ ] pg_wordcloud_articles() → nuage de mots affiché
[ ] pg_map_seminars() → carte affichée
[ ] devtools::check() → 0 errors, 0 warnings
[ ] generate_publigraphics() sans API → notebook HTML ouvert dans navigateur
[ ] Le notebook contient les 7 sections attendues
[ ] Les statistiques de Duflo sont cohérentes (15 articles, Prix Nobel, etc.)
```

---

## ÉTAPE 4 — TESTER LE SERVEUR MCP DANS CLAUDE DESKTOP

### 4.1 Installer Claude Desktop

Téléchargez Claude Desktop depuis https://claude.ai/download
Installez et connectez-vous avec votre compte Anthropic.

---

### 4.2 Compiler le serveur MCP

Dans le terminal (cmd), allez dans le dossier du serveur MCP :

```cmd
cd C:\Users\VotreNom\Documents\publigraphics\mcp-server
npm install
npm run build
```

**✅ Bon signe** : `npm run build` se termine sans message `error`.
Vous verrez le dossier `dist/` apparaître avec des fichiers `.js`.

**❌ Erreur TypeScript fréquente** :
```
error TS2345: Argument of type...
```
→ Dites à Claude Code : "J'ai cette erreur TypeScript : [collez]"

---

### 4.3 Trouver le chemin absolu vers le serveur MCP

Dans le terminal :

```cmd
cd C:\Users\VotreNom\Documents\publigraphics\mcp-server\dist
echo %CD%\index.js
```

Copiez le chemin affiché. Il ressemble à :
`C:\Users\VotreNom\Documents\publigraphics\mcp-server\dist\index.js`

---

### 4.4 Configurer Claude Desktop

1. Ouvrez l'explorateur Windows
2. Dans la barre d'adresse, collez :
   `%APPDATA%\Claude`
3. Ouvrez (ou créez) le fichier `claude_desktop_config.json`
4. Collez ce contenu en remplaçant le chemin :

```json
{
  "mcpServers": {
    "publigraphics": {
      "command": "node",
      "args": [
        "C:\\Users\\VotreNom\\Documents\\publigraphics\\mcp-server\\dist\\index.js"
      ]
    }
  }
}
```

**Attention** : sur Windows, utilisez des doubles backslashes `\\` dans le JSON.

5. Sauvegardez le fichier
6. **Fermez complètement Claude Desktop** (clic droit sur l'icône dans la barre
   des tâches → Quitter)
7. Relancez Claude Desktop

---

### 4.5 Vérifier que les outils MCP apparaissent

Dans Claude Desktop :
1. Cliquez sur l'icône **"+"** ou **outils** en bas de la fenêtre de chat
2. Cherchez **"publigraphics"** dans la liste des outils disponibles

**✅ Bon signe** : vous voyez les 7 outils listés :
- `parse_bib_file`
- `preview_researcher_stats`
- `list_productions_by_type`
- `generate_narrative_summary`
- `generate_publigraphics_notebook`
- `validate_bib_file`
- `open_publigraphics_output`

**❌ Si les outils n'apparaissent pas** :
Allez dans Claude Desktop → Paramètres → Developer → Logs MCP.
Copiez les messages d'erreur et dites à Claude Code :
"Les outils MCP n'apparaissent pas. Voici les logs : [collez]"

---

### 4.6 Premier test conversationnel

Dans Claude Desktop, tapez ce message :

```
J'ai un fichier BibTeX situé à :
C:\Users\VotreNom\Documents\publigraphics\r-package\inst\extdata\duflo_articles.bib

Et un fichier CSV à :
C:\Users\VotreNom\Documents\publigraphics\r-package\inst\extdata\duflo_extra.csv

Peux-tu analyser ce fichier et me donner les statistiques globales
de ce chercheur ?
```

**✅ Ce que vous devez voir** : Claude appelle automatiquement
`parse_bib_file` puis `preview_researcher_stats` et vous affiche
un résumé structuré de la carrière d'Esther Duflo.

---

### 4.7 Test de génération complète via MCP

```
Génère le notebook PubliGraphics complet pour Esther Duflo avec :
- Fichier BibTeX : C:\Users\VotreNom\...\duflo_articles.bib
- Fichier CSV : C:\Users\VotreNom\...\duflo_extra.csv
- Affiliation : MIT / J-PAL / Collège de France
- ORCID : 0000-0002-0632-6971
- Couleur : #1A5276
- Dossier de sortie : C:\Users\VotreNom\Desktop\test_mcp_duflo
- Langue : en
- Formats : html seulement (pas de PDF pour ce premier test)
```

**✅ Ce que vous devez voir** :
1. Claude appelle `validate_bib_file` pour vérifier la qualité
2. Claude appelle `generate_publigraphics_notebook`
3. Après 2-3 minutes, Claude vous donne le chemin du fichier HTML
4. Claude appelle `open_publigraphics_output` et le fichier s'ouvre

---

### ✅ CHECKLIST ÉTAPE 4 — Validation MCP

```
[ ] npm run build → 0 erreurs TypeScript
[ ] Dossier dist/ créé avec index.js
[ ] claude_desktop_config.json créé avec le bon chemin
[ ] Claude Desktop redémarré
[ ] 7 outils publigraphics visibles dans Claude Desktop
[ ] Première question conversationnelle → réponse avec stats Duflo
[ ] Génération complète via MCP → notebook HTML produit
```

---

## ÉTAPE 5 — VOTRE RÔLE DANS L'ARTICLE JSS

Claude Code aura produit le fichier `article-jss/publigraphics.Rnw`
avec toutes les sections rédigées. Voici exactement ce que VOUS devez
faire pour que l'article soit soumissible.

### 5.1 Ce que Claude Code aura écrit (ne pas modifier)

- La structure LaTeX complète
- Le code R dans tous les chunks (figures, tableaux)
- Les sections Background, Package Design, Core Functions
- L'illustration avec Esther Duflo
- La description du serveur MCP

---

### 5.2 Ce que VOUS devez ajouter ou modifier

**Dans la section Introduction** (environ 2 paragraphes à personnaliser) :
Ajoutez votre propre motivation pour avoir créé ce package.
Pourquoi, en tant que chercheur en sciences sociales,
avez-vous ressenti le besoin de cet outil ?
C'est la partie la plus personnelle de l'article.

**Dans la section Acknowledgments** :
Ajoutez les noms des collègues qui ont testé le package,
votre institution, tout financement éventuel.

**Dans la section Author Information** (à la fin du .Rnw) :
Remplissez votre adresse complète, affiliation, email.

**Dans la section Performance** :
Les chiffres de temps d'exécution doivent être mesurés sur VOTRE machine.
Exécutez le script de réplication et notez les durées réelles.

---

### 5.3 Comment compiler l'article

Pour vérifier que l'article se compile correctement :

```r
# Dans RStudio, ouvrez article-jss/publigraphics.Rnw
# Puis dans la console :
knitr::knit("article-jss/publigraphics.Rnw",
            output = "article-jss/publigraphics.tex")

# Ensuite, dans le terminal (cmd) :
# cd article-jss
# pdflatex publigraphics.tex
# bibtex publigraphics
# pdflatex publigraphics.tex
# pdflatex publigraphics.tex
```

➤ Pour compiler en PDF, vous avez besoin d'une installation LaTeX.
Sur Windows, installez **MiKTeX** : https://miktex.org/download

---

### 5.4 La checklist de soumission JSS

Avant de soumettre à JSS (https://www.jstatsoft.org/about/submissions),
vérifiez ces points OBLIGATOIRES :

```
[ ] Le package est sur GitHub avec toutes les fonctions documentées
[ ] devtools::check() → 0 errors, 0 warnings
[ ] Le script de réplication s'exécute en < 10 min
[ ] Toutes les figures de l'article sont générées par le code R
[ ] La vignette est compilable : devtools::build_vignettes()
[ ] L'article fait entre 20 et 40 pages en PDF
[ ] La bibliographie est au format JSS (jss.bst)
[ ] Vous avez soumis le package à CRAN (ou il est sur GitHub)
```

---

### 5.5 Soumettre le package à CRAN (avant ou avec l'article)

JSS exige que le package soit sur CRAN ou soumis en même temps.
Pour soumettre à CRAN :

```r
# Vérification finale stricte (simule les vérifications CRAN)
devtools::check(cran = TRUE, remote = TRUE)
# 0 errors, 0 warnings obligatoires

# Construire le package
devtools::build()
# → Crée un fichier publigraphics_0.1.0.tar.gz

# Soumettre à CRAN
# Allez sur : https://cran.r-project.org/submit.html
# Uploadez le fichier .tar.gz
# Remplissez le formulaire
```

---

## ANNEXE A — Résolution des problèmes Windows fréquents

### Problème : `Error: package 'xxx' is not available for R version x.x.x`

```r
# Solution : installer depuis GitHub ou Bioconductor
install.packages("xxx", repos = "https://cran.r-project.org")
# Si toujours absent :
remotes::install_github("auteur/xxx")
```

---

### Problème : `Error in loadNamespace : package 'xxx' required but not installed`

```r
# Solution rapide :
install.packages("xxx")
# Puis relancer devtools::load_all()
```

---

### Problème : Les chemins Windows avec espaces

Sur Windows, les chemins avec des espaces causent des erreurs.
Évitez : `C:\Users\Jean Dupont\Documents\`
Préférez : `C:\Users\JeanDupont\Documents\`

Si impossible, utilisez des guillemets dans R :

```r
path <- "C:/Users/Jean Dupont/Documents/publigraphics"
# Notez les slashes / (pas \) dans R
```

---

### Problème : `pandoc` non trouvé pour le rendu Rmd

RStudio installe pandoc automatiquement. Vérifiez :

```r
rmarkdown::pandoc_available()
# Doit retourner TRUE

rmarkdown::pandoc_version()
# Doit afficher 2.x.x ou supérieur
```

Si FALSE : réinstallez RStudio depuis https://posit.co/downloads/

---

### Problème : Chrome non trouvé pour la génération PDF

`pagedown::chrome_print()` nécessite Chrome ou Chromium.

```r
# Vérifier si Chrome est trouvé automatiquement
pagedown::find_chrome()
# Doit retourner un chemin vers chrome.exe

# Si non trouvé, spécifier manuellement :
options(pagedown.chrome = "C:/Program Files/Google/Chrome/Application/chrome.exe")
```

---

## ANNEXE B — Glossaire pour chercheurs non-informaticiens

| Terme                 | Explication simple                                          |
|-----------------------|-------------------------------------------------------------|
| **Package R**         | Un ensemble de fonctions R réutilisables, comme un plugin   |
| **BibTeX**            | Format de fichier pour les références bibliographiques      |
| **CRAN**              | La bibliothèque officielle des packages R (comme un AppStore)|
| **devtools::check()** | Vérifie que votre package respecte les standards de qualité |
| **roxygen2**          | Système pour écrire la documentation R dans le code         |
| **MCP**               | Protocole qui permet à Claude d'utiliser des outils externes|
| **npm**               | Gestionnaire de paquets pour Node.js (comme CRAN pour R)    |
| **TypeScript**        | Langage de programmation utilisé pour le serveur MCP        |
| **GitHub Actions**    | Tests automatiques qui s'exécutent à chaque modification    |
| **JSS**               | Journal of Statistical Software — la revue cible            |
| **Sweave/knitr**      | Système pour mélanger code R et texte LaTeX dans un article |
| **TF-IDF**            | Mesure statistique d'importance des mots dans un corpus     |
| **LDA**               | Modèle statistique pour découvrir les thèmes d'un corpus    |
| **API**               | Interface pour communiquer avec un service en ligne         |
| **JSON**              | Format de données structurées (comme un dictionnaire)       |

---

## ANNEXE C — Contacts en cas de blocage

Si vous êtes bloqué sur une erreur après avoir suivi ce guide :

1. **Premier réflexe** : copiez l'erreur complète et demandez à Claude
   (ce chat) : "J'ai cette erreur à l'étape X : [collez l'erreur]"

2. **Pour les erreurs R** : Stack Overflow avec le tag `[r]`
   https://stackoverflow.com/questions/tagged/r

3. **Pour les erreurs GitHub/Git** : GitHub Docs
   https://docs.github.com/fr

4. **Pour les erreurs MCP** : Documentation MCP Anthropic
   https://docs.anthropic.com/fr/docs/build-with-claude/mcp

5. **Pour les questions JSS** : Instructions aux auteurs JSS
   https://www.jstatsoft.org/about/submissions

---

*Ce guide a été conçu pour Windows 10/11 · RStudio Desktop · GitHub actif*
*PubliGraphics for Social Researchers — Version 0.1.0*
