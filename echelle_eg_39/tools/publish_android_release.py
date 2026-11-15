#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# tools/publish_android_release.py
#
# Publie une version de test Android hors magasin, en une commande :
#   bump de version -> APK universel + arm64 -> vérifications -> page /tester et
#   documentation -> release GitHub avec les deux fichiers -> commit et tag.
#
# Pourquoi ce script existe :
#   - `gh` n'est pas installé sur cette machine : la release se crée par l'API
#     REST, avec le jeton lu dans le trousseau macOS (`git credential-osxkeychain`).
#   - Flutter ne trouve pas le JDK tout seul : JAVA_HOME doit être exporté.
#   - `--split-per-abi` ajoute 2 000 au versionCode de la variante arm64. Le
#     nouveau numéro doit donc dépasser l'ancien + 2 000, sinon Android refuse la
#     mise à jour des testeurs qui ont la variante allégée (« App not installed »).
#   - La page /tester et docs/invitation-test.md annoncent la version courante :
#     oubliés une fois, ils distribuent un fichier qui n'existe plus.
#   - Le tag de release doit être posé sur le commit qui contient le bump, sinon
#     `git checkout android-test-<version>` montre encore l'ancien numéro.
#
# Exemples :
#   python3 tools/publish_android_release.py --version 1.0.5 --build 8004 \
#       --notes build/notes-1.0.5.md
#   python3 tools/publish_android_release.py --version 1.0.5 --notes build/notes-1.0.5.md --dry-run
#   python3 tools/publish_android_release.py --version 1.0.5 --notes build/notes-1.0.5.md --skip-build
#
# Ce que le script ne fait pas : rédiger les notes de version ni le paragraphe
# « Nouveautés » de la page. Ces textes parlent du contenu, pas des numéros, donc
# ils restent humains (--notes pour la release, --page-highlights pour la page).
# -----------------------------------------------------------------------------
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
REPO = Path(
    subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'],
        cwd=APP, capture_output=True, text=True, check=True,
    ).stdout.strip()
)

PUBSPEC = APP / 'pubspec.yaml'
VERSION_DART = APP / 'lib/app_version.dart'
DOCS = APP / 'docs/invitation-test.md'
PAGE = REPO / 'backend/src/routes/public_pages.js'
APK_DIR = APP / 'build/app/outputs/flutter-apk'
DIST = APP / 'build/android-release'
LOG_DIR = APP / 'build/logs'

GITHUB_REPO = 'okata-cell/echelle-eg39-backend'
GITHUB_USER = '210414533'
BRANCH = 'main'
PAGE_URL = 'https://echelle-eg39-backend-1.onrender.com/tester'

# Flutter ajoute cette valeur au versionCode de la variante arm64.
OFFSET_ABI = 2000

MOIS = (
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
)


class Journal:
    """Sortie lisible : étapes, constats, avertissements, erreurs."""

    def __init__(self, couleur: bool):
        self.couleur = couleur

    def _teinte(self, code: str, texte: str) -> str:
        return f'\033[{code}m{texte}\033[0m' if self.couleur else texte

    # Toutes les sorties sont vidées tout de suite : sans cela les
    # avertissements (stderr) passent avant l'étape qui les a produits.
    def etape(self, titre: str) -> None:
        print(f"\n{self._teinte('1', '▸')} {self._teinte('1', titre)}", flush=True)

    def info(self, texte: str) -> None:
        print(f'  {texte}', flush=True)

    def ok(self, texte: str) -> None:
        print(f'  {self._teinte("32", "✓")} {texte}', flush=True)

    def avertir(self, texte: str) -> None:
        print(f'  {self._teinte("33", "!")} {texte}', file=sys.stderr, flush=True)

    def simule(self, texte: str) -> None:
        print(f'  {self._teinte("2", f"(simulation) {texte}")}', flush=True)

    def echouer(self, texte: str) -> None:
        sys.exit(f'\n{self._teinte("31", "erreur")} : {texte}')


# --- Utilitaires -------------------------------------------------------------

