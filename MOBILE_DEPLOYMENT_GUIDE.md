# Guide de Déploiement sur Téléphone Mobile

## ✅ Configuration complétée

Les dépendances suivantes ont été vérifiées et configurées :

### Permissions Android ajoutées
- ✅ `INTERNET` - Pour les appels API
- ✅ `ACCESS_NETWORK_STATE` - Pour connectivity_plus (détection connexion)
- ✅ `CAMERA` - Pour image_picker
- ✅ `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO` - Pour file_picker
- ✅ Queries pour `sms:` - Pour url_launcher (envoi SMS)
- ✅ Queries pour `http:` et `https:` - Pour url_launcher

### État de l'environnement
```
✅ Flutter 3.38.4 (Stable)
✅ Android SDK 36.1.0
✅ Java OpenJDK 17.0.6
✅ Toutes les licences Android acceptées
```

## 📱 Étapes pour exécuter sur téléphone Android

### Option 1 : Téléphone physique (USB)

1. **Activer le mode développeur sur le téléphone**
   - Allez dans `Paramètres` → `À propos du téléphone`
   - Appuyez 7 fois sur `Numéro de build`
   - Message : "Vous êtes maintenant développeur"

2. **Activer le débogage USB**
   - Allez dans `Paramètres` → `Options pour les développeurs`
   - Activez `Débogage USB`
   - Activez `Installation via USB` (si disponible)

3. **Connecter le téléphone en USB**
   - Branchez le câble USB au PC
   - Sur le téléphone, sélectionnez "Transfert de fichiers" ou "MTP"
   - Autorisez le débogage USB (popup sur le téléphone)

4. **Vérifier la détection**
   ```bash
   flutter devices
   ```
   Vous devriez voir votre téléphone dans la liste

5. **Lancer l'application**
   ```bash
   flutter run
   ```
   Ou spécifier l'appareil :
   ```bash
   flutter run -d <device-id>
   ```

### Option 2 : Émulateur Android

1. **Lancer un émulateur**
   ```bash
   flutter emulators
   flutter emulators --launch <emulator-id>
   ```

2. **Ou depuis Android Studio**
   - Ouvrir Android Studio
   - Device Manager → Create Device
   - Choisir un modèle (ex: Pixel 5)
   - Télécharger une image système (API 34 recommandé)
   - Lancer l'émulateur

3. **Lancer l'application**
   ```bash
   flutter run
   ```

### Option 3 : Build APK pour installation manuelle

1. **Build en mode debug**
   ```bash
   flutter build apk --debug
   ```
   APK généré dans : `build/app/outputs/flutter-apk/app-debug.apk`

2. **Build en mode release (production)**
   ```bash
   flutter build apk --release
   ```
   APK généré dans : `build/app/outputs/flutter-apk/app-release.apk`

3. **Installer l'APK sur le téléphone**
   - Via USB :
     ```bash
     adb install build/app/outputs/flutter-apk/app-debug.apk
     ```
   - Ou transférer l'APK et installer manuellement depuis le téléphone

## 🔍 Dépannage

### Téléphone non détecté

1. **Vérifier les drivers USB**
   - Windows : Installer les drivers du fabricant (Samsung, Xiaomi, etc.)
   - Ou utiliser les Google USB Drivers

2. **Vérifier ADB**
   ```bash
   adb devices
   ```
   Si vide, essayer :
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

3. **Changer le mode USB**
   - Sur le téléphone, désactiver/réactiver le débogage USB
   - Essayer différents modes USB (MTP, PTP, etc.)
   - Changer de port USB ou de câble

### Erreurs de compilation

1. **Nettoyer le build**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

2. **Erreur Gradle**
   ```bash
   cd android
   ./gradlew clean
   cd ..
   flutter run
   ```

3. **Erreur de licences Android**
   ```bash
   flutter doctor --android-licenses
   ```

### Problèmes de permissions

Si l'app crash au démarrage :
- Vérifier que toutes les permissions sont dans `AndroidManifest.xml`
- Tester les fonctionnalités nécessitant des permissions une par une
- Vérifier les logs :
  ```bash
  flutter logs
  ```

## 📊 Commandes utiles

```bash
# Lister les appareils connectés
flutter devices

# Lister les émulateurs disponibles
flutter emulators

# Nettoyer le projet
flutter clean

# Installer les dépendances
flutter pub get

# Vérifier l'état de Flutter
flutter doctor -v

# Voir les logs en temps réel
flutter logs

# Build pour différentes plateformes
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (pour Play Store)
flutter build ios          # iOS (nécessite macOS)

# Hot reload pendant le développement
r                          # Dans le terminal flutter run
R                          # Hot restart
q                          # Quitter
```

## 📝 Checklist avant le run

- ✅ Téléphone en mode développeur
- ✅ Débogage USB activé
- ✅ Téléphone connecté et autorisé
- ✅ `flutter devices` montre le téléphone
- ✅ `flutter doctor` sans erreurs critiques
- ✅ `flutter pub get` exécuté
- ✅ Permissions Android ajoutées dans AndroidManifest.xml

## 🎯 Tester les nouvelles fonctionnalités

### Mode Hors-ligne + SMS

1. **Désactiver le WiFi et les données mobiles** sur le téléphone
2. Créer une alerte
3. Vérifier la sauvegarde locale
4. Vérifier que le dialogue SMS apparaît
5. Tester l'ouverture de l'app SMS
6. Réactiver la connexion
7. Tester la synchronisation depuis le Dashboard

### Session persistante

1. Se connecter
2. Fermer complètement l'app
3. Rouvrir → Devrait être déjà connecté
4. Aller dans Profil → Déconnexion
5. Rouvrir → Devrait demander la connexion

### Refresh automatique du token

1. Se connecter
2. Laisser l'app ouverte pendant 50+ minutes
3. Vérifier les logs : "✅ Token refreshed automatiquement"

## 🚀 Prêt à lancer !

Une fois le téléphone connecté, lancez simplement :

```bash
flutter run
```

L'application se compilera et s'installera automatiquement sur votre téléphone.
