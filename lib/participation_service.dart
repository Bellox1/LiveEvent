import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipationService {
  final supabase = Supabase.instance.client;

  String? get currentUserId => supabase.auth.currentUser?.id;

  Future<void> joinEvent(String eventId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Vous devez être connecté');

    final existing = await supabase
        .from('participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId);

    if (existing.isNotEmpty) throw Exception('Vous participez déjà à cet événement');

    await supabase.from('participants').insert({
      'event_id': eventId,
      'user_id': userId,
    });
  }

  Future<void> leaveEvent(String eventId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Vous devez être connecté');

    await supabase
        .from('participants')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<bool> isParticipating(String eventId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final response = await supabase
        .from('participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId);

    return response.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    final response = await supabase
        .from('participants')
        .select('user_id')
        .eq('event_id', eventId);

    return List<Map<String, dynamic>>.from(response);
  }
}