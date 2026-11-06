const express = require('express');

const router = express.Router();

// Adresse publiée dans Play Console. Les mêmes pages servent de référence pour
// l'App Store : elles doivent rester lisibles sans compte et sans JavaScript.
const CONTACT_EMAIL = process.env.SUPPORT_EMAIL || 'admin@echelle-eg39.com';
const CONTACT_PHONE = '+228 90 01 43 29';
const COMPANY = 'ÉCHELLE EG39';
const ADDRESS = 'Lomé, Rue des frères franciscains, après les rails — Togo';
const UPDATED_AT = '3 novembre 2026';

const PAGES = [
  { path: '/confidentialite', label: 'Confidentialité' },
  { path: '/suppression-compte', label: 'Supprimer mon compte' },
  { path: '/conditions', label: 'Conditions d’utilisation' },
  { path: '/tester', label: 'Tester l’application' },
];

// Canal de test hors magasin. Tant que l'application n'est ni sur Google Play
// ni sur l'App Store, cette page est le seul point d'entrée pour un testeur :
// elle distribue l'APK signé. Les deux constantes ci-dessous se mettent à jour
// à chaque nouvelle version de test publiée sur GitHub Releases.
const ANDROID_TEST_VERSION = '1.0.1';
const ANDROID_TEST_APK_SIZE = '61 Mo';
const ANDROID_TEST_MIN_SDK = 'Android 7.0 (API 24)';
const ANDROID_TEST_UPDATED_AT = '6 novembre 2026';
const ANDROID_TEST_APK_URL =
  process.env.ANDROID_TEST_APK_URL ||
  'https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.1/echelle-eg39-1.0.1-android.apk';
// Même application, compilée pour les seuls téléphones arm64 (Android récents) :
// deux fois moins lourd à télécharger, utile en connexion mobile limitée.
const ANDROID_TEST_APK_ARM64_URL =
  process.env.ANDROID_TEST_APK_ARM64_URL ||
  'https://github.com/okata-cell/echelle-eg39-backend/releases/download/android-test-1.0.1/echelle-eg39-1.0.1-arm64.apk';

const STYLES = `
  :root {
    color-scheme: light;
    --canvas: #F5F5F7;
    --surface: #FFFFFF;
    --ink: #1D1D1F;
    --muted: #646970;
    --border: #E6E6E6;
    --brand: #0066CC;
    --danger: #B42318;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--canvas);
    color: var(--ink);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }
  .shell { max-width: 760px; margin: 0 auto; padding: 32px 20px 64px; }
  .wordmark { display: flex; align-items: baseline; gap: 10px; margin-bottom: 24px; }
  .wordmark strong { font-size: 17px; letter-spacing: -.2px; }
  .wordmark span { font-size: 12px; color: var(--muted); }
  nav { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 18px; }
  nav a {
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    color: var(--muted);
    border: 1px solid var(--border);
    background: var(--surface);
    border-radius: 999px;
    padding: 7px 14px;
  }
  nav a.active { color: #fff; background: var(--brand); border-color: var(--brand); }
  article {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 18px;
    padding: 28px 26px 32px;
  }
  h1 { font-size: 26px; line-height: 1.2; letter-spacing: -.6px; margin: 0 0 6px; }
  .meta { font-size: 12px; color: var(--muted); margin: 0 0 22px; }
  h2 { font-size: 17px; letter-spacing: -.2px; margin: 28px 0 8px; }
  h2:first-of-type { margin-top: 4px; }
  p { margin: 0 0 12px; }
  ul, ol { margin: 0 0 12px; padding-left: 20px; }
  li { margin-bottom: 6px; }
  a { color: var(--brand); }
  table { width: 100%; border-collapse: collapse; margin: 4px 0 16px; font-size: 15px; }
  th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
  th { font-size: 13px; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); font-weight: 600; }
  .callout {
    background: var(--canvas);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 14px 16px;
    margin: 4px 0 16px;
    font-size: 15px;
  }
  .danger { color: var(--danger); }
  .download {
    display: inline-block;
    background: var(--brand);
    color: #fff;
    text-decoration: none;
    font-weight: 600;
    border-radius: 999px;
    padding: 13px 24px;
    margin: 2px 0 0;
  }
  .download-meta { font-size: 13px; color: var(--muted); margin: 8px 0 20px; }
  ol.steps { padding-left: 22px; }
  ol.steps li { margin-bottom: 10px; }
  footer { margin-top: 22px; font-size: 13px; color: var(--muted); }
  footer a { color: var(--muted); }
  @media (max-width: 520px) {
    article { padding: 22px 18px 26px; }
    h1 { font-size: 22px; }
  }
`;

