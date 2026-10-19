# Klone Chums — commencer ici

Application iPhone et Apple Watch basée sur Chums, avec son design et Noodle,
connectée à notre profil Hermès existant. Ce dossier est indépendant d’AppleBrainAi.

## Essayer

1. Docker doit faire tourner `binome` et sa passerelle Hermès existante.
2. Sur le Mac et l’iPhone, connecter Tailscale au réseau privé habituel.
3. Double-cliquer **Lancer Klone Chums.command** dans ce dossier.
4. Ouvrir **Klone Chums** sur l’iPhone, puis écrire ou maintenir le micro pour parler.

Le lancement démarre uniquement notre serveur local. Aucun agent Claude/Codex,
aucun second modèle Whisper et aucun service au démarrage de session n’est installé.
La lecture audio utilise notre Supertonic français existant ; en cas d’indisponibilité,
le texte reste disponible et le client peut utiliser sa voix Apple française.

## Installation initiale sur iPhone

L’accord Apple Developer doit être à jour sur developer.apple.com/account.
Ensuite, depuis ce dossier :

```sh
python3 klone/prepare.py
python3 klone/start.py
klone/build-iphone.sh
```

Le build signé est dans `app/build/sym/Release-iphoneos/Chums.app`.
Installer puis lancer avec `python3 klone/install-iphone.py` (un seul iPhone appairé disponible), ou utiliser Xcode.

Au 19 octobre 2026 : build signé, installation et lancement sur l’iPhone de Harry confirmés ; route privée active.
L’identifiant est `com.harry.klonechums` : il ne remplace pas Aura.
Le projet généré `app/Chums.xcodeproj` s’ouvre dans Xcode.

