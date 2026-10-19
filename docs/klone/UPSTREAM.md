# Suivre les mises à jour Chums

- `origin` : notre fork `harrymelka/klone-chums`.
- `upstream` : dépôt original `lcoutodemos/chums`.
- `upstream-main` : référence locale suivant `upstream/main`, sans nos modifications.
- `main` : version Klone intégrée.
- `codex/hermes-iphone` : branche d’implémentation initiale.

## Examiner puis intégrer une nouvelle version

```sh
git fetch upstream
git log --oneline HEAD..upstream/main
git diff HEAD...upstream/main -- hub app
# Partir d’un checkout propre ; créer une branche de maintenance dédiée.
git switch -c codex/update-chums-YYYYMMDD main
git merge upstream/main
npm ci --ignore-scripts
npm test
node --test klone/test-hermes.mjs
```

Vérifier le build et refaire la recette iPhone avant de fusionner dans `main`.
Ne jamais réinitialiser notre branche sur upstream ou utiliser `--force` pour
absorber une mise à jour. En cas de conflit, revoir le comportement final,
notamment la réception des ordres, les autorisations, le statut et la voix.
Les secrets générés restent ignorés. Le dossier `.local` ne doit jamais entrer
dans une proposition de modification ou une archive publique.

## Surface de modifications à surveiller

- `hub/runtimes.mjs` : enregistrement du connecteur Hermès.
- `hub/hub.mjs` : configuration isolée, fournisseurs voix, historique, acheminement
  asynchrone et confirmation d’autorisation, absence de soul Claude en mode Hermès.
- `app/ChumsPhone/AgentSheet.swift`, `app/ChumsWatch/Soul.swift` : réglages Hermès en lecture seule.
- `app/ChumsWatch/Voice.swift` : voix système française de secours.
- `app/ChumsWatch/StayOn.swift` : maintien par API privée désactivé.

Nos modules et outils sont dans `klone/`. Le fichier XcodeGen original reste
inchangé ; `klone/prepare.py` génère une variante locale avec notre nom d’app.
Une mise à jour upstream n’est pas encore arrivée pendant cette intégration :
aucune fusion future n’est présentée comme déjà validée.
