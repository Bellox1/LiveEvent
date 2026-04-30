// lib/participants_list.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'join_leave_button.dart';

class ParticipantsList extends StatefulWidget {
  final String eventId;
  
  const ParticipantsList({super.key, required this.eventId});

  @override
  State<ParticipantsList> createState() => _ParticipantsListState();
}

class _ParticipantsListState extends State<ParticipantsList> {
  final supabase = Supabase.instance.client;
  late final RealtimeChannel _channel;
  List<Map<String, dynamic>> _participants = [];
  String? _currentUserId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _fetchParticipants();
    _setupRealtimeSubscription();
  }
  
  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }
  
  Future<void> _fetchParticipants() async {
    try {
      final response = await supabase
          .from('participants')
          .select('user_id, profiles(email)')
          .eq('event_id', widget.eventId);
      
      if (mounted) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement participants: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _setupRealtimeSubscription() {
    _channel = supabase.channel('public:participants');
    
    _channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'participants',
      callback: (payload) {
        // Rafraîchit la liste quand un participant rejoint/quitte
        _fetchParticipants();
      },
    ).subscribe();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _participants.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.people, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Participants (${_participants.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_participants.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucun participant pour le moment',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          )
        else
          Column(
            children: _participants.map((p) {
              final userId = p['user_id'];
              final userData = p['profiles'] as Map<String, dynamic>?;
              final email = userData?['email'] ?? 'Utilisateur';
              final isMe = userId == _currentUserId;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isMe ? Colors.blue.shade600 : Colors.grey.shade400,
                      child: Text(
                        email.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMe ? supabase.auth.currentUser?.email ?? 'Moi' : email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                          color: isMe ? Colors.blue.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Moi',
                          style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class ParticipantsScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final String eventDate;
  final String creatorEmail;

  const ParticipantsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.eventDate,
    required this.creatorEmail,
  });

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
    } catch (_) {
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
        title: Row(
          children: const [
            Icon(Icons.people_alt_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Liste des participants',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shadowColor: Colors.blue.shade900.withOpacity(0.5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    eventTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(child: JoinLeaveButton(eventId: eventId)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  _formatDate(eventDate),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    creatorEmail,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ParticipantsList(eventId: eventId),
          ],
        ),
      ),
    );
  }
}