def executer(cmd: list[str], journal: Journal, env: dict | None = None,
             log: Path | None = None) -> None:
    """Exécute une commande ; sa sortie part dans un fichier de log."""
    journal.info(f'$ {" ".join(cmd)}')
    resultat = subprocess.run(
        cmd, cwd=APP, env={**os.environ, **(env or {})}, capture_output=True, text=True,
    )
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(resultat.stdout + resultat.stderr, encoding='utf-8')
        journal.info(f'log : {log.relative_to(APP)}')
    if resultat.returncode != 0:
        journal.avertir((resultat.stdout + resultat.stderr).strip()[-1200:])
        journal.echouer(f'{cmd[0]} a échoué (code {resultat.returncode}) — voir le log ci-dessus')


def version_actuelle() -> tuple[str, int]:
    """Renvoie (version, versionCode de l'APK universel) lus dans pubspec.yaml."""
    texte = PUBSPEC.read_text(encoding='utf-8')
    trouve = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', texte, re.MULTILINE)
    if not trouve:
        sys.exit('version: <x.y.z>+<n> introuvable dans pubspec.yaml')
    return trouve.group(1), int(trouve.group(2))


def version_suivante(version: str) -> str:
    parties = version.split('.')
    parties[-1] = str(int(parties[-1]) + 1)
    return '.'.join(parties)


def date_francaise(jour: dt.date) -> str:
    return f'{jour.day} {MOIS[jour.month - 1]} {jour.year}'


def en_mo(octets: int) -> str:
    return f'{int(round(octets / 1_000_000))} Mo'


def espaces(nombre: int) -> str:
    return f'{nombre:,}'.replace(',', ' ')


def empreinte(chemin: Path) -> str:
    somme = hashlib.sha256()
    with chemin.open('rb') as flux:
        for bloc in iter(lambda: flux.read(1 << 20), b''):
            somme.update(bloc)
    return somme.hexdigest()


def outil_sdk(nom: str) -> Path:
    """Dernière version installée de aapt2 ou apksigner dans le SDK Android."""
    racine = Path.home() / 'Library/Android/sdk/build-tools'
    versions = sorted(
        (d for d in racine.glob('*') if (d / nom).exists() and d.name[0].isdigit()),
        key=lambda d: [int(p) for p in d.name.split('.') if p.isdigit()],
    )
    if not versions:
        sys.exit(f'{nom} introuvable dans {racine} : installez les build-tools Android.')
    return versions[-1] / nom


_JDK: dict | None = None


def java_home(journal: Journal) -> dict:
    """JDK d'Android Studio : Flutter ne le trouve pas seul sur ce Mac."""
    global _JDK
    if _JDK is not None:
        return _JDK
    if os.environ.get('JAVA_HOME') and Path(os.environ['JAVA_HOME'], 'bin/java').exists():
        journal.info(f'JAVA_HOME fourni : {os.environ["JAVA_HOME"]}')
        _JDK = {}
        return _JDK
    candidat = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    if candidat.exists():
        journal.info(f'JAVA_HOME : {candidat}')
        _JDK = {'JAVA_HOME': str(candidat)}
        return _JDK
    journal.echouer('aucun JDK trouvé : exportez JAVA_HOME ou installez Android Studio.')


def maj(texte: str, motif: str, remplacement: str, etiquette: str, journal: Journal) -> str:
    """Remplace un motif documenté ; prévient s'il a disparu du fichier."""
    nouveau, nombre = re.subn(motif, lambda _: remplacement, texte, flags=re.MULTILINE)
    if nombre == 0:
        journal.avertir(f'motif introuvable dans {etiquette} — à corriger à la main')
    return nouveau


# --- Contenus des fichiers à réécrire ---------------------------------------

def contenu_pubspec(version: str, build: int, version_prec: str, build_prec: int) -> str:
    """Réécrit le bloc de commentaire qui précède `version:` et la ligne elle-même.

    Le bloc est reconnu à sa première ligne : sans ancre explicite, la recherche
    remonterait dans les commentaires du gabarit Flutter et les effacerait.
    """
    commentaire = (
        '# Le +N reste au-dessus du versionCode arm64 de la version précédente : plus bas,\n'
        '# un testeur passé par la variante allégée ne pourrait pas installer celle-ci\n'
        f'# (Android refuse une régression, « App not installed »). La {version_prec} allégée est en\n'
        f'# {build_prec + OFFSET_ABI}, d\'où {build} pour l\'universelle '
        '(voir docs/invitation-test.md).'
    )
    texte = PUBSPEC.read_text(encoding='utf-8')
    # Deux générations de commentaire : celle de ce script, et l'ancienne rédigée
    # à la main pour la 1.0.4.
    for motif in (
        r'^# Le \+N reste au-dessus[\s\S]*?^version:.*?$',
        r'^# \d+ et non \d+ :[\s\S]*?^version:.*?$',
    ):
        nouveau, nombre = re.subn(
            motif, lambda _: f'{commentaire}\nversion: {version}+{build}',
            texte, count=1, flags=re.MULTILINE,
        )
        if nombre:
            return nouveau
    return re.sub(r'^version:.*?$', lambda _: f'version: {version}+{build}',
                  texte, count=1, flags=re.MULTILINE)


