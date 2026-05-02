// lib/join_leave_button.dart
import 'package:flutter/material.dart';
import 'participation_service.dart';

class JoinLeaveButton extends StatefulWidget {
  final String eventId;
  
  const JoinLeaveButton({super.key, required this.eventId});

  @override
  State<JoinLeaveButton> createState() => _JoinLeaveButtonState();
}

class _JoinLeaveButtonState extends State<JoinLeaveButton> {
  final ParticipationService _service = ParticipationService();
  bool _isParticipating = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkParticipation();
  }
  
  Future<void> _checkParticipation() async {
    try {
      final participating = await _service.isParticipating(widget.eventId);
      if (mounted) {
        setState(() {
          _isParticipating = participating;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _handleJoin() async {
    setState(() => _isLoading = true);
    try {
      await _service.joinEvent(widget.eventId);
      if (mounted) {
        setState(() => _isParticipating = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Événement rejoint !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleLeave() async {
    setState(() => _isLoading = true);
    try {
      await _service.leaveEvent(widget.eventId);
      if (mounted) {
        setState(() => _isParticipating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👋 Événement quitté'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: _isLoading && _isParticipating == false && _isFirstLoad()
          ? _buildLoading()
          : _isParticipating 
              ? _buildLeaveButton() 
              : _buildJoinButton(),
    );
  }

  bool _isFirstLoad() {
    // Une petite astuce pour savoir si c'est le chargement initial
    return _isLoading && !_isParticipating;
  }

  Widget _buildLoading() {
    return Container(
      key: const ValueKey('loading'),
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
      ),
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton.icon(
      key: const ValueKey('join'),
      onPressed: _isLoading ? null : _handleJoin,
      icon: _isLoading 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.person_add_alt_1_rounded, size: 20),
      label: Text(
        _isLoading ? 'Traitement...' : 'Rejoindre',
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.blue.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildLeaveButton() {
    return OutlinedButton.icon(
      key: const ValueKey('leave'),
      onPressed: _isLoading ? null : _handleLeave,
      icon: _isLoading 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
          : const Icon(Icons.no_accounts_rounded, size: 20),
      label: Text(
        _isLoading ? 'Sortie...' : 'Quitter',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade200, width: 1.5),
        backgroundColor: Colors.red.shade50.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}