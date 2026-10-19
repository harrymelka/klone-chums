# Architecture Klone

```
iPhone / Watch (SwiftUI Chums)
          │ HTTP + token appareil, HTTPS privé à distance
          ▼
Passerelle Chums sur Mac (127.0.0.1:17771 / API appareils :17772)
   ├── klone/hermes.mjs → API profil Hermès existante :8642
   ├── klone/transcription.mjs → docker exec → Whisper local dans binome
   └── voix → passerelle Supertonic existante :8643 → AAC pour les appareils
```

Le worker de transcription est un processus Python persistant lancé dans le
conteneur existant. Il réutilise les paquets, réglages et poids déjà installés,
et conserve son modèle en mémoire entre demandes. Il ne réutilise pas le même
objet Python en mémoire que les autres processus Hermès. Aucun fichier source,
config ou service du conteneur n’est modifié ; un WAV temporaire est supprimé
après chaque demande. La fonction locale explicite interdit un repli cloud.

Le connecteur consomme les événements SSE d’outils et d’approbation. Le statut
HTTP du run reste la référence pour sa fin et les reprises. Le journal atomique
`hermes-pending.json` garde input, clé d’idempotence et identifiant de run, mode
0600. La clé est enregistrée avant soumission. Une reprise incertaine de plus de
23 heures n’est pas soumise à nouveau. Une tâche acceptée est relue, jamais
recréée. Le connecteur ne promet pas la reprise d’un moteur Hermès lui-même
interrompu définitivement.

Un seul compagnon actif et une tâche à la fois. Pas de nouvelle requête pendant
la précédente. La mémoire et les outils du profil existant sont conservés ; la
conversation Klone est distincte d’Aura pour éviter de mélanger les fils.

Les états d’affichage ne contiennent pas les raisonnements internes ni les
arguments bruts des outils. Les pièces jointes sont refusées avant soumission,
car un chemin du Mac ne constitue pas un fichier accessible depuis Docker.

Les identités Chums locales sont en lecture seule en mode Hermès. Les réglages
Claude/Codex sont masqués. Les personnages et leur moteur de rendu ne sont pas
modifiés. Les sept autres personnages sont conservés dans les sources, mais
ne constituent pas sept agents Hermès supplémentaires.

Les ports et secrets sont propres à ce checkout sous `.local/server`. Le jeton
Hermès reste côté serveur. Le jeton appareil est généré dans HubConfig.swift,
ignoré par Git ; l’appairage dynamique est une phase suivante.

Aucun service launchd, connexion fournisseur IA, tunnel public ou modification
de SOUL/mémoire n’est installé par les scripts Klone. Le serveur est un processus
local détaché ; double-cliquer le lanceur le redémarre si nécessaire.
