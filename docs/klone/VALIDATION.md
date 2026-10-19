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
- Mode développeur de la Watch activé après reconnexion ; installation autorisée.

## À vérifier sur appareils

- Revue visuelle du rendu iPhone avec Harry (installation et lancement déjà confirmés).
- Autorisation micro et phrase vocale depuis l’iPhone.
- Notification/réception pendant changement d’app : pas de push prévu dans cette version.
- Watch, autorisations, reconnexion et réseau cellulaire.

Le doctor upstream vérifie WhisperKit, Claude et Funnel ; ces dépendances ne
sont pas requises dans notre mode Hermès/Whisper existant. Ses échecs initiaux
sur ces composants ne doivent pas déclencher leur installation.

## Correction iPhone et préparation Watch

- Le cadre arrondi simulant une montre et la couronne décorative ont été retirés
  de `CharacterStage` sur iPhone. Les gestes et le moteur de rendu sont conservés.
- Build signé réussi, mise à jour iPhone installée et lancée.
- Capture sur iPhone : personnage compact directement dans l’app. La vue agrandie
  reste à revoir avec Harry ; la capture suivante a coïncidé avec son utilisation
  des Réglages et ne constitue pas une preuve de la vue agrandie.
- Appairage Watch/Mac renouvelé. La vérification directe et une tentative réelle
  d’installation confirment le mode développeur désactivé. L’installation est
  refusée par le système (montage DDI interdit tant que ce mode est désactivé).
- Le script `klone/install-watch.py` est prêt ; l’activation et la confirmation
  après redémarrage doivent être faites sur la montre.
- Le dernier échange vocal journalisé a utilisé l’audio Supertonic fourni par
  Hermès, et non le repli Apple. Quatre extraits F1/F3/M1/M3 ont été générés
  localement pour comparaison ; le préréglage actuel F1 n’a pas été changé.

## Reconnexion Watch après activation annoncée

Harry indique avoir activé le mode développeur. La Watch reste déconnectée de
CoreDevice et les informations de développement retournées sont en cache.
L’installation directe a expiré après 45 secondes ; elle n’est pas présentée
comme réussie. Le script n’interprète désormais plus une valeur « disabled »
provenant d’une montre déconnectée comme une lecture actuelle. Le système Apple
reste responsable de vérifier le mode avant d’autoriser l’installation.
Un câble iPhone–Mac et les deux appareils déverrouillés ont été demandés pour
rétablir la connexion. Aucune app Watch installée n’a été supprimée.

## Watch installée et lancée

Le mode développeur a été rafraîchi à `enabled` après reconnexion de l’iPhone
par câble. `python3 klone/install-watch.py` a ensuite réussi : installation de
`com.harry.klonechums.watchkitapp`, puis lancement confirmé par devicectl.
La capture suivante a échoué car la liaison de développement avec la montre
s’est interrompue. Aucun événement HTTP de la montre n’a encore été observé
au moment de cette vérification ; sa connexion à la passerelle et le parcours
vocal restent à tester avec Harry. Installation n’équivaut pas à validation réseau.

## Chat Watch et complication — 19 octobre 2026

- Harry confirme que l’app fonctionne sur la Watch et affiche la conversation.
- Ajout de commandes fixes au bas du chat : Parler, Envoyer, Annuler et Fermer.
  Fermer le chat ou passer en arrière-plan annule un enregistrement en cours.
- Complication : personnage, dernier état disponible et raccourci micro, selon
  le choix « 1 et 3 » de Harry. Le toucher ouvre le chat et demande le micro ;
  l’envoi reste explicite. Les mises à jour dépendent de WidgetKit. Un état
  vieux de quinze minutes est remplacé par « Ouvrir ».
- Build Release signé réussi avec les cibles Watch, widgets et iPhone.
  Mise à jour installée et lancée sur les deux appareils physiques.
- Lancement de l’URL `klonechums://talk` tenté avec le mode de capture sans
  micro réel ; devicectl confirme le lancement, pas l’état visuel du chat.
  L’app a ensuite été relancée sans ces options de test.
- La capture Watch est noire (écran en veille) : le rendu du pied de chat,
  du cadran et le parcours vocal au toucher restent à confirmer avec Harry.
- Aucun changement au moteur vocal, à Whisper ou à l’interface Mac dans cette
  mise à jour. Le Mac héberge le serveur ; une interface compagnon reste à faire.

## Mac et choix visuels — 19 octobre 2026

- Cible macOS Release compilée, signée avec l’équipe existante et vérifiée par
  `codesign --verify --deep --strict`. Aucun service au login n’a été ajouté.
