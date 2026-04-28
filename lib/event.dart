import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final supabase = Supabase.instance.client;
  late final RealtimeChannel _channel;
  
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    // Nettoyer l'abonnement pour éviter les fuites mémoire
    _channel.unsubscribe();
    super.dispose();
  }

  /// 🔹 Récupère la liste des événements depuis Supabase
  Future<void> _fetchEvents() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final response = await supabase
          .from('events')
          .select('''
            id,
            title,
            date,
            created_at,
            created_by,
            users ( email )
          ''')
          .order('date', ascending: false);

      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de chargement: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// 🔹 Abonnement temps réel aux changements sur la table `events`
  void _setupRealtimeSubscription() {
    _channel = supabase.channel('public:events');
    
    _channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'events',
        callback: (payload) {
          // Mise à jour automatique de la liste à chaque changement
          // Aucun bouton "rafraîchir" nécessaire ✨
          _fetchEvents();
        },
      )
      .subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('Erreur subscription realtime: $error');
        }
      });
  }

  /// 🔹 Crée un nouvel événement (date automatique = maintenant)
  Future<void> _createEvent(String title) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non authentifié');
      }

      await supabase.from('events').insert({
        'title': title.trim(),
        'date': DateTime.now().toIso8601String(), // 🎯 Date auto-générée
        'created_by': user.id,
      });
      
      // La mise à jour temps réel gère le refresh ✅
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 🔹 Affiche le dialog de création d'événement
  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✨ Nouveau événement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titre de l\'événement',
                hintText: 'Ex: Réunion d\'équipe, Anniversaire...',
                prefixIcon: Icon(Icons.title),
              ),
              autofocus: true,
              maxLength: 100,
              onSubmitted: (_) => _submitEvent(titleController.text),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Date: automatique (maintenant)',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => _submitEvent(titleController.text),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _submitEvent(String title) {
    if (title.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le titre doit contenir au moins 3 caractères'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    _createEvent(title);
  }

  /// 🔹 Formattage lisible de la date
  String _formatDate(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} '
        '${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}'
        ':${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Événements'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'À propos',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel événement'),
        tooltip: 'Créer un événement',
      ),
    );
  }

  /// 🔹 Widget principal du body avec gestion des états
  Widget _buildBody() {
    if (_isLoading && _events.isEmpty) {
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

    if (_error != null && _events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text(
                'Aucun événement pour le moment 👋',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateEventDialog,
                icon: const Icon(Icons.add),
                label: const Text('Créer le premier événement'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Liste des événements avec mise à jour temps réel
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final creatorEmail = event['users']?['email'] ?? 'Utilisateur';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shadowColor: Colors.blue.shade100,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              event['title'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, 
                          size: 14, 
                          color: Colors.blue.shade700
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(event['date']),
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, 
                        size: 14, 
                        color: Colors.grey.shade600
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Créé par: $creatorEmail',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  /// 🔹 Dialog d'information rapide
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ℹ️ Synchronisation'),
        content: const Text(
          'Les événements se mettent à jour automatiquement en temps réel. '
          'Aucun bouton "rafraîchir" nécessaire ! ✨\n\n'
          '• Création: titre uniquement\n'
          '• Date: définie automatiquement\n'
          '• Mise à jour: instantanée sur tous les appareils',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}