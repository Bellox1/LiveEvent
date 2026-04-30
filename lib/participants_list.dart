// lib/participants_list.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .select('user_id')
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(
          width: 20, 
          height: 20, 
          child: CircularProgressIndicator(strokeWidth: 2)
        )),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _participants.map((p) {
              final userId = p['user_id'];
              final userData = p['users'] as Map<String, dynamic>?;
              final email = userData?['email'] ?? 'Utilisateur';
              final isMe = userId == _currentUserId;
              
              return Chip(
                label: Text(
                  isMe ? 'Moi (${email.split('@').first})' : email.split('@').first,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: isMe ? Colors.blue : Colors.blue.shade100,
                  child: Text(
                    email.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : Colors.blue.shade800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}