function layout({ title, description, active, body }) {
  const nav = PAGES.map(
    (page) =>
      `<a href="${page.path}"${page.path === active ? ' class="active" aria-current="page"' : ''}>${page.label}</a>`,
  ).join('');

  return `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — ${COMPANY}</title>
<meta name="description" content="${description}">
<style>${STYLES}</style>
</head>
<body>
<div class="shell">
  <div class="wordmark"><strong>${COMPANY}</strong><span>Topographie &amp; BTP</span></div>
  <nav>${nav}</nav>
  <article>
${body}
  </article>
  <footer>
    ${COMPANY} — ${ADDRESS}<br>
    <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> · ${CONTACT_PHONE}
  </footer>
</div>
</body>
</html>`;
}

const PRIVACY_BODY = `    <h1>Politique de confidentialité</h1>
    <p class="meta">Dernière mise à jour : ${UPDATED_AT}</p>

    <p>Cette politique décrit les données personnelles traitées par l’application
    ${COMPANY} et par le service en ligne qui l’accompagne. Elle s’applique à
    l’application mobile Android et iOS, ainsi qu’à ce site.</p>

    <h2>1. Responsable du traitement</h2>
    <p>${COMPANY}, ${ADDRESS}.<br>
    Contact : <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> — ${CONTACT_PHONE}.</p>

    <h2>2. Données que nous collectons</h2>
    <table>
      <tr><th>Catégorie</th><th>Données</th></tr>
      <tr><td>Compte</td><td>Nom, prénom, adresse e-mail, numéro de téléphone, mot de passe (conservé sous forme chiffrée, jamais en clair)</td></tr>
      <tr><td>Profil</td><td>Photo de profil si vous en ajoutez une, entreprise, adresse, ville, pays</td></tr>
      <tr><td>Activité commerciale</td><td>Demandes d’achat, locations de matériel, demandes de devis, prolongations de location</td></tr>
      <tr><td>Support</td><td>Messages envoyés au support et images qui y sont jointes, demandes d’information sur les formations, note et commentaire laissés sur l’application</td></tr>
      <tr><td>Technique</td><td>Jeton de session permettant de rester connecté. Aucune mesure d’audience publicitaire, aucun traceur tiers n’est installé par l’application.</td></tr>
    </table>
    <p>La carte de l’agence affichée dans l’application montre la position de nos
    locaux : l’application ne lit pas votre position personnelle.</p>

    <h2>3. Pourquoi nous les utilisons</h2>
    <ul>
      <li>créer et sécuriser votre compte, vous authentifier et vous permettre de récupérer votre mot de passe ;</li>
      <li>traiter vos demandes d’achat, vos locations et vos demandes de devis ;</li>
      <li>répondre à vos messages de support et vous recontacter au sujet d’une formation ;</li>
      <li>établir nos documents commerciaux et respecter nos obligations comptables ;</li>
      <li>améliorer l’application à partir des notes et commentaires reçus.</li>
    </ul>
    <p>Ces traitements reposent sur l’exécution du contrat qui vous lie à nous,
    sur nos obligations légales et comptables, et sur votre consentement
    lorsque vous sollicitez une formation ou laissez un commentaire.</p>

    <h2>4. Combien de temps nous les gardons</h2>
    <ul>
      <li><strong>Compte actif :</strong> vos données sont conservées tant que le compte existe.</li>
      <li><strong>Après suppression du compte</strong> : vos données personnelles et vos contenus (messages de support, images jointes, adresse, note de l’application) sont effacés immédiatement.</li>
      <li><strong>Pièces commerciales</strong> : les locations et les devis sont conservés sous forme anonymisée — sans nom, sans e-mail, sans téléphone — pendant la durée légale de conservation des pièces comptables.</li>
    </ul>

    <h2>5. Qui peut y accéder</h2>
    <p>Vos données sont accessibles à l’équipe ${COMPANY} et aux prestataires
    techniques qui hébergent et font fonctionner le service :</p>
    <ul>
      <li><strong>Render</strong> — hébergement du service et de la base de données ;</li>
      <li><strong>SendGrid</strong> — envoi des e-mails de réinitialisation de mot de passe ;</li>
      <li><strong>Africa’s Talking</strong> — envoi des codes de vérification par SMS ;</li>
      <li><strong>Google Firebase</strong> — authentification et services applicatifs de l’application mobile ;</li>
      <li><strong>OpenStreetMap</strong> — fond de carte de la fiche agence.</li>
    </ul>
    <p>Nous ne vendons ni ne louons vos données. Aucune donnée n’est utilisée à
    des fins de publicité. Ces prestataires peuvent être situés hors du Togo ;
    les transferts sont encadrés par leurs engagements contractuels de
    protection des données.</p>

    <h2>6. Vos droits</h2>
    <p>Vous pouvez demander l’accès à vos données, leur rectification, leur
    effacement, la limitation de leur traitement, vous y opposer, et en obtenir
    une copie.</p>
    <div class="callout">
      <strong>Supprimer votre compte</strong> : directement depuis l’application,
      dans <em>Profil → Mon compte → Supprimer mon compte</em>. La procédure est
      également décrite sur la page
      <a href="/suppression-compte">Supprimer mon compte</a>.
    </div>
    <p>Pour tout autre droit, écrivez à
    <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> depuis l’adresse
    associée à votre compte. Nous répondons dans un délai de 30 jours.</p>

    <h2>7. Sécurité</h2>
    <p>Les échanges avec l’application sont chiffrés (HTTPS). Les mots de passe
    ne sont jamais stockés en clair : ils sont conservés sous forme d’empreinte
    cryptographique non réversible. L’accès aux données est limité aux personnes
    qui en ont besoin.</p>

    <h2>8. Enfants</h2>
    <p>L’application s’adresse à des professionnels de la topographie et du BTP.
    Elle n’est pas destinée aux enfants de moins de 15 ans et ne collecte pas
    sciemment leurs données.</p>

    <h2>9. Modifications</h2>
    <p>Cette politique peut évoluer avec l’application. La date de mise à jour
    figure en haut de cette page ; toute évolution importante est signalée dans
    l’application.</p>`;