- Le contrôle intégré `-selfCheck YES` a décodé l’état réel depuis l’API appareils
  locale et retrouvé douze lignes du fil partagé. Aucun message n’a été envoyé.
  Les secrets, les identifiants du fil et la cible Whisper ont été vérifiés sans
  imprimer leurs valeurs privées.
- Vérification native : personnage sans carré noir, deux captures avec des poses
  différentes, ouverture du chat au clic, historique réel présent, saisie activant
  Envoyer puis effacement du brouillon sans envoi. Le défilement laisse les
  commandes texte et vocal accessibles. Le dernier build Mac est lancé.
- Le test vocal au microphone Mac et la lecture d’une nouvelle réponse restent
  à faire avec Harry ; aucun son ambiant n’a été enregistré pendant les contrôles.
- Trois maquettes rendues avec le rig Chums ; Harry retient B (fond clair), avec
  la conversation visible de C. La maquette interactive a été contrôlée dans
  le navigateur, y compris les changements de pose et le point d’interrogation.
- Première compilation iPhone de la nouvelle vue claire réussie. Build final,
  installation et revue physique de cette vue consignés ci-dessous après exécution.

- Build final iPhone/Watch signé réussi et installation confirmée sur les deux
  appareils. Premier lancement iPhone refusé parce que verrouillé, puis lancement
  réussi après le « go » de Harry. La Watch a été installée et lancée également.
- Deux captures iPhone physiques : première au raccordement, deuxième avec
  connexion rétablie, historique partagé affiché, fond clair et commandes fixes.
  Le recadrage final remonte légèrement Noodle pour corriger la queue coupée.
- Le rendu du nouveau cadran et sa transition à un changement d’état restent à
  valider sur la Watch ; l’installation seule n’est pas présentée comme cette preuve.

- Recadrage final recompilé, signé, installé et lancé sur iPhone. La capture
  physique confirme la queue entière dans la scène, sans bord noir. Les commandes
  de capture ont été exécutées sans démarrer le microphone.
- Contrôle final `klone/check.py` : hub, capacités Hermès, voix française, route
  privée appareils et Whisper dans le conteneur existant tous disponibles.
- Analyse des sources non ignorées : aucun des secrets de connexion locaux
  retrouvé dans les fichiers à publier. `git diff --check` et vérifications de
  syntaxe des scripts Python/zsh réussis.

## Retours d’usage — médias, saisie et défilement

- `npm run test:klone` : six tests réussis, couvrant reprise/idempotence/accords,
  photos multimodales et rejets avant exécution, preview vocale sans création
  d’ordre, audio vide et absence de parole reconnue.
- Vision Hermès réelle : image synthétique rouge reconnue dans une session QA
  isolée. Aucun message photo ajouté au fil utilisateur.
- Whisper réel dans binome : échantillon synthétique transcrit par la nouvelle
  route, sans changement du fil ni des accords. Aucun micro ambiant enregistré.
- Builds Release signés iPhone/Watch et Mac réussis ; vérification de signature
  Mac réussie. Installation/lancement des apps physiques confirmés.
- Capture iPhone : canevas plein écran et commandes flottantes confirmés.
  Panneau, clavier et gestes restent à valider en usage avec Harry.
- Mac : rendus natifs hors ligne des états repos, enregistrement, pause et
  relecture contrôlés ; transcription lisible et boutons accessibles. La capture
  vocale physique et la lecture d’une nouvelle réponse restent à confirmer.
- Watch : le premier correctif a échoué au doigt et à la couronne selon Harry.
  Nouvelle version installée : hauteur du viewport bornée, Crown explicite et
  diagnostics privés de géométrie/offset sans texte des messages. Confirmation
  physique demandée, non déduite du succès de compilation.
- Suite upstream : tests channel/hub et runtimes réussis ; quatre tests de
  dimensions du renderer artifacts échouent également sur HEAD initial 48435ff
  (1200 au lieu de 780). Aucun fichier de ce renderer modifié ici.
- Deux préparations simultanées réussies après ajout du verrou local.

## Régression Watch confirmée puis retour au défilement natif

Harry confirme que la Crown remontait le fil dans les deux sens et que le doigt
et l’ouverture restaient défaillants. Les logs montrent bien un viewport de
163 points pour plus de 2300 points défilables ; l’hypothèse précédente d’une
absence de hauteur n’explique donc pas ce comportement. Les offsets reviennent
brutalement vers le début pendant le pilotage manuel.

Le nouveau correctif supprime ScrollPosition et digitalCrownRotation du chat :
le ScrollView natif reçoit le focus, le suivi géométrique reste en lecture seule.
Le fil n’est plus inséré pendant le geste d’ouverture, une vraie poignée bouton
l’ouvre, et aucune gesture de fermeture ne recouvre ses messages. Compilation
Release iPhone/Watch réussie. Aucun runtime simulateur n’est installé sur ce Mac ;
le test des gestes physiques reste à confirmer, sans l’assimiler au build.

