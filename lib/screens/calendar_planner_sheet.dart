import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/models/google_calendar_models.dart';
import 'package:utopia_app/services/google_calendar_service.dart';
import 'package:utopia_app/services/calendar_cache_service.dart';
import 'package:utopia_app/services/ai_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class CalendarPlannerSheet extends StatefulWidget {
  const CalendarPlannerSheet({super.key, required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<CalendarPlannerSheet> createState() => _CalendarPlannerSheetState();
}

class ProposedAction {
  final String action; // 'create', 'update', 'delete'
  final String id;
  final String calendarId;
  final String summary;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  bool isSelected;

  ProposedAction({
    required this.action,
    required this.id,
    required this.calendarId,
    required this.summary,
    required this.description,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    this.isSelected = true,
  });

  factory ProposedAction.fromJson(Map<String, dynamic> json, int index) {
    final action = json['action'] as String? ?? 'create';
    // Generate a guaranteed unique ID for creates to avoid duplicate ID issues from LLM templates.
    final id = action == 'create'
        ? 'local_suggested_${DateTime.now().millisecondsSinceEpoch}_$index'
        : (json['id'] as String? ?? 'local_suggested_${DateTime.now().millisecondsSinceEpoch}_$index');

    return ProposedAction(
      action: action,
      id: id,
      calendarId: json['calendarId'] as String? ?? 'primary',
      summary: json['summary'] as String? ?? 'Untitled Suggested Event',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now().add(const Duration(hours: 1)),
      isAllDay: json['isAllDay'] as bool? ?? false,
    );
  }
}

class PlannerMessage {
  final String text;
  final bool isUser;
  final String? explanation;
  final List<ProposedAction> actions;

  PlannerMessage({
    required this.text,
    required this.isUser,
    this.explanation,
    this.actions = const [],
  });
}

class _CalendarPlannerSheetState extends State<CalendarPlannerSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<PlannerMessage> _messages = [];
  final List<Map<String, String>> _apiHistory = [];
  
  List<GoogleCalendarEvent> _existingEvents = [];
  bool _isLoading = false;
  bool _applying = false;

  static const List<String> _suggestions = [
    'Plan exam studies on Mon & Wed next week',
    'Schedule dentist session this Friday at 4 PM',
    'Block 1 hour daily for coding this week',
    'Move tomorrow\'s meetings to next Monday morning',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEvents() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final end = now.add(const Duration(days: 14));
    final events = await CalendarCacheService.instance.getEvents(start: start, end: end);
    if (mounted) {
      setState(() {
        _existingEvents = events;
      });
    }
  }

  GoogleCalendarEvent? _getOverlappingEvent(ProposedAction proposed) {
    for (final existing in _existingEvents) {
      if (existing.startTime == null || existing.endTime == null) continue;
      if (existing.isDeleted) continue;
      if (existing.id == proposed.id) continue;

      // Overlap check
      if (proposed.startTime.isBefore(existing.endTime!) &&
          proposed.endTime.isAfter(existing.startTime!)) {
        return existing;
      }
    }
    return null;
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(PlannerMessage(text: trimmed, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final now = DateTime.now();
      final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      final calendars = await CalendarCacheService.instance.getCalendars();
      final writable = calendars.where((c) => c.accessRole == 'owner' || c.accessRole == 'writer').toList();
      final calendarsContext = writable.map((c) => '- ${c.id} (Name: "${c.summary}")').join('\n');

      final eventsContext = _existingEvents.map((e) {
        final time = e.isAllDay
            ? 'All Day'
            : '${DateFormat('yyyy-MM-dd HH:mm').format(e.startTime!)} to ${DateFormat('yyyy-MM-dd HH:mm').format(e.endTime!)}';
        return '- ${e.summary ?? "Untitled"} ($time) [Calendar ID: ${e.calendarId}] [Event ID: ${e.id}]';
      }).join('\n');

      final systemPrompt = '''
You are Luna, UTOPIA's Intelligent Calendar Planner.
Your role is to help the user manage, plan, and schedule their calendar.
You can propose creating new events, updating existing events, or deleting events.
Improvise and make smart scheduling decisions based on the user's request. For example, if they ask for a 'study session tomorrow afternoon', choose a free afternoon slot (e.g. 2 PM - 4 PM or 3 PM - 5 PM) that does not overlap with their existing events/classes.

You are fully capable of planning multiple events at once (even 10 or more). Ensure you list ALL requested events as separate entries in the "actions" array. Never omit any requested event, and never say you have scheduled them in the "explanation" without actually including them in the "actions" array.

Today's local time is: $todayStr, $timeStr.

Here are the user's writable calendars:
$calendarsContext

Here are the user's existing events from ${DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)))} to ${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 14)))}:
$eventsContext

You must respond in the following JSON format ONLY:
{
  "explanation": "<Friendly response explaining the planning decision or what was done, or answering their question. Use markdown formatting. Keep it friendly and concise.>",
  "actions": [
    {
      "action": "create", // "create", "update", "delete"
      "id": "local_suggested_1", // for 'create' use a unique local ID like 'local_suggested_1', 'local_suggested_2', etc. for 'update' or 'delete', use the exact event ID provided in the existing events list.
      "calendarId": "<calendar ID from the list, or default to 'primary'>",
      "summary": "<summary/title>",
      "description": "<description/details>",
      "location": "<location, optional>",
      "startTime": "YYYY-MM-DDTHH:MM:SS", // ISO 8601 local date-time string
      "endTime": "YYYY-MM-DDTHH:MM:SS", // ISO 8601 local date-time string
      "isAllDay": false
    }
  ]
}

If no changes are needed, or if the user's message is not related to calendar planning (e.g. general questions or chit-chat), return an empty actions array: "actions": [].
Do NOT wrap the JSON in anything except a standard ```json markdown code block. Do NOT put any other text outside the JSON code block.
''';

      final payloadMessages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ..._apiHistory,
        {'role': 'user', 'content': trimmed},
      ];

      final responseText = await AIService.sendCustomMessage(
        messages: payloadMessages,
        maxTokens: 4096,
      );
      final parsed = _parseResponse(responseText);

      setState(() {
        _apiHistory.add({'role': 'user', 'content': trimmed});
        _apiHistory.add({'role': 'assistant', 'content': responseText});
        
        if (parsed != null) {
          final explanation = parsed['explanation'] as String? ?? '';
          final rawActions = parsed['actions'] as List<dynamic>? ?? [];
          final actions = <ProposedAction>[];
          for (int i = 0; i < rawActions.length; i++) {
            if (rawActions[i] is Map<String, dynamic>) {
              actions.add(ProposedAction.fromJson(rawActions[i] as Map<String, dynamic>, i));
            }
          }
          _messages.add(PlannerMessage(
            text: responseText,
            isUser: false,
            explanation: explanation,
            actions: actions,
          ));
        } else {
          _messages.add(PlannerMessage(
            text: responseText,
            isUser: false,
            explanation: responseText,
          ));
        }
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (err) {
      if (mounted) {
        setState(() {
          _messages.add(PlannerMessage(text: err.toString().replaceFirst('Exception: ', ''), isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _sanitizeJson(String jsonStr) {
    final sb = StringBuffer();
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < jsonStr.length; i++) {
      final char = jsonStr[i];
      if (char == '"' && !escaped) {
        inString = !inString;
        sb.write(char);
      } else if (char == '\n' && inString) {
        sb.write('\\n');
      } else if (char == '\r' && inString) {
        sb.write('\\r');
      } else {
        sb.write(char);
      }

      if (char == '\\') {
        escaped = !escaped;
      } else {
        escaped = false;
      }
    }
    return sb.toString();
  }

  Map<String, dynamic>? _parseResponse(String responseText) {
    String jsonString = responseText.trim();
    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false);
    final match = jsonRegex.firstMatch(responseText);
    if (match != null) {
      jsonString = match.group(1)!.trim();
    } else {
      final startIdx = responseText.indexOf('{');
      final endIdx = responseText.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        jsonString = responseText.substring(startIdx, endIdx + 1).trim();
      }
    }

    try {
      final sanitized = _sanitizeJson(jsonString);
      return jsonDecode(sanitized) as Map<String, dynamic>;
    } catch (_) {
      // Try regex explanation extraction
      final expRegex = RegExp(r'"explanation"\s*:\s*"([\s\S]*?)"\s*,\s*"actions"', caseSensitive: false);
      final expMatch = expRegex.firstMatch(jsonString);
      if (expMatch != null) {
        final expText = expMatch.group(1)!;
        final cleanText = expText
            .replaceAll('\\n', '\n')
            .replaceAll('\\r', '\r')
            .replaceAll('\\"', '"')
            .replaceAll('\\\\', '\\');
        return {
          'explanation': cleanText,
          'actions': []
        };
      }
      
      // Fallback: raw response is explanation
      return {
        'explanation': responseText,
        'actions': []
      };
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _applyPlan() async {
    // Collect all selected proposed actions across messages
    final proposedActions = <ProposedAction>[];
    for (final m in _messages) {
      if (!m.isUser) {
        for (final act in m.actions) {
          if (act.isSelected) {
            proposedActions.add(act);
          }
        }
      }
    }

    if (proposedActions.isEmpty) return;

    setState(() => _applying = true);

    String localTimeZone = 'UTC';
    try {
      localTimeZone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      localTimeZone = DateTime.now().timeZoneName;
    }

    int successCount = 0;
    for (final act in proposedActions) {
      try {
        if (act.action == 'create') {
          final event = GoogleCalendarEvent(
            id: 'local_${DateTime.now().millisecondsSinceEpoch}_$successCount',
            calendarId: act.calendarId,
            summary: act.summary,
            description: act.description,
            location: act.location,
            startTime: act.startTime,
            endTime: act.endTime,
            isAllDay: act.isAllDay,
            timezone: localTimeZone,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          final success = await GoogleCalendarService.instance.createEvent(event);
          if (success) successCount++;
        } else if (act.action == 'update') {
          final existing = await CalendarCacheService.instance.getEvent(act.id);
          if (existing != null) {
            final updated = existing.copyWith(
              summary: act.summary,
              description: act.description,
              location: act.location,
              startTime: act.startTime,
              endTime: act.endTime,
              isAllDay: act.isAllDay,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            final success = await GoogleCalendarService.instance.updateEvent(updated);
            if (success) successCount++;
          }
        } else if (act.action == 'delete') {
          final existing = await CalendarCacheService.instance.getEvent(act.id);
          if (existing != null) {
            final success = await GoogleCalendarService.instance.deleteEvent(existing);
            if (success) successCount++;
          }
        }
      } catch (e) {
        debugPrint('Failed to apply planner action: $e');
      }
    }

    setState(() => _applying = false);

    if (mounted) {
      U.showSnackBar(
        context,
        'Successfully applied $successCount scheduled updates to your calendar!',
        icon: Icons.check_circle_outline,
      );
      widget.onRefresh();
      Navigator.pop(context);
    }
  }

  bool _hasProposedActions() {
    for (final m in _messages) {
      if (!m.isUser) {
        for (final act in m.actions) {
          if (act.isSelected) return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasActions = _hasProposedActions();

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: U.bg.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: U.border.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                // ── Header Drag Indicator ──
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: U.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Header Title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: U.surface.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: U.border.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.auto_awesome_rounded, color: U.gold, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Luna Calendar Planner',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: U.text,
                              ),
                            ),
                            Text(
                              'Conversational calendar intelligence',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: U.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: U.dim, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // ── Messages View ──
                Expanded(
                  child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
                ),

                // ── Suggestion Chips (Only if chat is empty & not loading) ──
                if (_messages.isEmpty && !_isLoading) _buildSuggestions(),

                // ── Apply Plan Drawer Actions Bar ──
                if (hasActions) _buildActionsBar(),

                // ── Input Area ──
                _buildInputComposer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: U.border.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.psychology_rounded, color: U.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Improvise Your Schedule',
              style: GoogleFonts.playfairDisplay(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: U.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask Luna to design, block, or shift your calendar slots. She will check your conflicts automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: U.sub,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[i];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: U.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: U.gold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Luna is planning...',
              style: GoogleFonts.plusJakartaSans(
                color: U.sub,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(PlannerMessage msg) {
    if (msg.isUser) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: U.primary.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            border: Border.all(color: U.primary.withValues(alpha: 0.2), width: 0.8),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.plusJakartaSans(
              color: U.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // AI message with un-bordered conversation style & timeline list
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Luna avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: U.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: U.gold.withValues(alpha: 0.3), width: 1),
            ),
            child: Center(
              child: Icon(Icons.auto_awesome_rounded, color: U.gold, size: 13),
            ),
          ),
          const SizedBox(width: 12),

          // Message details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Response text body
                MarkdownBody(
                  data: msg.explanation ?? msg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.plusJakartaSans(
                      color: U.text,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    strong: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    em: GoogleFonts.plusJakartaSans(fontStyle: FontStyle.italic),
                    code: GoogleFonts.plusJakartaSans(
                      backgroundColor: U.surface,
                      color: U.red,
                      fontSize: 11,
                    ),
                    listBullet: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
                  ),
                ),

                // Timelined Proposed Action Tiles
                if (msg.actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'PROPOSED CALENDAR UPDATES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: U.dim,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: msg.actions.length,
                    itemBuilder: (ctx, idx) {
                      final act = msg.actions[idx];
                      return _buildProposedActionTile(act);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposedActionTile(ProposedAction act) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlapEvent = _getOverlappingEvent(act);
    final isDelete = act.action == 'delete';
    final isUpdate = act.action == 'update';

    final dateStr = DateFormat('EEE, MMM d').format(act.startTime);
    final timeStr = act.isAllDay
        ? 'All day'
        : '${DateFormat('h:mm a').format(act.startTime)} – ${DateFormat('h:mm a').format(act.endTime)}';

    final actionColor = isDelete
        ? U.red
        : isUpdate
            ? U.teal
            : U.primary;

    final badgeText = isDelete
        ? 'Delete'
        : isUpdate
            ? 'Move'
            : 'Add';

    return GestureDetector(
      onTap: () {
        setState(() {
          act.isSelected = !act.isSelected;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: act.isSelected
              ? actionColor.withValues(alpha: 0.04)
              : U.card.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: act.isSelected
                ? actionColor.withValues(alpha: 0.4)
                : U.border.withValues(alpha: 0.15),
            width: act.isSelected ? 1.2 : 0.8,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    // Circular check indicator
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: act.isSelected ? actionColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: act.isSelected ? actionColor : U.dim.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: act.isSelected
                          ? Icon(Icons.check, size: 12, color: isDark ? U.bg : Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Event description summary & times
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.summary,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: U.text,
                              decoration: isDelete ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$dateStr  •  $timeStr',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: U.sub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Small indicator badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: actionColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Warning alert banner on conflict
              if (overlapEvent != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: U.gold.withValues(alpha: 0.07),
                    border: Border(
                      top: BorderSide(color: U.gold.withValues(alpha: 0.15), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: U.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Conflicts with "${overlapEvent.summary ?? "Untitled"}"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: U.gold,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final sugg = _suggestions[i];
          return ActionChip(
            label: Text(sugg),
            backgroundColor: U.card,
            side: BorderSide(color: U.border.withValues(alpha: 0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            labelStyle: GoogleFonts.plusJakartaSans(
              color: U.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            onPressed: () => _sendMessage(sugg),
          );
        },
      ),
    );
  }

  Widget _buildActionsBar() {
    int totalCount = 0;
    for (final m in _messages) {
      if (!m.isUser) {
        totalCount += m.actions.where((act) => act.isSelected).length;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: U.surface,
        border: Border(top: BorderSide(color: U.border.withValues(alpha: 0.15), width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalCount scheduled proposed changes ready to apply.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: U.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _applying ? null : _applyPlan,
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              foregroundColor: U.bg,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _applying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Apply Changes',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: BoxDecoration(
        color: U.surface.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: U.border.withValues(alpha: 0.15), width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: U.border.withValues(alpha: 0.3), width: 0.8),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask Luna to schedule or block time...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 13),
                  filled: true,
                  fillColor: Colors.transparent,
                  prefixIcon: Icon(Icons.bolt_rounded, color: U.gold, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: U.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: U.bg,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