const DELETE_ACCOUNT_BODY = `    <h1>Supprimer mon compte</h1>
    <p class="meta">Dernière mise à jour : ${UPDATED_AT}</p>

    <p>Vous pouvez supprimer votre compte ${COMPANY} à tout moment, sans
    justification et sans frais. Deux moyens sont disponibles.</p>

    <h2>1. Depuis l’application (immédiat)</h2>
    <ol>
      <li>Ouvrez l’application et connectez-vous.</li>
      <li>Ouvrez l’onglet <em>Profil</em>.</li>
      <li>Dans la section <em>Mon compte</em>, touchez <em>Supprimer mon compte</em>.</li>
      <li>Saisissez votre mot de passe pour confirmer, puis validez la suppression.</li>
    </ol>
    <p>La suppression est appliquée immédiatement et votre session est fermée.</p>

    <h2>2. Par e-mail (si vous n’avez plus l’application)</h2>
    <p>Écrivez à <a href="mailto:${CONTACT_EMAIL}?subject=Suppression%20de%20compte">${CONTACT_EMAIL}</a>
    avec pour objet « Suppression de compte », <strong>depuis l’adresse e-mail
    associée au compte</strong>. Si vous ne pouvez plus accéder à cette boîte,
    indiquez le numéro de téléphone du compte : nous vérifions l’identité avant
    d’agir.</p>
    <p>La demande est traitée dans un délai de 30 jours, et en pratique sous
    7 jours ouvrés.</p>

    <h2>Ce qui est effacé</h2>
    <ul>
      <li>nom, prénom, adresse e-mail et numéro de téléphone ;</li>
      <li>mot de passe et photo de profil ;</li>
      <li>entreprise, adresse, ville et pays enregistrés sur le profil ;</li>
      <li>messages envoyés au support et images jointes ;</li>
      <li>demandes d’information sur les formations et note laissée sur l’application.</li>
    </ul>
    <p>Après la suppression, la connexion à ce compte devient impossible. Votre
    adresse e-mail et votre numéro redeviennent disponibles pour créer un
    nouveau compte.</p>

    <h2>Ce qui est conservé</h2>
    <div class="callout">
      Les <strong>locations et devis</strong> déjà émis sont conservés sous forme
      <strong>anonymisée</strong> — sans nom, sans e-mail, sans téléphone —
      pendant la durée légale de conservation des pièces comptables. Aucun de
      ces documents ne permet de vous réidentifier.
    </div>

    <h2>Une question</h2>
    <p>Écrivez à <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> ou
    appelez le ${CONTACT_PHONE}. Le détail des traitements figure dans notre
    <a href="/confidentialite">politique de confidentialité</a>.</p>`;

