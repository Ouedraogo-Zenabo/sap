import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Helper pour envoyer des alertes par SMS
class SmsHelper {
  /// Formate les données d'une alerte en message SMS
  static String formatAlertToSms(Map<String, dynamic> alertData) {
    final StringBuffer message = StringBuffer();
    
    message.writeln('🚨 ALERTE SYSTÈME');
    message.writeln('');
    
    // Type d'alerte
    if (alertData['type'] != null) {
      message.writeln('Type: ${_translateType(alertData['type'])}');
    }
    
    // Sévérité
    if (alertData['severity'] != null) {
      message.writeln('Sévérité: ${_translateSeverity(alertData['severity'])}');
    }
    
    // Titre
    if (alertData['title'] != null && alertData['title'].toString().isNotEmpty) {
      message.writeln('');
      message.writeln('TITRE: ${alertData['title']}');
    }
    
    // Message
    if (alertData['message'] != null && alertData['message'].toString().isNotEmpty) {
      message.writeln('');
      message.writeln('MESSAGE: ${alertData['message']}');
    }
    
    // Zone
    if (alertData['zoneName'] != null) {
      message.writeln('');
      message.writeln('Zone: ${alertData['zoneName']}');
    }
    
    // Date de début
    if (alertData['startDate'] != null) {
      message.writeln('Début: ${_formatDate(alertData['startDate'])}');
    }
    
    // Instructions
    if (alertData['instructions'] != null && alertData['instructions'].toString().isNotEmpty) {
      message.writeln('');
      message.writeln('INSTRUCTIONS: ${alertData['instructions']}');
    }
    
    // Action requise
    if (alertData['actionRequired'] == true) {
      message.writeln('');
      message.writeln('⚠️ ACTION REQUISE');
    }
    
    message.writeln('');
    message.writeln('---');
    message.writeln('Message envoyé via Système d\'Alerte Précoce');
    
    return message.toString();
  }
  
  /// Ouvre l'application SMS native avec le message pré-rempli
  static Future<bool> sendSms({
    String? phoneNumber,
    required String message,
  }) async {
    try {
      // Encoder le message pour l'URL
      final encodedMessage = Uri.encodeComponent(message);
      
      // Construire l'URL SMS
      // Si phoneNumber est fourni, l'utiliser, sinon laisser vide
      final smsUri = phoneNumber != null && phoneNumber.isNotEmpty
          ? Uri.parse('sms:$phoneNumber?body=$encodedMessage')
          : Uri.parse('sms:?body=$encodedMessage');
      
      // Vérifier si on peut lancer l'URL
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      } else {
        debugPrint('Impossible d\'ouvrir l\'application SMS');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture de l\'app SMS: $e');
      return false;
    }
  }
  
  /// Affiche un dialogue pour choisir d'envoyer par SMS
  static Future<bool?> showSmsDialog(
    BuildContext context,
    Map<String, dynamic> alertData,
  ) async {
    final message = formatAlertToSms(alertData);
    
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.sms, color: Colors.blue),
            SizedBox(width: 10),
            Text('Envoyer par SMS'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'L\'alerte a été sauvegardée localement.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Voulez-vous également l\'envoyer par SMS ?',
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aperçu du message:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message.length > 200 
                          ? '${message.substring(0, 200)}...' 
                          : message,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '💡 L\'application SMS s\'ouvrira et vous pourrez:',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const Text(
                '• Choisir le destinataire',
                style: TextStyle(fontSize: 11),
              ),
              const Text(
                '• Modifier le message si nécessaire',
                style: TextStyle(fontSize: 11),
              ),
              const Text(
                '• Envoyer ou annuler',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non, merci'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.sms),
            label: const Text('Ouvrir SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helpers pour traduire les valeurs
  
  static String _translateType(String type) {
    const types = {
      'FLOOD': 'Inondation',
      'DROUGHT': 'Sécheresse',
      'STORM': 'Tempête',
      'EPIDEMIC': 'Épidémie',
      'FIRE': 'Incendie',
      'EARTHQUAKE': 'Séisme',
      'SECURITY': 'Sécurité/Conflit',
      'FAMINE': 'Famine',
      'LOCUST': 'Invasion acridienne',
      'OTHER': 'Autre',
    };
    return types[type] ?? type;
  }
  
  static String _translateSeverity(String severity) {
    const severities = {
      'INFO': 'Information',
      'LOW': 'Faible',
      'MODERATE': 'Modéré',
      'HIGH': 'Élevé',
      'CRITICAL': 'Critique',
      'EXTREME': 'Extrême',
    };
    return severities[severity] ?? severity;
  }
  
  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Non spécifiée';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
