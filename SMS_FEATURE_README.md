# Envoi d'Alertes par SMS (Mode Hors-Ligne)

## Vue d'ensemble

Cette fonctionnalité permet d'envoyer une alerte par SMS lorsqu'elle est créée sans connexion internet, offrant une alternative de communication même en cas d'absence de réseau mobile data.

## Fonctionnement

### 1. Scénario de création d'alerte hors-ligne

**Flux utilisateur :**

1. L'utilisateur crée une alerte sans connexion internet
2. L'alerte est sauvegardée localement
3. Un dialogue apparaît proposant d'envoyer l'alerte par SMS
4. Si l'utilisateur accepte :
   - L'application SMS native s'ouvre
   - Le message est pré-rempli avec les détails de l'alerte
   - L'utilisateur peut :
     - Choisir le destinataire (numéro de téléphone)
     - Modifier le message si nécessaire
     - Envoyer ou annuler

### 2. Format du message SMS

Le message SMS contient :
- 🚨 En-tête "ALERTE SYSTÈME"
- **Type** : Type d'alerte traduit (Inondation, Sécheresse, etc.)
- **Sévérité** : Niveau de gravité (Information, Faible, Critique, etc.)
- **Titre** : Titre de l'alerte
- **Message** : Description détaillée
- **Zone** : Zone géographique concernée
- **Date de début** : Quand l'alerte commence
- **Instructions** : Actions à prendre (si spécifiées)
- **Action requise** : Indication si une action est nécessaire
- Signature automatique

**Exemple de message formaté :**
```
🚨 ALERTE SYSTÈME

Type: Inondation
Sévérité: Critique

TITRE: Crue importante du fleuve

MESSAGE: Niveau d'eau critique atteint dans la zone. Risque de débordement imminent.

Zone: Commune de Niamey
Début: 12/01/2026 14:30

INSTRUCTIONS: Évacuer les zones basses. Se diriger vers les points de regroupement.

⚠️ ACTION REQUISE

---
Message envoyé via Système d'Alerte Précoce
```

### 3. Envoi depuis la page de synchronisation

Dans la page de synchronisation des alertes :
- Chaque alerte non synchronisée a un menu ⋮ (trois points)
- Option "Envoyer par SMS" disponible
- Même dialogue et même processus que lors de la création

## Implémentation technique

### Fichiers créés

**`core/utils/sms_helper.dart`**

Classe utilitaire avec trois méthodes principales :

```dart
// Formater une alerte en message SMS
String formatAlertToSms(Map<String, dynamic> alertData)

// Ouvrir l'app SMS native avec le message
Future<bool> sendSms({String? phoneNumber, required String message})

// Afficher le dialogue de confirmation
Future<bool?> showSmsDialog(BuildContext context, Map<String, dynamic> alertData)
```

### Fichiers modifiés

1. **`create_alert.dart`**
   - Import de `SmsHelper`
   - Après sauvegarde locale, appel de `SmsHelper.showSmsDialog()`
   - Si accepté, ouverture de l'app SMS

2. **`sync_alerts_page.dart`**
   - Import de `SmsHelper`
   - Ajout d'un `PopupMenuButton` sur chaque alerte
   - Option "Envoyer par SMS" dans le menu

3. **`pubspec.yaml`**
   - Ajout de `url_launcher: ^6.3.1`

## Utilisation

### Pour l'utilisateur

**Création d'alerte hors-ligne :**

1. Remplissez le formulaire d'alerte normalement
2. Cliquez sur "Envoyer"
3. Message "📴 Pas de connexion. Alerte sauvegardée localement"
4. Dialogue : "Voulez-vous également l'envoyer par SMS ?"
5. Cliquez sur "Ouvrir SMS"
6. L'application SMS s'ouvre avec le message pré-rempli
7. Choisissez le destinataire
8. Modifiez le message si nécessaire
9. Envoyez

**Depuis la synchronisation :**

1. Allez dans Dashboard → Icône ☁️ (synchronisation)
2. Pour chaque alerte, cliquez sur ⋮ (trois points)
3. Sélectionnez "Envoyer par SMS"
4. Suivez le même processus