const TERMS_BODY = `    <h1>Conditions d’utilisation</h1>
    <p class="meta">Dernière mise à jour : ${UPDATED_AT}</p>

    <p>L’application ${COMPANY} permet de consulter le matériel de topographie
    disponible, de demander un devis, de réserver une location et de suivre vos
    échanges avec l’entreprise.</p>

    <h2>1. Compte</h2>
    <p>La création d’un compte suppose des informations exactes et à jour. Vous
    êtes responsable de la confidentialité de votre mot de passe et des actions
    effectuées depuis votre compte. Un compte est personnel.</p>

    <h2>2. Demandes, devis et locations</h2>
    <p>Une demande envoyée depuis l’application ne vaut pas commande ferme :
    elle est confirmée par l’entreprise, par devis accepté ou par contrat de
    location signé. Les prix affichés sont indicatifs et peuvent évoluer selon
    la durée, la disponibilité du matériel et les conditions d’intervention.</p>
    <p>Le matériel loué est restitué dans l’état où il a été remis, aux dates
    convenues. Toute prolongation fait l’objet d’une demande depuis
    l’application.</p>

    <h2>3. Usage de l’application</h2>
    <p>L’application ne doit pas servir à transmettre des contenus illicites,
    à usurper l’identité d’un tiers, ni à perturber son fonctionnement. Les
    messages adressés au support doivent rester en lien avec l’activité de
    l’entreprise.</p>

    <h2>4. Disponibilité</h2>
    <p>L’application est fournie en l’état. Certaines demandes d’enregistrement
    peuvent être différées lorsque l’appareil est hors ligne ; elles sont
    transmises à la reconnexion. Une interruption du service peut survenir pour
    maintenance ou pour une cause extérieure.</p>

    <h2>5. Propriété intellectuelle</h2>
    <p>Les textes, photographies de matériel, marques et éléments graphiques de
    l’application appartiennent à ${COMPANY} ou à leurs titulaires. Toute
    reproduction non autorisée est interdite.</p>

    <h2>6. Droit applicable</h2>
    <p>Ces conditions sont soumises au droit togolais. En cas de difficulté,
    nous vous invitons à nous écrire d’abord à
    <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> afin de rechercher une
    solution amiable.</p>`;

