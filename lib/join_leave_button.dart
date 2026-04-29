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
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_isParticipating)
          ElevatedButton.icon(
            onPressed: _handleLeave,
            icon: const Icon(Icons.exit_to_app, size: 18),
            label: const Text('Quitter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade800,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _handleJoin,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Rejoindre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.green.shade800,
            ),
          ),
      ],
    );
  }
}