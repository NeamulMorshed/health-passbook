import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../../models/appointment_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messaging_provider.dart';

class AppointmentMessagesScreen extends ConsumerStatefulWidget {
  final Appointment appointment;
  const AppointmentMessagesScreen({super.key, required this.appointment});

  @override
  ConsumerState<AppointmentMessagesScreen> createState() =>
      _AppointmentMessagesScreenState();
}

class _AppointmentMessagesScreenState
    extends ConsumerState<AppointmentMessagesScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(AppUser user) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final role = user.userType == UserType.doctor
        ? SenderRole.doctor
        : SenderRole.patient;
    try {
      await sendAppointmentMessage(
        appointmentId: widget.appointment.id,
        text: text,
        senderId: user.uid,
        senderRole: role,
        senderName: user.name,
        patientId: widget.appointment.patientId,
        doctorId: widget.appointment.doctorId,
      );
      _ctrl.clear();
      // Scroll to bottom after the stream delivers the new message.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to send message. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _maybeMarkRead(AppUser user) {
    if (_markedRead) return;
    _markedRead = true;
    markAppointmentMessagesRead(
      appointmentId: widget.appointment.id,
      currentUserId: user.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final messagesAsync =
        ref.watch(appointmentMessagesProvider(widget.appointment.id));

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull to refresh or try again.'),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final isDoctor = user.userType == UserType.doctor;
        final otherName = isDoctor
            ? widget.appointment.patientName
            : widget.appointment.doctorName;
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  widget.appointment.scheduledAt != null
                      ? 'Appointment · ${DateFormat('MMM d, h:mm a').format(widget.appointment.scheduledAt!)}'
                      : 'Appointment',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load messages',
                      subtitle: 'Pull to refresh or try again.'),
                  data: (messages) {
                    _maybeMarkRead(user);
                    if (messages.isEmpty) {
                      return EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        subtitle: isDoctor
                            ? 'Send a message to ${widget.appointment.patientName}.'
                            : 'Have a quick question for ${widget.appointment.doctorName}? Send a message.',
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        final mine = msg.senderId == user.uid;
                        final showDateHeader = i == 0 ||
                            !_sameDay(messages[i - 1].createdAt, msg.createdAt);
                        return Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    _dateLabel(msg.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            _MessageBubble(msg: msg, mine: mine),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _ctrl,
                sending: _sending,
                onSend: () => _send(user),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOf = DateTime(local.year, local.month, local.day);
    final diff = today.difference(dayOf).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(local);
    return DateFormat('MMM d, yyyy').format(local);
  }
}

class _MessageBubble extends StatelessWidget {
  final AppointmentMessage msg;
  final bool mine;
  const _MessageBubble({required this.msg, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColors.primary : AppColors.surface;
    final fg = mine ? Colors.white : AppColors.foreground;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.text,
                  style: TextStyle(fontSize: 14, color: fg, height: 1.35)),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(msg.createdAt.toLocal()),
                    style: TextStyle(
                      fontSize: 10,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.mutedForeground,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.readAt != null
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 12,
                      color: msg.readAt != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.primary)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, v, __) {
                final enabled = !sending && v.text.trim().isNotEmpty;
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.primary : AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: enabled ? onSend : null,
                    padding: EdgeInsets.zero,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : HugeIcon(
                            icon: HugeIcons.strokeRoundedSent,
                            color: enabled
                                ? Colors.white
                                : AppColors.mutedForeground,
                            size: 18),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
