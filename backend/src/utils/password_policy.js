/**
 * Politique de mot de passe du serveur.
 *
 * Elle ne s'applique qu'aux mots de passe créés ou modifiés : un compte inscrit
 * avant cette règle conserve le sien et peut toujours se connecter.
 *
 * Principes retenus :
 *  - aucun caractère interdit, les caractères spéciaux sont même encouragés ;
 *  - pas de longueur maximale courte (128 caractères acceptés) ;
 *  - pas de composition imposée à la lettre : trois familles sur quatre ;
 *  - refus des mots de passe courants, des suites évidentes et de ce qui
 *    reprend le nom, l'e-mail ou le téléphone du titulaire.
 */

const LONGUEUR_MIN = 10;
const LONGUEUR_MAX = 128;

/** Rappel affiché par les écrans, identique côté application. */
const REGLES =
  '10 caractères minimum, dont trois familles parmi minuscules, majuscules, ' +
  'chiffres et caractères spéciaux.';

const FAMILLES = [
  { nom: 'minuscules', test: (mdp) => /[a-z]/.test(mdp) },
  { nom: 'majuscules', test: (mdp) => /[A-Z]/.test(mdp) },
  { nom: 'chiffres', test: (mdp) => /[0-9]/.test(mdp) },
  { nom: 'caractères spéciaux', test: (mdp) => /[^A-Za-z0-9]/.test(mdp) },
];

/** Mots de passe les plus utilisés, comparés en minuscules et sans accents. */
const INTERDITS = new Set([
  '123456',
  '1234567',
  '12345678',
  '123456789',
  '1234567890',
  '000000',
  '111111',
  '112233',
  '121212',
  '123123',
  '654321',
  'azerty',
  'azertyuiop',
  'azerty1234',
  'qwerty',
  'qwertyuiop',
  'motdepasse',
  'motdepasse1',
  'motdepasse123',
  'password',
  'password1',
  'password123',
  'passw0rd',
  'passepartout',
  'admin',
  'admin1234',
  'administrateur',
  'root',
  'bienvenue',
  'welcome',
  'welcome1',
  'soleil',
  'bonjour',
  'salut',
  'football',
  'basketball',
  'superman',
  'batman',
  'amour',
  'secret',
  'changeme',
  'testtest',
  'test1234',
  'abcdef',
  'abc12345',
  'iloveyou',
  'ordinateur',
  'telephone',
  // Le nom de la maison reste interdit ; les mots du métier, eux, sont une
  // base légitime pour une phrase de passe (« Chantier#2026 » doit passer).
  'echelle',
  'echelleeg39',
  'eg39',
]);

/** Minuscules, sans accents, sans espaces : base des comparaisons. */
function nettoyer(valeur) {
  return String(valeur ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, '');
}

function neConserveQueLesLettres(valeur) {
  return valeur.replace(/[^a-z]/g, '');
}

/**
 * Suites de quatre caractères consécutifs (`abcd`, `1234`, `9876`).
 */
function contientUneSuite(mdp) {
  for (let index = 0; index + 3 < mdp.length; index += 1) {
    const a = mdp.charCodeAt(index);
    const b = mdp.charCodeAt(index + 1);
    const c = mdp.charCodeAt(index + 2);
    const d = mdp.charCodeAt(index + 3);

    if (b - a === 1 && c - b === 1 && d - c === 1) return true;
    if (b - a === -1 && c - b === -1 && d - c === -1) return true;
  }
  return false;
}

/** Éléments personnels à ne pas retrouver dans le mot de passe. */
function elementsPersonnels({ firstName, lastName, email, phone }) {
  const jetons = new Set();
  const ajouter = (valeur) => {
    const propre = nettoyer(valeur);
    if (propre.length >= 3) jetons.add(propre);
  };

  ajouter(firstName);
  ajouter(lastName);
  ajouter(String(email ?? '').split('@')[0]);

  const chiffres = String(phone ?? '').replace(/\D/g, '');
  if (chiffres.length >= 6) {
    ajouter(chiffres);
    ajouter(chiffres.slice(-6));
  }

  return [...jetons];
}

/**
 * @param {string} password Mot de passe saisi.
 * @param {{firstName?: string, lastName?: string, email?: string, phone?: string}} [identite]
 * @returns {{valide: boolean, message?: string}}
 */
function verifierMotDePasse(password, identite = {}) {
  const mdp = String(password ?? '');

  if (!mdp) {
    return { valide: false, message: 'Le mot de passe est requis.' };
  }

  // Les caractères sont comptés, pas les octets : un accent ou un emoji vaut un
  // caractère du point de vue de la personne qui le tape.
  const longueur = [...mdp].length;
  if (longueur < LONGUEUR_MIN) {
    return {
      valide: false,
      message: `Le mot de passe doit contenir au moins ${LONGUEUR_MIN} caractères.`,
    };
  }
  if (longueur > LONGUEUR_MAX) {
    return {
      valide: false,
      message: `Le mot de passe ne peut pas dépasser ${LONGUEUR_MAX} caractères.`,
    };
  }

  const famillesPresentes = FAMILLES.filter((famille) => famille.test(mdp));
  if (famillesPresentes.length < 3) {
    return {
      valide: false,
      message:
        'Ajoutez au moins trois familles de caractères : minuscules, majuscules, chiffres ou caractères spéciaux.',
    };
  }

  const propre = nettoyer(mdp);
  if (INTERDITS.has(propre) || INTERDITS.has(neConserveQueLesLettres(propre))) {
    return {
      valide: false,
      message:
        'Ce mot de passe fait partie des plus courants. Choisissez-en un autre.',
    };
  }

  if (/(.)\1{3}/.test(mdp)) {
    return {
      valide: false,
      message: 'Évitez de répéter quatre fois le même caractère.',
    };
  }

  if (contientUneSuite(propre) || contientUneSuite(mdp.toLowerCase())) {
    return {
      valide: false,
      message:
        'Évitez les suites de caractères comme 1234 ou abcd, faciles à deviner.',
    };
  }

  for (const jeton of elementsPersonnels(identite)) {
    if (propre.includes(jeton)) {
      return {
        valide: false,
        message:
          'Le mot de passe ne doit pas reprendre votre nom, votre e-mail ou votre numéro de téléphone.',
      };
    }
  }

  return { valide: true };
}

module.exports = {
  FAMILLES,
  INTERDITS,
  LONGUEUR_MAX,
  LONGUEUR_MIN,
  REGLES,
  contientUneSuite,
  verifierMotDePasse,
};
