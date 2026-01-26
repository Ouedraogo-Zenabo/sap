/*import 'package:flutter/material.dart';
import '../models/alert_detail.dart';

class CommentsTab extends StatefulWidget {
  final List<CommentItem> comments;

  const CommentsTab({super.key, required this.comments});

  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  final TextEditingController _controller = TextEditingController();

  late List<CommentItem> _comments;

  @override
  void initState() {
    super.initState();
    // Copie locale des commentaires pour pouvoir en ajouter
    _comments = List.from(widget.comments);
  }

  /// Publier un nouveau commentaire
  void _publishComment() {
    if (_controller.text.trim().isEmpty) return;

    final newComment = CommentItem(
      author: "Utilisateur courant",
      role: "Agent",
      message: _controller.text.trim(),
      date: DateTime.now().toString().substring(0, 16),
    );

    setState(() {
      _comments.insert(0, newComment); // Ajout en haut
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🔹 Liste des commentaires
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Avatar (initiales)
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          comment.author.substring(0, 2).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),

                      /// Contenu
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${comment.author} - ${comment.role}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(comment.message),
                            const SizedBox(height: 8),
                            Text(
                              comment.date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        /// 🔹 Zone d’ajout de commentaire
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
              )
            ],
          ),
          child: Row(
            children: [
              /// Champ texte
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Ajouter un commentaire...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              /// Bouton publier
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: _publishComment,
              ),
            ],
          ),
        ),
      ],
    );
  }
}*/
