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
- `app/ChumsWatch/Chat.swift`, `ChumsWatchApp.swift` : micro et fermeture fixes dans le chat ; rechargement de la complication.
- `app/ChumsWidget/ChumsWidget.swift` : Noodle et dernier état, actualisation WidgetKit limitée par le système.
- `app/ChumsPhone/Stage.swift` : personnage sans cadre de montre ni couronne décorative sur iPhone.
- `app/ChumsWatch/Voice.swift` : voix système française de secours.
- `app/ChumsWatch/StayOn.swift` : maintien par API privée désactivé.

Nos modules et outils sont dans `klone/`. Le fichier XcodeGen original reste
inchangé ; `klone/prepare.py` génère une variante locale avec notre nom d’app.
Une mise à jour upstream n’est pas encore arrivée pendant cette intégration :
aucune fusion future n’est présentée comme déjà validée.

## Compagnon Mac et présentation iPhone claire

- `app/KloneMac/`, `klone/mac.yml`, `klone/build-mac.sh` : cible macOS séparée.
  Réutilise directement le rig Chums, avec son propre client de l’API appareils
  du hub existant. Aucun changement à la session Hermès ni au backend.
- `Renderer.draw` : fond optionnel, noir par défaut ; import UIKit conditionnel
  pour compiler sur Mac. Les rendus Watch hérités gardent leur comportement.
- `KloneHomeView.swift` : présentation iPhone propre au fork. `HomeView.swift`
  upstream conservé ; seul le point d’entrée iPhone sélectionne la nouvelle vue.
- `CharacterStage` : fond et agrandissement configurables, coordonnées tactiles
  inversées pour suivre l’agrandissement.
- Quatre poses PNG issues du rig dans `Shared/Characters.xcassets`, utilisées
  par le widget Watch. Le générateur local ajoute le schéma URL de la Watch.
- Maquettes et choix utilisateur dans `docs/klone/design/`.

## Retours d’usage : médias et interactions

- `KlonePhoneComponents.swift` : bulles et composants du panneau iPhone propre au fork.
- `Chat.swift` et `ChumsWatchApp.swift` : viewport borné, Crown explicite, exclusion
  de la Crown du personnage quand le chat est ouvert et footer intégré. Les APIs
  Crown sont conditionnées à watchOS car le fichier est partagé avec iPhone.
- `Controller.swift` : invitations de repos selon heure et activité réelle.
- Widgets iPhone/Watch : transitions d’état et poses ; pas de boucle continue.
- `MacModel` : pause/reprise et transcription avant envoi via la route dédiée.
- `hub/hub.mjs`, `klone/attachments.mjs`, `klone/hermes.mjs` : prévisualisation
  Whisper et transport multimodal des photos, même profil/session.
