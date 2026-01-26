# Mode Hors-Ligne pour les Alertes

## Fonctionnalités

Ce système permet de créer des alertes même sans connexion internet et de les synchroniser automatiquement lorsque la connexion revient.

## Comment ça fonctionne

### 1. Création d'alerte sans connexion

Lorsque vous créez une alerte :
- L'application détecte automatiquement si vous avez une connexion internet
- **Avec connexion** : L'alerte est envoyée directement à l'API
- **Sans connexion** : L'alerte est sauvegardée localement sur le téléphone avec un message "📴 Pas de connexion. Alerte sauvegardée localement."

### 2. Visualisation des alertes en attente

Sur la page **Dashboard** :
- Un badge orange avec un chiffre apparaît dans l'AppBar s'il y a des alertes en attente
- Cliquez sur l'icône ☁️ (cloud_upload) pour accéder à la page de synchronisation

### 3. Synchronisation des alertes

Page **Synchronisation** :
- Affiche la liste de toutes les alertes créées hors-ligne
- Pour chaque alerte : titre, description, date de création
- Bouton **"Synchroniser tout"** pour envoyer toutes les alertes à l'API
- Progression en temps réel de la synchronisation
- Les alertes synchronisées avec succès sont automatiquement supprimées de la liste locale

### 4. Statuts de synchronisation

Pour chaque alerte :
- ☁️ Gris : En attente de synchronisation
- ⏳ Bleu : Synchronisation en cours...
- ✅ Vert : Synchronisé avec succès
- ❌ Rouge : Échec de la synchronisation

## Architecture

### Fichiers créés

1. **`alert_local_service.dart`**
   - Service de stockage local avec SharedPreferences
   - Méthodes : `addPendingAlert()`, `getPendingAlerts()`, `removePendingAlert()`, `getPendingAlertsCount()`

2. **`connectivity_service.dart`**
   - Détection de la connexion internet avec le package `connectivity_plus`
   - Méthode : `hasConnection()`, `onConnectivityChanged`

3. **`sync_alerts_page.dart`**
   - Page UI pour synchroniser les alertes
   - Affichage de la liste des alertes en attente
   - Gestion de la synchronisation avec l'API

### Fichiers modifiés

1. **`create_alert.dart`**
   - Ajout de la détection de connexion avant création
   - Sauvegarde locale si pas de connexion
   - Message de confirmation adapté

2. **`dashboard_page.dart`**
   - Badge avec compteur d'alertes en attente
   - Bouton d'accès à la page de synchronisation
   - Rafraîchissement du compteur

3. **`pubspec.yaml`**
   - Ajout du package `connectivity_plus: ^6.1.2`

## Utilisation

### Pour l'utilisateur

1. **Créer une alerte hors-ligne** :
   - Remplissez le formulaire normalement
   - Cliquez sur "Envoyer"
   - Si pas de connexion, un message orange apparaît : "📴 Pas de connexion. Alerte sauvegardée localement."

2. **Synchroniser** :
   - Allez sur la page Dashboard
   - Vous verrez un badge orange avec le nombre d'alertes en attente
   - Cliquez sur l'icône ☁️
   - Cliquez sur "Synchroniser tout"
   - Attendez que toutes les alertes soient envoyées

### Pour le développeur

```dart
// Vérifier la connexion
final connectivityService = ConnectivityService();
final hasConnection = await connectivityService.hasConnection();

// Sauvegarder une alerte localement
final localService = AlertLocalService();
await localService.addPendingAlert(alertData);

// Récupérer les alertes en attente
final pendingAlerts = await localService.getPendingAlerts();

// Supprimer après synchronisation
await localService.removePendingAlert(localId);
```

## Améliorations futures possibles

- Synchronisation automatique en arrière-plan quand la connexion revient
- Support de la synchronisation des médias (images, vidéos, audio)
- File de priorité pour les alertes critiques
- Retry automatique en cas d'échec de synchronisation
- Base de données SQLite pour stocker plus d'informations