### Pour le développeur

**Utilisation du SmsHelper :**

```dart
// Formater une alerte en SMS
final message = SmsHelper.formatAlertToSms(alertData);

// Envoyer directement (ouvre l'app SMS)
await SmsHelper.sendSms(
  phoneNumber: '+22790123456', // Optionnel
  message: message,
);

// Avec dialogue de confirmation
final sendSms = await SmsHelper.showSmsDialog(context, alertData);
if (sendSms == true) {
  await SmsHelper.sendSms(message: SmsHelper.formatAlertToSms(alertData));
}
```

**Personnaliser le format du message :**

Modifiez la méthode `formatAlertToSms()` dans `sms_helper.dart` pour adapter :
- L'ordre des informations
- Les emojis
- Les traductions
- Le format des dates

## Limitations et considérations

### Limitations techniques

1. **Longueur du SMS** : Les messages SMS standards sont limités à 160 caractères (320 pour Unicode). Les messages plus longs seront divisés en plusieurs SMS.

2. **Pas d'envoi automatique** : Pour des raisons de sécurité, l'application ne peut pas envoyer de SMS automatiquement. Elle ouvre seulement l'app SMS native.

3. **Support plateformes** :
   - ✅ Android : Fonctionne parfaitement
   - ✅ iOS : Fonctionne parfaitement
   - ❌ Web : Non supporté (pas d'app SMS sur navigateur)

4. **Numéro pré-rempli** : Sur certains appareils, il n'est pas possible de pré-remplir le numéro de destinataire via l'URL `sms:`.

### Bonnes pratiques

1. **Garder les messages concis** : Même si le système inclut tous les détails, privilégiez des alertes avec des messages courts et clairs.

2. **Instructions prioritaires** : Les instructions doivent être les plus importantes et faciles à comprendre.

3. **Numéros de contact prédéfinis** : Envisager d'ajouter une liste de contacts d'urgence dans les paramètres de l'app pour faciliter l'envoi.

4. **Confirmation d'envoi** : Le système ne peut pas confirmer si le SMS a été envoyé (c'est géré par l'app SMS native).

## Améliorations futures possibles

### Court terme
- Ajouter un carnet de contacts d'urgence dans l'app
- Option pour sauvegarder des modèles de messages SMS personnalisés
- Historique des SMS envoyés depuis l'app

### Moyen terme
- Sélection multiple de destinataires
- Envoi automatique si permissions accordées (Android uniquement)
- Raccourci rapide "Partager par SMS" dans la liste des alertes

### Long terme
- Intégration avec les contacts du téléphone
- Support de MMS pour inclure des images
- Statistiques d'utilisation des SMS vs synchronisation
- Mode "Urgence" qui propose automatiquement l'envoi SMS pour les alertes critiques

## Permissions nécessaires

Aucune permission spéciale n'est requise car l'app ouvre simplement l'application SMS native au lieu d'envoyer directement des SMS.

## Tests

Pour tester cette fonctionnalité :

1. **Désactiver le réseau mobile data** (garder le réseau téléphonique pour SMS)
2. Créer une alerte
3. Vérifier que le dialogue SMS apparaît
4. Cliquer sur "Ouvrir SMS"
5. Vérifier que l'app SMS s'ouvre avec le message pré-rempli
6. Vérifier que le message contient toutes les informations de l'alerte
7. (Optionnel) Envoyer le SMS à un numéro de test

## Support et dépannage

**Problème** : L'app SMS ne s'ouvre pas
- **Solution** : Vérifier que le téléphone a une app SMS installée (certains appareils n'en ont pas par défaut)

**Problème** : Le message est tronqué
- **Solution** : Le message sera automatiquement divisé en plusieurs SMS par l'app SMS native

**Problème** : Caractères spéciaux mal affichés
- **Solution** : Le système utilise l'encodage UTF-8, mais certains vieux téléphones peuvent avoir des problèmes avec les emojis

## Code source

Fichier principal : `lib/core/utils/sms_helper.dart`

```dart
// Voir le fichier pour l'implémentation complète
```
