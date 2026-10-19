# Validation — 19 octobre 2026

## Vérifié

- Dépendances npm installées, audit sans vulnérabilité signalée.
- Tests Chums `npm test` : réussis (channel, hub, artefacts et runtimes simulés).
- `npm run test:klone` : 5 tests réussis (4 connecteur, 1 parcours HTTP iPhone simulé).
  - Journal privé, une demande à la fois, autorisation exacte et refus d’un identifiant périmé.
  - Échec HTTP lors du verdict : la demande reste ouverte, puis le refus est transmis.
  - Redémarrage du connecteur : lecture du même run, sans nouvelle soumission.
  - Soumission incertaine : nouvelle tentative avec la même clé d’idempotence.
  - Pièces jointes refusées avant création d’un run.
- Connecteur sur Hermès réel : réponse `KLONE_CHUMS_OK` dans une session QA isolée,
  sans outil et sans demande de mémorisation ; fil utilisateur Klone non utilisé.
- Whisper réel dans `binome` : deux transcriptions françaises réussies (environ 7 s à froid puis 3,3 s dans le même worker).
- API voix existante : Supertonic 3, français, disponible ; synthèse réelle WAV réussie.
- Route privée HTTPS Tailscale 8444 : active et contrôle authentifié réussi.
- Build signé Release : **BUILD SUCCEEDED** après acceptation de l’accord Apple.
- Installation et lancement sur l’iPhone physique confirmés par devicectl.
- Événement « phone: app active » reçu du client iPhone via la passerelle privée.
- Build `Chums` Release sans signature : **BUILD SUCCEEDED**, cibles iPhone,
  Watch et widgets incluses. Cela confirme la compilation, pas l’installation.

Journaux privés dans `.local/` : `upstream-tests.log`, `hermes-tests.log`,
`build-unsigned.log`, `build-iphone.log`, `klone-tests.log`. Ils ne sont pas publiés dans Git.

## État des prérequis externes

- Accord développeur Apple : accepté par Harry ; signature débloquée. Un premier téléchargement de profil manquant a été résolu par une seconde compilation.
- Tailscale : reconnecté par Harry sur Mac et iPhone ; route privée 8444 active.
  Configuration Aura 8443 conservée.
- Mode développeur de la Watch désactivé.

## À vérifier sur appareils

- Revue visuelle du rendu iPhone avec Harry (installation et lancement déjà confirmés).
- Autorisation micro et phrase vocale depuis l’iPhone.
- Notification/réception pendant changement d’app : pas de push prévu dans cette version.
- Watch, autorisations, reconnexion et réseau cellulaire.

Le doctor upstream vérifie WhisperKit, Claude et Funnel ; ces dépendances ne
sont pas requises dans notre mode Hermès/Whisper existant. Ses échecs initiaux
sur ces composants ne doivent pas déclencher leur installation.
