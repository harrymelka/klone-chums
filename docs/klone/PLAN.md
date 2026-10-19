# Plan Klone Chums — suivi des intégrations

Décision du 19 octobre 2026 : Chums comme socle produit, Hermès comme cerveau,
iPhone puis Watch en priorité. Conserver le design upstream avant toute refonte.

## 1 — Socle et suivi upstream

- [x] Dossier séparé `~/Project/Klone Chums`.
- [x] Fork `harrymelka/klone-chums`, remote `upstream` vers `lcoutodemos/chums`.
- [x] Base auditée : `6821bd6e1aa3d3fb41ca77bd0cc4de0dbbb8097a`.
- [x] Modules Klone dédiés ; moteur de personnages conservé.
- [x] État local, ports et identifiants d’app distincts d’Aura et de Chums original.
- [ ] Première fusion d’une nouvelle version upstream quand elle sera disponible.

## 2 — Hermès et conversation iPhone

- [x] Connecteur HTTP utilisant les runs durables et leur idempotence.
- [x] Profil existant `klone-aura`, conversation séparée `klone-chums-main`.
- [x] Historique et réponse complète ; pas d’injection de personnalité Chums concurrente.
- [x] États outils et attente d’autorisation.
- [x] Journal local privé de la tâche en cours et reprise après redémarrage.
- [x] Autorisations exactes confirmées côté Hermès avant affichage du verdict.
- [x] Tests simulés de coupure, reprise et refus d’autorisation.
- [x] Échange réel de contrôle dans une session QA séparée.
- [x] Compilation iPhone et Watch sans signature.
- [x] Accord Apple accepté, build signé, installation et lancement iPhone confirmés.
- [ ] Revue visuelle et conversation sur l’iPhone physique.

## 3 — Voix locale

- [x] Réutiliser Whisper dans `binome`, confirmé par Harry.
- [x] Worker persistant via Docker ; aucun deuxième modèle installé sur le Mac.
- [x] Appel strictement local, sans repli vers un fournisseur cloud.
- [x] Deux transcriptions réelles du même échantillon français : modèle réutilisé dans le worker.
- [x] Fournisseur HTTP configurable pour une future machine partagée distincte.
- [x] Raccordement à la synthèse Supertonic française déjà disponible.
- [ ] Recette vocale depuis le micro iPhone avec Harry.

## 4 — Watch et réseau

- [x] Conserver les écrans, gestes, animations et widgets upstream.
- [x] Désactiver l’appel à l’API privée de maintien d’écran.
- [x] Préparer une route HTTPS privée dédiée sans toucher à Aura.
- [x] Tailscale reconnecté ; route Serve privée 8444 active et joignable.
- [x] L’app iPhone a rejoint la passerelle privée (événement de lancement reçu).
- [x] Activer le mode développeur Watch.
- [x] Installation et lancement sur Watch physique confirmés.
- [x] Harry confirme que l’application Watch fonctionne et affiche la conversation.
- [ ] Validation des autorisations sur Watch physique.
- [x] Installer le micro fixe dans le chat Watch (build signé et lancement confirmés).
- [ ] Vérifier avec Harry les boutons Parler / Envoyer / Annuler / Fermer dans le chat.
- [x] Installer la complication personnage + état + raccourci micro, choix 1 et 3 de Harry.
- [x] Installer le cadran simplifié : un libellé, poses de Noodle selon l’état, point d’interrogation.
- [ ] Vérifier avec Harry le rendu du cadran et le lancement vocal au toucher.
- [ ] Essais autre Wi-Fi / cellulaire ; autonomie distante non revendiquée avant ces essais.

## 5 — Suite après validation du cœur

- [ ] Photos puis fichiers : transfert explicite Mac ↔ conteneur.
- [x] Retirer le cadre de montre et la couronne décorative du personnage sur iPhone.
- [ ] Choix d’apparence sans multiplier profils et mémoires.
- [ ] Appairage dynamique / QR code, révocation par appareil.
- [ ] Notifications push et comportement en arrière-plan.
- [x] Compagnon Mac natif : Noodle animé transparent, fenêtre de conversation, texte et capture vocale.
- [x] Mac relié au même fil `klone-chums-main`, sans nouveau profil.
- [ ] Recette vocale Mac avec autorisation du micro par Harry.
- [x] Proposer trois compositions iPhone avec le personnage existant.
- [x] Choix de Harry : B, fond clair, avec le fil visible de C.
- [x] Installer et observer le fond clair, le grand personnage et le fil partagé sur iPhone physique.
- [ ] Recette des contrôles de la nouvelle vue iPhone avec Harry.
- [ ] Personnage original, plus tard.

## Critère de première livraison validée

Depuis l’iPhone : parler/écrire → traitement Hermès → réponse → retrouver le fil
après coupure ; autoriser/refuser la demande exacte sans faux succès.
Depuis la Watch : même compagnon et même fil, puis recette réseau réelle.
Ne cocher les validations sur appareil qu’après leur observation.

## Retours d’essai — conversation, présence et médias

- [x] Photo iPhone : import via « + », aperçu, compression et envoi multimodal à Hermès.
- [x] Reconnaissance réelle d’une image synthétique en session QA isolée ; même profil, sans toucher au fil utilisateur.
- [x] Prévisualisation vocale Mac séparée de l’envoi, Whisper partagé réutilisé.
- [x] Pause, reprise, annulation, niveau micro, transcription modifiable et envoi explicite sur Mac.
- [x] Salutations/invitations selon l’heure et l’activité réelle, questions et accords distincts.
- [x] Apparences iPhone : liste illustrée, nom et sélection ; fil Hermès conservé.
- [x] Chat iPhone superposé : canevas plein écran, panneau coulissant à trois tailles, bulles gauche/droite.
- [x] Avatar conservé pendant la saisie, clavier clair et fermeture explicite ou toucher hors clavier.
- [x] Widgets : transitions courtes et vraies poses/états, sans boucle d’animation prétendue.
- [ ] Validation physique du nouveau panneau iPhone et de la saisie avec Harry.
- [ ] Validation vocale Mac (pause/reprise et relecture) avec Harry.
- [ ] Défilement Watch : correctifs manuels rejetés en essai ; ScrollView natif en overlay également rejeté ; isoler en présentation système, rétablir swipe fermeture, validation physique requise.

## Retours suivants — iPhone immersif et vocal

- [x] Contrôles supérieurs sous la barre système, canevas intégral conservé.
- [x] Chat sans gros titre ni toolbar ; fermeture par tirage bas ou toucher extérieur.
- [x] Vocal iPhone : capture/transcription annulables, relecture avant envoi Hermès.
- [ ] Recette physique du clavier, des gestes et de l’annulation avec Harry.
