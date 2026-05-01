// lib/participation_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
class ParticipationService {
  final supabase = Supabase.instance.client;
  
  // Récupère l'utilisateur connecté
  String? get currentUserId => supabase.auth.currentUser?.id;
  
  // 🔵 REJOINDRE un événement
  Future<void> joinEvent(String eventId) async {
    final userId = currentUserId; // ← variable locale
    if (userId == null) {
      throw Exception('Vous devez être connecté');
    }
    
    // Vérifie si l'utilisateur participe déjà
    final existing = await supabase
        .from('participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId); // ← userId au lieu de currentUserId
    
    if (existing.isNotEmpty) {
      throw Exception('Vous participez déjà à cet événement');
    }
    
    // Ajoute la participation (avec les bons noms de colonnes)
    await supabase.from('participants').insert({
      'event_id': eventId,
      'user_id': userId, // ← userId au lieu de currentUserId
    });
  }
  
  // 🔴 QUITTER un événement
  Future<void> leaveEvent(String eventId) async {
    final userId = currentUserId; // ← variable locale
    if (userId == null) {
      throw Exception('Vous devez être connecté');
    }
    
    // Supprime la participation
    await supabase
        .from('participants')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId); // ← userId au lieu de currentUserId
  }
  
  // Vérifie si l'utilisateur participe à un événement
  Future<bool> isParticipating(String eventId) async {
    final userId = currentUserId; // ← variable locale
    if (userId == null) return false;
    
    final response = await supabase
        .from('participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId); // ← userId au lieu de currentUserId
    
    return response.isNotEmpty;
  }
  
  // Récupère la liste des participants d'un événement
  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    final response = await supabase
        .from('participants')
        .select('''
          user_id,
          users (
            email
          )
        ''')
        .eq('event_id', eventId);
    
    return List<Map<String, dynamic>>.from(response);
  }
}