Le nouvel essai physique échoue aussi : indicateur clignotant, Crown sans effet,
fermeture par balayage absente. Cette version n’est donc pas validée. Le chat
Watch est repris dans une présentation système séparée du canevas, avec retrait
du focus explicite et des mesures de scroll écrites en état local.

## iPhone : contrôles, panneau et relecture vocale

- Canevas isolé dans un overlay de taille fixe, pour ne plus agrandir la mesure
  de la pile de commandes. Header positionné par rapport à la safe area réelle
  de la fenêtre, sans changer l’étendue du canevas.
- Gros titre et toolbar du fil supprimés. Fermeture par poignée vers le bas,
  surdéfilement natif depuis le début du fil ou toucher extérieur ; cette couche
  bloque les interactions avec le personnage pendant la fermeture.
- Capture iPhone opt-in vers `/v1/transcribe` : Annuler, Terminer, puis brouillon
  éditable et Envoyer. L’annulation de transcription invalide le résultat tardif.
  Aucun enregistrement ambiant réalisé pour vérifier ces changements.
- Six tests `test:klone` réussis ; compilation Release iPhone/Watch réussie après
  correction d’une signature d’action d’accessibilité. Diff et scan secrets propres.
- Installation iPhone confirmée. Lancement de contrôle bloqué par le verrouillage
  physique ; nouvelle installation Watch en cours après une expiration du tunnel.
  Les gestes et l’annulation vocale restent à confirmer sur appareil.

Après déverrouillage confirmé par Harry : lancement iPhone réussi, installation
et lancement Watch réussis. Capture iPhone physique : commandes sous la barre
système, canevas complet, fil superposé sans titre/toolbar et poignée présents.
Le lancement de capture forçait le fil visible via argument temporaire ; l’app
a ensuite été relancée normalement. Aucun micro démarré par ces contrôles.
La fermeture gestuelle, la Crown Watch et l’annulation vocale restent à confirmer
en usage ; aucune réussite physique n’est déduite de la seule installation.

## Révision 0.3 (3) — contrôle direct des interfaces

- Runtime watchOS 27 installé et simulateur `Klone QA Watch` créé. Xcode 27
  utilise Device Hub pour sa fenêtre de contrôle. Le téléchargement iOS 27 a
  été refusé faute d’espace (8,07 Go demandés) ; l’iPhone physique a été contrôlé
  via Device Hub et captures devicectl.
- Plusieurs captures simulateur ont révélé que la première correction de hauteur
  était encore insuffisante. La version finale utilise une page native explicite,
  ignore les anciens insets de navigation, réserve 28 points pour l’horloge et
  clippe le viewport. Les captures finales montrent poignée sous l’horloge,
  fil sur la hauteur restante et Parler au bas, sans croix ni chevron.
- Le nouveau bouton bulle ouvre effectivement le chat dans le simulateur.
  Plusieurs positions de l’historique ont été observées. Les gestes drag/wheel
  de Device Hub n’ont pas permis une recette fiable de chaque sens de Crown
  et du swipe ; le comportement natif confirmé par Harry avant cette révision
  est conservé. Aucun succès supplémentaire de ces gestes n’est prétendu.
- iPhone réel : composer compact, champ focalisé et texte synthétique saisi
  sans envoi ; Envoyer remplace le micro. La sheet native medium affiche
  l’historique sans assombrir le personnage. Ouverture via bouton et fermeture
  par toucher extérieur vérifiées dans le build final, captures privées gardées.
  Le clavier matériel de Device Hub était utilisé pour ce contrôle de saisie.
- Builds Release signés iPhone/Watch/Mac et build simulateur réussis. Version
  0.3 (3) installée/lancée sur les appareils physiques. Aucun flag de capture
  laissé sur l’iPhone physique.
- Mac : signature vérifiée, contrôle API réel réussi (18 lignes, audio initial
  silencieux). Les deux démarrages vocaux n’appellent plus l’ouverture du chat.
  Le processus précédent est resté ouvert pour conserver son brouillon vocal ;
  le nouveau binaire attend sa relance, sans perte du brouillon ni faux essai micro.

Contrôle de fin : hub local et route privée appareils HTTP 200 ; Hermès et
la voix ont expiré à cinq secondes. `docker ps` et le diagnostic d’import Whisper
se sont également bloqués ; les processus de diagnostic locaux ont été arrêtés,
sans redémarrer le conteneur partagé. Docker Desktop n’a pas répondu au contrôle
d’interface. Ceci bloque une nouvelle recette vocale de bout en bout, sans
changement backend dans cette révision. Les succès antérieurs ne remplacent pas
ce constat de fin. Le simulateur Watch a été éteint après les contrôles.