La connexion distante utilise une route Tailscale Serve privée dédiée au port 8444,
vers `http://127.0.0.1:17772`. Après reconnexion de Tailscale sur le Mac :

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=8444 http://127.0.0.1:17772
```

C’est une route privée ; aucun Funnel public n’a été créé. Le port Aura 8443 reste inchangé.
La route a été activée pour cette installation ; la commande ci-dessus permet de la rétablir si nécessaire.
Contrôle en lecture seule : `python3 klone/check.py`.

## Ce que cette version fait

- Conversation texte et capture vocale avec le design Chums.
- Un compagnon actif, Noodle, relié au profil Hermès `klone-aura`.
- Conversation dédiée `klone-chums-main` : même mémoire de profil, fil séparé d’Aura.
- Réponses complètes sur iPhone, états de travail et cartes d’autorisation.
- Reprise d’une tâche déjà acceptée après redémarrage du serveur.
- Transcription via le Whisper déjà installé dans `binome`, sans fournisseur cloud.
- Réglages de personnalité/modèle/autorisations conservés dans Hermès.

## Limites à connaître pour cet essai

- Pas encore de pièces jointes vers Hermès (l’envoi est refusé explicitement).
- Pas de notifications push lorsque l’app iPhone est fermée.
- Un seul échange à la fois ; attendre la réponse avant d’envoyer la suite.
- Le Mac, Docker, Hermès et la connexion privée doivent rester disponibles.
- La Watch doit avoir son mode développeur activé avant installation.
- Mode porte-clés non validé ; maintien d’écran par API privée désactivé.
- La configuration des appareils est encore générée à la compilation ; pas encore de QR code.
- Le protocole protège la reprise serveur ; un nouvel envoi manuel constitue une nouvelle demande.

## Suivi et maintenance

- [Plan et avancement](docs/klone/PLAN.md)
- [Architecture et limites](docs/klone/ARCHITECTURE.md)
- [Mises à jour Chums](docs/klone/UPSTREAM.md)
- [Validation](docs/klone/VALIDATION.md)

Les secrets restent dans `.local/` et dans le fichier Swift généré ignoré par Git.
Ne pas partager les builds, fichiers de connexion ou journaux privés.
Le README original de Chums est conservé pour faciliter le suivi upstream.

## Installer sur la Watch

Sur la montre : **Réglages → Confidentialité et sécurité → Mode développeur**.
Activer, accepter le redémarrage, déverrouiller puis confirmer **Activer**.
Garder la Watch déverrouillée près de l’iPhone ; le Mac doit pouvoir la joindre.

```sh
python3 klone/install-watch.py
```

Le script vérifie le mode développeur avant l’installation. Le même build iPhone
contient le binaire Watch signé. La montre utilise la même passerelle privée et
la même conversation Hermès ; aucun nouveau profil ni fournisseur IA n’est créé.

## Comprendre le vocal

- Parole entrante : enregistrement sur l’appareil, transcription par Whisper local dans `binome`.
- Réponse écrite : notre profil Hermès et son fournisseur de modèle existant.
- Réponse parlée : Supertonic 3 local, préréglage F1 pour l’essai actuel, livré en AAC.
- Si l’audio local manque : le client peut utiliser sa voix Apple française de secours.

Les préréglages F1, F3, M1 et M3 sont disponibles dans la passerelle existante.
Les exemples locaux sont sous `.local/voice-previews/`, non publiés dans Git.
Ces voix restent des préréglages synthétiques ; changer d’avatar ne leur donne
pas une voix différente automatiquement.

## Chat et complication Watch

Le chat possède maintenant une barre fixe : **Parler**, puis **Envoyer** pendant
l’enregistrement, avec **Annuler** et une fermeture du chat accessible sans remonter.
Fermer le chat ou quitter l’app annule un enregistrement encore en cours.

La complication du cadran montre Noodle et un état court lorsque le format le
permet. La toucher ouvre le chat et lance le micro ; l’envoi reste explicite avec
**Envoyer**. Le micro ne tourne jamais dans la complication elle-même.
La complication ne montre aucun message privé. Les actualisations sont soumises
au budget WidgetKit, pas à une boucle d’animation permanente. Un état non actualisé
depuis quinze minutes revient à **Parler**, sans afficher une ancienne tâche pour ne pas laisser une ancienne
activité ou autorisation affichée comme actuelle.

Une nouvelle image peut nécessiter de retirer puis remettre la complication
existante dans le cadran si watchOS conserve son ancien aperçu en cache.

## Compagnon Mac

Double-cliquer **Lancer le compagnon Mac.command**. Le personnage apparaît sur
le bureau, sans fond noir. Le bouton **Parler** ouvre la conversation et demande
l’autorisation macOS du microphone au premier usage. Cliquer ensuite **Envoyer**
ou **Annuler**. Un clic sur le personnage ouvre seulement le fil.

La petite poignée au-dessus du personnage permet de le déplacer. Le menu Klone
Chums dans la barre de menus permet de retrouver le fil, masquer le personnage,
le replacer ou quitter. Aucun lancement automatique à l’ouverture de session.

Le client Mac utilise la passerelle locale existante, la même session
`klone-chums-main` que l’iPhone et la Watch, Whisper dans `binome` et la synthèse
Supertonic existante. Seules les réponses demandées depuis le Mac y sont lues ;
l’historique n’est pas relu au démarrage. Le bouton haut-parleur coupe les réponses
vocales. Fermer la fenêtre ou mettre le Mac en veille annule un enregistrement
en cours. Un enregistrement de plus d’une minute est annulé, sans envoi.

Pour reconstruire : `klone/build-mac.sh`. L’app signée reste dans
`app/build/mac/products/Release/Klone Chums Mac.app`.

## Présentation iPhone choisie

Harry a choisi la piste **B, fond clair**, avec le **fil visible** de C :
Noodle en grand sur un fond chaud, sans carré de montre, derniers échanges
défilants en dessous, commandes fixes en bas. Une commande agrandit le fil.
La proposition interactive est dans `docs/klone/design/index.html` (paramètre
`?selected=1` pour le choix retenu). Les textes des maquettes sont fictifs.

Sur le cadran Watch, une seule indication remplace le doublon micro/Prêt :
**Parler** au repos, ou l’état courant. Noodle change de pose ; un **?** apparaît
s’il attend une réponse. Les transitions sont courtes et dépendent de watchOS ;
l’animation continue est réservée à l’app ouverte et au compagnon Mac.
