import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'participation_service.dart';
import 'participants_list.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final supabase = Supabase.instance.client;
  List<RealtimeChannel> _channels = [];
  
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
    for (final channel in _channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    try {
      if (!mounted) return;
      if (_events.isEmpty) {
        setState(() => _isLoading = true);
      }
      
      final response = await supabase
          .from('events')
          .select('id, title, date, created_at, created_by, profiles(email), participants(id)')
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

  void _setupRealtimeSubscription() {
    final mainChannel = supabase.channel('main-changes-room');
    
    mainChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'events',
      callback: (payload) => _fetchEvents(),
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'participants',
      callback: (payload) => _fetchEvents(),
    ).subscribe();
    
    _channels = [mainChannel];
  }

  Future<void> _createEvent(String title) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non authentifié');
      }

      await supabase.from('events').insert({
        'title': title.trim(),
        'date': DateTime.now().toIso8601String(),
        'created_by': user.id,
      });
      
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

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Créer un événement',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                style: const TextStyle(fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Titre de l\'événement',
                  hintText: 'Ex: Soirée de lancement...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: Icon(Icons.edit_calendar_rounded, color: Colors.blue.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                ),
                autofocus: true,
                minLines: 3, // Hauteur initiale (style textarea)
                maxLines: 5, // Expansion maximale
                keyboardType: TextInputType.multiline,
                maxLength: 100,
              ),

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _submitEvent(titleController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.blue.shade200,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text(
                      'Créer',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      const months = [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} '
          '${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}'
          ':${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade400],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Événements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            Text(
              supabase.auth.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        elevation: 4,
        shadowColor: Colors.blue.shade900.withOpacity(0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await supabase.auth.signOut();
            },
            tooltip: 'Déconnexion',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(),
            tooltip: 'À propos',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel événement', style: TextStyle(fontWeight: FontWeight.bold)),
        tooltip: 'Créer un événement',
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Image avec fallback
            Positioned.fill(
              child: Image.network(
                'https://i.pinimg.com/736x/8e/fd/14/8efd14d145b7f2db252b21767cebcd8b.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.blue.shade900,
                  child: const Icon(Icons.event_available, color: Colors.white24, size: 64),
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.blue.shade900.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
            // Text Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Découvrir tous les événements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Publiez vos événements en temps réel et participez en direct',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4, // Afficher 4 cartes factices
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 150,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Colors.grey.shade200),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading && _events.isEmpty) {
      return _buildSkeletonList();
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

    // ⭐⭐⭐ LISTE DES ÉVÉNEMENTS MODIFIÉE AVEC TES FONCTIONNALITÉS P4 ⭐⭐⭐
    return RefreshIndicator(
      onRefresh: _fetchEvents,
      color: Colors.blue.shade900,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _events.length + 2,
        physics: const AlwaysScrollableScrollPhysics(), // Important pour le Pull-to-refresh
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader();
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.explore_rounded, size: 20, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  const Text(
                    'Tous les événements',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            );
          }
          final event = _events[index - 2];
          final creatorEmail = event['profiles']?['email'] ?? 'Utilisateur';
          final eventId = event['id'].toString();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParticipantsScreen(
                      eventId: eventId,
                      eventTitle: event['title'],
                      eventDate: event['date'],
                      creatorEmail: creatorEmail,
                    ),
                  ),
                );
                _fetchEvents(); // Rafraîchissement au retour
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. En-tête : Titre
                    Text(
                      event['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  
                  // 2. Infos : Date, Créateur et Nombre de participants
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _formatDate(event['date']),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    creatorEmail,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Badge Nombre de participants
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_alt_rounded, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                            ((event['participants'] as List?)?.length ?? 0).toString(),
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Synchronisation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fonctionnement en temps réel :\n\n'
                '• Les événements se mettent à jour automatiquement.\n'
                '• Les participants apparaissent instantanément.\n'
                '• Aucun bouton d\'actualisation n\'est nécessaire.\n\n'
                'Vous pouvez participer à un événement et voir les autres participants s\'y joindre en direct.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}