def contenu_version_dart(version: str) -> str:
    texte = VERSION_DART.read_text(encoding='utf-8')
    if not re.search(r"kAppVersion = '[\d.]+'", texte):
        sys.exit(f'kAppVersion introuvable dans {VERSION_DART.relative_to(APP)}')
    return re.sub(r"kAppVersion = '[\d.]+'", f"kAppVersion = '{version}'", texte, count=1)


def contenu_page(version: str, taille: str, taille_arm: str, jour: str, tag: str,
                 journal: Journal) -> str:
    texte = PAGE.read_text(encoding='utf-8')
    remplacements = [
        (r"^const ANDROID_TEST_VERSION = '.*?';",
         f"const ANDROID_TEST_VERSION = '{version}';"),
        (r"^const ANDROID_TEST_APK_SIZE = '.*?';",
         f"const ANDROID_TEST_APK_SIZE = '{taille}';"),
        (r"^const ANDROID_TEST_ARM64_SIZE = '.*?';",
         f"const ANDROID_TEST_ARM64_SIZE = '{taille_arm}';"),
        (r"^const ANDROID_TEST_UPDATED_AT = '.*?';",
         f"const ANDROID_TEST_UPDATED_AT = '{jour}';"),
        (r'releases/download/[^/]+/echelle-eg39-[\d.]+-android\.apk',
         f'releases/download/{tag}/echelle-eg39-{version}-android.apk'),
        (r'releases/download/[^/]+/echelle-eg39-[\d.]+-arm64\.apk',
         f'releases/download/{tag}/echelle-eg39-{version}-arm64.apk'),
    ]
    for motif, remplacement in remplacements:
        texte = maj(texte, motif, remplacement, 'public_pages.js', journal)
    return texte


def contenu_page_nouveautes(texte: str, resume: str, journal: Journal) -> str:
    """Remplace le paragraphe « Nouveautés » de la page, entre les balises <p>."""
    if '`' in resume or '${' in resume:
        journal.echouer('--page-highlights ne doit contenir ni backtick ni « ${ » '
                        '(le texte est inséré dans un gabarit JavaScript).')
    nouveau, nombre = re.subn(
        r'<p class="meta"><strong>Nouveautés \$\{ANDROID_TEST_VERSION\} :</strong>[\s\S]*?</p>',
        lambda _: ('<p class="meta"><strong>Nouveautés ${ANDROID_TEST_VERSION} :</strong> '
                   f'{resume}</p>'),
        texte, count=1,
    )
    if nombre == 0:
        journal.avertir('paragraphe « Nouveautés » introuvable dans public_pages.js')
    return nouveau