const TEST_BODY = `    <h1>Tester l’application</h1>
    <p class="meta">Version ${ANDROID_TEST_VERSION} · ${ANDROID_TEST_UPDATED_AT}</p>

    <p>L’application ${COMPANY} n’est pas encore publiée sur Google Play ni sur
    l’App Store. Cette page distribue la version de test pour Android. Elle est
    signée et identique à la version qui sera publiée.</p>

    <a class="download" href="${ANDROID_TEST_APK_URL}">Télécharger l’application</a>
    <p class="download-meta">Version ${ANDROID_TEST_VERSION} · ${ANDROID_TEST_APK_SIZE} · ${ANDROID_TEST_MIN_SDK} · aucun compte de magasin requis</p>
    <p class="download-meta">Connexion mobile limitée :
    <a href="${ANDROID_TEST_APK_ARM64_URL}">variante allégée (23 Mo)</a>, pour un
    téléphone Android récent. Même application.</p>

    <p class="meta"><strong>Nouveautés 1.0.1 :</strong> après la création du compte,
    un récapitulatif affiche l’e-mail, le téléphone et le mot de passe, avec un
    bouton « Copier et fermer » avant l’accueil.</p>

    <h2>Installation sur Android</h2>
    <ol class="steps">
      <li>Touchez <strong>Télécharger l’application</strong> ci-dessus. Le fichier
      arrive dans les téléchargements du téléphone.</li>
      <li>Ouvrez le fichier téléchargé. Android prévient que l’application ne vient
      pas du Play Store : c’est attendu à ce stade.</li>
      <li>Autorisez l’installation quand Android le demande
      (<em>Installer des applications inconnues</em>, pour Chrome ou Fichiers).
      L’autorisation vaut pour cette source une fois pour toutes.</li>
      <li>Ouvrez <em>ÉCHELLE EG39</em> et connectez-vous avec votre compte.</li>
    </ol>

    <div class="callout">
      <strong>Mise à jour</strong> : une nouvelle version se réinstalle de la même
      façon, par-dessus l’ancienne. Vos données et votre session sont conservées.
      Hors magasin, l’application ne se met pas à jour toute seule.
    </div>

    <h2>Ce qu’il faut</h2>
    <table>
      <tr><th>Élément</th><th>Valeur</th></tr>
      <tr><td>Système</td><td>${ANDROID_TEST_MIN_SDK} ou version ultérieure</td></tr>
      <tr><td>Taille du fichier</td><td>${ANDROID_TEST_APK_SIZE}</td></tr>
      <tr><td>Version de test</td><td>${ANDROID_TEST_VERSION}</td></tr>
      <tr><td>Compte</td><td>Un compte ${COMPANY} — écrivez-nous pour le créer</td></tr>
    </table>

    <h2>Sur iPhone</h2>
    <p>Il n’y a pas encore de lien de test pour iPhone. Apple n’autorise
    l’installation que de paquets signés, et la diffusion par TestFlight suppose
    un compte développeur Apple payant. Écrivez à
    <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> pour être prévenu dès
    que le lien iPhone existe.</p>

    <h2>Signaler un problème</h2>
    <p>Décrivez ce qui s’est passé, avec le modèle de téléphone et la version
    d’Android si possible :
    <a href="mailto:${CONTACT_EMAIL}?subject=Test%20de%20l%27application">${CONTACT_EMAIL}</a>
    ou ${CONTACT_PHONE}.</p>`;

router.get('/confidentialite', (req, res) => {
  res.set('Cache-Control', 'public, max-age=3600');
  res.type('html').send(
    layout({
      title: 'Politique de confidentialité',
      description:
        'Données collectées par l’application ÉCHELLE EG39, finalités, durées de conservation et droits des utilisateurs.',
      active: '/confidentialite',
      body: PRIVACY_BODY,
    }),
  );
});

router.get('/suppression-compte', (req, res) => {
  res.set('Cache-Control', 'public, max-age=3600');
  res.type('html').send(
    layout({
      title: 'Supprimer mon compte',
      description:
        'Comment supprimer votre compte ÉCHELLE EG39 depuis l’application ou par e-mail, et quelles données sont effacées.',
      active: '/suppression-compte',
      body: DELETE_ACCOUNT_BODY,
    }),
  );
});

router.get('/conditions', (req, res) => {
  res.set('Cache-Control', 'public, max-age=3600');
  res.type('html').send(
    layout({
      title: 'Conditions d’utilisation',
      description:
        'Conditions d’utilisation de l’application ÉCHELLE EG39 : compte, devis, locations et responsabilités.',
      active: '/conditions',
      body: TERMS_BODY,
    }),
  );
});

router.get('/tester', (req, res) => {
  res.set('Cache-Control', 'public, max-age=300');
  res.type('html').send(
    layout({
      title: 'Tester l’application',
      description:
        'Télécharger la version de test Android de l’application ÉCHELLE EG39, sans passer par Google Play, et l’installer pas à pas.',
      active: '/tester',
      body: TEST_BODY,
    }),
  );
});

module.exports = router;
