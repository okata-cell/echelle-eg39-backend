# Cette copie du backend n'est pas déployée

Le service Render **`echelle-eg39-backend-1`** exécute
`/backend/src/server.js` **à la racine du dépôt**, pas ce dossier-ci.

Autrement dit : modifier un fichier ici ne change **rien** en production.
C'est arrivé le 6 novembre 2026 avec la page `/tester` et les pages légales :
ajoutées ici, déployées, toujours en 404 sur le site en ligne.

## Comment savoir laquelle tourne

Sur l'API en production :

| Route | Réponse | Signification |
| --- | --- | --- |
| `GET /api/locations/check-expired` | `401` | La route existe : c'est le backend `backend/` qui tourne |
| `GET /api/auth/account` | `404` | La route n'existe que dans ce dossier-ci : il n'est pas déployé |

## Ce qui a divergé entre les deux copies

| Élément | `backend/` (déployé) | ce dossier (non déployé) |
| --- | --- | --- |
| `routes/public_pages.js` (pages légales + `/tester`) | oui, actif en ligne | oui |
| `services/cloudinary_storage.js` | oui | non |
| `utils/rental_dates.js` | oui | non |
| `package.json` | mêmes dépendances + `cloudinary`, `multer` | sans `cloudinary` |
| `server.js` | monte les pages publiques | monte les pages publiques, mais démarre inconditionnellement |

## Que faire d'un correctif écrit ici

Le porter dans `backend/src/` avant de committer. Le plus sûr reste de
supprimer cette copie un jour prochain : deux arbres qui divergent est la cause
directe de la perte de correctifs.

## Fichiers de déploiement

- Définition de référence : `/render.yaml` (racine du dépôt).
- `echelle_eg_39/render.yaml` est conservé mais marqué obsolète : ses commandes
  pointent vers ce dossier-ci et ne décrivent pas le service en ligne.