def contenu_docs(version: str, build: int, arm: int, version_prec: str, build_prec: int,
                 apk: dict, apk_arm: dict, tag: str, journal: Journal) -> str:
    texte = DOCS.read_text(encoding='utf-8')
    base = f'https://github.com/{GITHUB_REPO}/releases/download'

    texte = maj(
        texte,
        r'Version courante : \*\*[\d.]+\*\* \(versionCode \*\*\d+\*\*, variante allégée arm64\s*\n\*\*\d+\*\*\)',
        f'Version courante : **{version}** (versionCode **{build}**, variante allégée arm64\n**{arm}**)',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'\| APK universel \(toutes architectures\) \| \S+ \|',
        f'| APK universel (toutes architectures) | {base}/{tag}/echelle-eg39-{version}-android.apk |',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'\| APK allégé \(arm64, téléphones Android récents\) \| \S+ \|',
        f'| APK allégé (arm64, téléphones Android récents) | {base}/{tag}/echelle-eg39-{version}-arm64.apk |',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'\| Page de la release \(notes, empreintes\) \| \S+ \|',
        f'| Page de la release (notes, empreintes) | https://github.com/{GITHUB_REPO}/releases/tag/{tag} |',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'Version [\d.]+ · Android 7\.0 \(API 24\) et plus ·[\s\S]*?\n\n',
        f'Version {version} · Android 7.0 (API 24) et plus · {en_mo(apk["octets"])} '
        f'({espaces(apk["octets"])} octets,\nversionCode {build}, SHA-256 `{apk["sha256"]}`),\n'
        f'variante allégée {en_mo(apk_arm["octets"])} ({espaces(apk_arm["octets"])} octets, '
        f'versionCode {arm}, SHA-256\n`{apk_arm["sha256"]}`).\n\n',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'\*\*Le numéro après le `\+` doit rester au-dessus de \d+\*\* : voir l\'encadré\n'
        r'\s*ci-dessous\. La [\d.]+ utilise `[\d.]+\+\d+`\.',
        f'**Le numéro après le `+` doit rester au-dessus de {build_prec + OFFSET_ABI}** : voir '
        f'l\'encadré\n   ci-dessous. La {version} utilise `{version}+{build}`.',
        'docs/invitation-test.md', journal,
    )
    texte = maj(
        texte,
        r'> \*\*Piège des versionCodes ABI\.\*\*[\s\S]*?données\.',
        f'> **Piège des versionCodes ABI.** `--split-per-abi` ne produit pas le même\n'
        f'> versionCode pour la variante arm64 : Flutter ajoute 2 000 à celui de l\'APK\n'
        f'> universel. La {version_prec} universelle était en **{build_prec}**, sa variante\n'
        f'> allégée en **{build_prec + OFFSET_ABI}**. Un testeur passé par la variante allégée\n'
        f'> ne pourrait pas installer une {version} en versionCode {build_prec + OFFSET_ABI + 1} :\n'
        f'> Android refuse une régression. D\'où le choix de partir de **{build}** pour\n'
        f'> l\'universel (**{arm}** pour l\'arm64) — les deux variantes s\'installent alors\n'
        f'> par-dessus l\'une ou l\'autre {version_prec}, sans perte de données.',
        'docs/invitation-test.md', journal,
    )
    return texte


# --- Compilation et vérification --------------------------------------------

def construire(journal: Journal) -> None:
    env = java_home(journal)
    horodatage = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
    journal.etape('APK universel (toutes architectures)')
    executer(['flutter', 'build', 'apk', '--release'], journal, env=env,
             log=LOG_DIR / f'apk_universel_{horodatage}.log')
    journal.etape('APK allégé (arm64)')
    executer(['flutter', 'build', 'apk', '--release', '--split-per-abi'], journal, env=env,
             log=LOG_DIR / f'apk_arm64_{horodatage}.log')


