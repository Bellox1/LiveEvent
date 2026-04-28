import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _eventsStream;

  @override
  void initState() {
    super.initState();
    // 🔁 Stream temps réel : mise à jour automatique sans refresh
    _eventsStream = _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .order('date', ascending: true);
  }

  /// Crée un nouvel événement dans la table `events`
  Future<void> _createEvent(String title, DateTime date) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté')),
        );
      }
      return;
    }

    try {
      await _supabase.from('events').insert({
        'title': title,
        'date': date.toIso8601String(),
        'created_by': user.id,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  /// Affiche le dialog de création d'événement
  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('✨ Créer un événement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Champ titre
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de l\'événement',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Sélecteur de date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? '📅 Aucune date sélectionnée'
                          : '📅 ${_formatDate(selectedDate!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).colorScheme.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        // Ajout d'une heure par défaut (18h00)
                        final withTime = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          18,
                          0,
                        );
                        setState(() => selectedDate = withTime);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Date'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Veuillez remplir tous les champs'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                await _createEvent(title, selectedDate!);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Formate la date pour l'affichage (FR)
  String _formatDate(DateTime date) {
    const months = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${date.day} ${months[date.month]} ${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Événements'),
        centerTitle: false,
        actions: [
          // Bouton rapide pour créer (alternative au FAB)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCreateEventDialog,
            tooltip: 'Créer un événement',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          // 🔄 État de chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des événements...'),
                ],
              ),
            );
          }

          // ❌ Gestion des erreurs
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Erreur de synchronisation',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // 📭 Liste vide
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun événement pour le moment',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez le premier ! 🎉',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // ✅ Liste des événements
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final date = DateTime.parse(event['date']);
              final isPast = date.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isPast
                      ? BorderSide(color: Colors.grey[300]!)
                      : BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPast
                          ? Colors.grey[100]
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPast ? Icons.event_note : Icons.event_available,
                      color: isPast
                          ? Colors.grey[600]
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    event['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isPast ? Colors.grey[500] : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(date),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (isPast) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Terminé',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                  onTap: () {
                    // 🎯 Future feature : détails de l'événement
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Détails de "${event['title']}" à venir...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel événement'),
        tooltip: 'Créer un événement',
      ),
    );
  }

  @override
  void dispose() {
    // Nettoyage des contrôleurs
    // (le stream est géré automatiquement par Supabase/Flutter)
    super.dispose();
  }
}