def verifier_apk(chemin: Path, journal: Journal) -> dict:
    """Contrôle versionCode, versionName, signature, taille et empreinte."""
    badging = subprocess.run(
        [str(outil_sdk('aapt2')), 'dump', 'badging', str(chemin)],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()[0]
    code = re.search(r"versionCode='(\d+)'", badging)
    nom = re.search(r"versionName='([^']+)'", badging)
    if not code or not nom:
        journal.echouer(f'versionCode/versionName illisibles dans {chemin.name}')

    signature = subprocess.run(
        [str(outil_sdk('apksigner')), 'verify', '--print-certs', str(chemin)],
        capture_output=True, text=True, env={**os.environ, **java_home(journal)},
    )
    dn = re.search(r'certificate DN: (.+)', signature.stdout)
    return {
        'chemin': chemin,
        'versionCode': int(code.group(1)),
        'versionName': nom.group(1),
        'octets': chemin.stat().st_size,
        'sha256': empreinte(chemin),
        'certificat': dn.group(1).strip() if dn else 'inconnu',
    }


# --- GitHub ------------------------------------------------------------------

def jeton_github() -> str:
    """Jeton lu dans le trousseau macOS, jamais affiché."""
    demande = f'protocol=https\nhost=github.com\nusername={GITHUB_USER}\n\n'
    sortie = subprocess.run(
        ['git', 'credential-osxkeychain', 'get'],
        input=demande, capture_output=True, text=True, check=True,
    ).stdout
    for ligne in sortie.splitlines():
        if ligne.startswith('password='):
            return ligne.split('=', 1)[1].strip()
    sys.exit('jeton GitHub introuvable dans le trousseau macOS.')


def appel_api(methode: str, url: str, jeton: str, corps: dict | None = None,
              brut: bytes | None = None) -> dict:
    entetes = {
        'Authorization': f'Bearer {jeton}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'echelle-eg39-publish-script',
    }
    donnees = None
    if brut is not None:
        donnees = brut
        entetes['Content-Type'] = 'application/vnd.android.package-archive'
        entetes['Content-Length'] = str(len(brut))
    elif corps is not None:
        donnees = json.dumps(corps).encode()
        entetes['Content-Type'] = 'application/json'
    requete = urllib.request.Request(url, data=donnees, method=methode, headers=entetes)
    try:
        with urllib.request.urlopen(requete, timeout=900) as reponse:
            return json.loads(reponse.read().decode() or '{}')
    except urllib.error.HTTPError as erreur:
        sys.exit(f'{methode} {url} → HTTP {erreur.code}\n{erreur.read().decode()}')


def publier_release(tag: str, titre: str, notes: str, fichiers: list[Path],
                    journal: Journal) -> str:
    jeton = jeton_github()
    try:
        release = appel_api('GET', f'https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{tag}',
                            jeton)
        journal.info(f'release {tag} déjà présente (id {release["id"]}) : réutilisation')
    except SystemExit:
        release = appel_api('POST', f'https://api.github.com/repos/{GITHUB_REPO}/releases', jeton, {
            'tag_name': tag,
            'target_commitish': BRANCH,
            'name': titre,
            'body': notes,
            'draft': False,
            'prerelease': True,
        })
        journal.ok(f'release créée : {release["html_url"]}')

    deja = {actif['name']: actif['id'] for actif in release.get('assets', [])}
    for fichier in fichiers:
        if fichier.name in deja:
            appel_api('DELETE',
                      f'https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{deja[fichier.name]}',
                      jeton)
            journal.info(f'{fichier.name} déjà présent : ancien fichier supprimé')
        actif = appel_api(
            'POST',
            f'https://uploads.github.com/repos/{GITHUB_REPO}/releases/{release["id"]}/assets'
            f'?name={urllib.parse.quote(fichier.name)}',
            jeton, brut=fichier.read_bytes(),
        )
        journal.ok(f'{actif["name"]} — {espaces(actif["size"])} octets — {actif["state"]}')
    return release['html_url']


# --- Git ---------------------------------------------------------------------

def git(*arguments: str, journal: Journal) -> str:
    resultat = subprocess.run(['git', *arguments], cwd=REPO, capture_output=True, text=True)
    if resultat.returncode != 0:
        journal.echouer(f'git {arguments[0]} : {resultat.stderr.strip()}')
    if resultat.stdout.strip():
        journal.info(resultat.stdout.strip())
    return resultat.stdout.strip()


def pousser_tag(tag: str, journal: Journal) -> None:
    """Pousse le tag ; tolère une republication après un échec réseau."""
    resultat = subprocess.run(['git', 'push', 'origin', f'refs/tags/{tag}'],
                              cwd=REPO, capture_output=True, text=True)
    if resultat.returncode == 0:
        journal.ok(f'tag {tag} poussé')
        return
    if 'already exists' in resultat.stderr or 'déjà existante' in resultat.stderr:
        journal.avertir(f'tag {tag} déjà présent sur origin : la release le réutilisera '
                        f'(supprimez-le à la main si le commit est faux)')
        return
    journal.echouer(f'git push du tag : {resultat.stderr.strip()}')


def index_propre(fichiers: list[Path], journal: Journal) -> None:
    """Refuse de committer des modifications déjà indexées par quelqu'un d'autre."""
    deja = subprocess.run(['git', 'diff', '--cached', '--name-only'], cwd=REPO,
                          capture_output=True, text=True).stdout.split()
    intrus = [f for f in deja if f not in {str(p.relative_to(REPO)) for p in fichiers}]
    if intrus:
        journal.echouer('index déjà occupé par : ' + ', '.join(intrus) +
                        '. Committez ou retirez ces fichiers avant de publier.')


# --- Programme ---------------------------------------------------------------

def main() -> None:
    version_lue, build_lu = version_actuelle()

    analyseur = argparse.ArgumentParser(
        description='Construit et publie une version de test Android (hors magasin).',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Sans --version ni --build, le script propose la version suivante et un '
               'versionCode au-dessus de la variante arm64 actuelle.',
    )
    analyseur.add_argument('--version', help=f'numéro affiché (actuel : {version_lue})')
    analyseur.add_argument('--build', type=int,
                           help=f'versionCode de l\'APK universel (actuel : {build_lu}, '
                                f'minimum {build_lu + OFFSET_ABI + 1})')
    analyseur.add_argument('--tag', help='tag de release (défaut : android-test-<version>)')
    analyseur.add_argument('--titre', help='titre de la release GitHub')
    analyseur.add_argument('--notes', type=Path,
                           help='fichier Markdown des notes de version (corps de la release)')
    analyseur.add_argument('--page-highlights',
                           help='remplace le paragraphe « Nouveautés » de la page /tester')
    analyseur.add_argument('--skip-build', action='store_true',
                           help='réutilise les APK déjà présents dans build/app/outputs/flutter-apk')
    analyseur.add_argument('--dry-run', action='store_true',
                           help='n\'écrit rien : affiche les contrôles et les remplacements')
    analyseur.add_argument('--no-push', action='store_true',
                           help='prépare fichiers et APK, sans commit, tag ni release')
    arguments = analyseur.parse_args()

    journal = Journal(couleur=sys.stdout.isatty())

    version = arguments.version or version_suivante(version_lue)
    build = arguments.build or (build_lu + OFFSET_ABI + 3000)
    arm = build + OFFSET_ABI
    tag = arguments.tag or f'android-test-{version}'
    titre = arguments.titre or f'Version de test {version}'

    # --- Contrôles avant de toucher au dépôt -------------------------------
    journal.etape('Contrôles')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        journal.echouer(f'--version attend trois nombres séparés par des points (reçu : {version})')
    if build <= build_lu + OFFSET_ABI:
        journal.echouer(
            f'--build {build} est trop bas : les testeurs qui ont la variante allégée de '
            f'{version_lue} portent le versionCode {build_lu + OFFSET_ABI}. Choisissez au '
            f'moins {build_lu + OFFSET_ABI + 1} (conseillé : {build_lu + OFFSET_ABI + 3000}).'
        )
    if not arguments.dry_run and not arguments.no_push:
        if not arguments.notes:
            journal.echouer('--notes est obligatoire pour publier : décrivez ce qui change '
                            'dans un fichier Markdown (modèle : docs/invitation-test.md).')
        if not arguments.notes.exists():
            journal.echouer(f'fichier de notes introuvable : {arguments.notes}')
    if shutil.which('flutter') is None:
        journal.echouer('flutter est introuvable dans le PATH.')
    if not PAGE.exists():
        journal.echouer(f'page publique introuvable : {PAGE} (arborescence du dépôt modifiée ?)')
    journal.ok(f'{version_lue} ({build_lu}) → {version} : universel {build}, arm64 {arm}')

    # --- Compilation ou reprise des APK existants --------------------------
    if arguments.skip_build:
        journal.etape('Compilation ignorée (--skip-build)')
    elif arguments.dry_run:
        journal.etape('Compilation')
        journal.simule('flutter build apk --release puis --split-per-abi')
    else:
        journal.etape('Compilation')
        construire(journal)

    universel_source = APK_DIR / 'app-release.apk'
    arm64_source = APK_DIR / 'app-arm64-v8a-release.apk'
    if not universel_source.exists() or not arm64_source.exists():
        if not arguments.dry_run:
            journal.echouer('APK introuvables : relancez sans --skip-build.')
        journal.avertir('APK absents : tailles et empreintes ne seront connues qu\'après '
                        'compilation (les textes générés resteront approximatifs)')
        apk = {'octets': 0, 'sha256': '(après compilation)'}
        apk_arm = {'octets': 0, 'sha256': '(après compilation)'}
    else:
        journal.etape('Vérification des APK')
        apk = verifier_apk(universel_source, journal)
        apk_arm = verifier_apk(arm64_source, journal)
        # En simulation, les APK présents sont ceux de la version précédente : leur
        # versionCode ne peut pas encore correspondre, c'est attendu.
        verifier = journal.echouer if not arguments.dry_run else journal.avertir
        if (apk['versionCode'], apk_arm['versionCode']) != (build, arm):
            verifier(
                f'versionCode inattendu : universel {apk["versionCode"]} (attendu {build}), '
                f'arm64 {apk_arm["versionCode"]} (attendu {arm}). Le bump n\'a pas été pris en '
                f'compte : relancez sans --skip-build.'
            )
        if (apk['versionName'], apk_arm['versionName']) != (version, version):
            verifier(f'versionName inattendu : {apk["versionName"]} / '
                     f'{apk_arm["versionName"]}')
        journal.ok(f'universel {espaces(apk["octets"])} octets · sha256 {apk["sha256"][:16]}… '
                   f'· {apk["certificat"]}')
        journal.ok(f'arm64 {espaces(apk_arm["octets"])} octets · sha256 {apk_arm["sha256"][:16]}…')

    nom_universel = f'echelle-eg39-{version}-android.apk'
    nom_arm64 = f'echelle-eg39-{version}-arm64.apk'

    # --- Contenus réécrits -------------------------------------------------
    journal.etape('Fichiers à mettre à jour')
    page = contenu_page(version, en_mo(apk['octets']), en_mo(apk_arm['octets']),
                        date_francaise(dt.date.today()), tag, journal)
    if arguments.page_highlights:
        page = contenu_page_nouveautes(page, arguments.page_highlights, journal)
    nouveaux = {
        PUBSPEC: contenu_pubspec(version, build, version_lue, build_lu),
        VERSION_DART: contenu_version_dart(version),
        PAGE: page,
        DOCS: contenu_docs(version, build, arm, version_lue, build_lu, apk, apk_arm, tag, journal),
    }
    for chemin in nouveaux:
        journal.info(str(chemin.relative_to(REPO)))

    if arguments.dry_run:
        journal.etape('Simulation terminée')
        journal.simule(f'APK renommés : {nom_universel}, {nom_arm64}')
        journal.simule(f'commit, tag {tag}, release {titre} et push sur {BRANCH}')
        return

    # --- Fichiers prêts ----------------------------------------------------
    DIST.mkdir(parents=True, exist_ok=True)
    for source, nom in ((universel_source, nom_universel), (arm64_source, nom_arm64)):
        shutil.copy2(source, DIST / nom)
    journal.etape('Fichiers prêts')
    journal.ok(f'{DIST.relative_to(APP)}/{nom_universel}')
    journal.ok(f'{DIST.relative_to(APP)}/{nom_arm64}')

    for chemin, texte in nouveaux.items():
        chemin.write_text(texte, encoding='utf-8')
    journal.ok('pubspec.yaml, app_version.dart, page /tester et documentation réécrits')
    journal.avertir('relire le paragraphe « Nouveautés » de la page et la section des '
                    'nouveautés de docs/invitation-test.md (textes humains, non touchés)')

    if arguments.no_push:
        journal.etape('Arrêt demandé (--no-push)')
        journal.info('fichiers et APK prêts, rien n\'a été publié')
        return

    # --- Commit, tag, puis release ----------------------------------------
    journal.etape('Commit et tag')
    fichiers = [PUBSPEC, VERSION_DART, PAGE, DOCS]
    index_propre(fichiers, journal)
    git('add', *[str(f.relative_to(REPO)) for f in fichiers], journal=journal)
    git('commit', '-q', '-m',
        f'Publication Android {version} : versionCode {build} et {arm}, page /tester a jour',
        journal=journal)
    git('tag', '-f', tag, journal=journal)
    git('push', 'origin', BRANCH, journal=journal)
    pousser_tag(tag, journal)
    journal.ok(f'commit et tag {tag} poussés sur {BRANCH}')

    journal.etape('Release GitHub')
    adresse = publier_release(tag, titre, arguments.notes.read_text(encoding='utf-8'),
                              [DIST / nom_universel, DIST / nom_arm64], journal)

    journal.etape('Terminé')
    journal.info(f'release : {adresse}')
    journal.info(f'page    : {PAGE_URL}')
    journal.info('Render redéploie en une minute environ après le push.')
    journal.info('à envoyer aux testeurs : le lien /tester seulement, pas les APK.')


if __name__ == '__main__':
    main()
