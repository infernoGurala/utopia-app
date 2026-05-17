import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/file_upload_service.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/cloudinary_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int _currentStep = 0;
  bool _isPublishing = false;

  // Step 1 — Basic Info
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _conductedByController = TextEditingController();
  String _selectedCategory = 'Tech';
  File? _bannerFile;
  File? _posterFile;

  // Step 2 — Scheduling
  final _venueController = TextEditingController();
  final _participantLimitController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  DateTime? _registrationDeadline;

  // Step 3 — Details
  final _fullDescController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _prizeInfoController = TextEditingController();
  final _contactController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _participationLinkController = TextEditingController();
  final _tagsController = TextEditingController();
  final _feeAmountController = TextEditingController();

  // Step 4 — Flags
  bool _providesAttendance = false;
  bool _requiresPayment = false;
  bool _providesCertificate = false;
  File? _permissionFile;

  static const _categories = [
    'Tech', 'Sports', 'Workshops', 'Clubs', 'Cultural',
    'Gaming', 'Music', 'Startup', 'Hackathons', 'AI', 'Robotics', 'Competitions',
  ];

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _conductedByController.dispose();
    _venueController.dispose();
    _participantLimitController.dispose();
    _fullDescController.dispose();
    _requirementsController.dispose();
    _prizeInfoController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _participationLinkController.dispose();
    _tagsController.dispose();
    _feeAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isBanner}) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isBanner) {
          _bannerFile = File(picked.path);
        } else {
          _posterFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _pickPermissionLetter() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _permissionFile = File(picked.path));
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? _selectedDate.subtract(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: _selectedDate,
    );
    if (date != null) {
      setState(() => _registrationDeadline = date);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _publishEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an event title', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_contactController.text.trim().isEmpty || _conductedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact numbers and conducted by are required', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_bannerFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Banner image is required', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_permissionFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission letter is required', style: GoogleFonts.outfit())),
      );
      return;
    }
    if (_requiresPayment && _feeAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the fee amount', style: GoogleFonts.outfit())),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      // Get university ID first, required for FileUploadService path scoping
      String? universityId;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        universityId = userDoc.data()?['selectedUniversityId'] as String?;
      } catch (_) {}

      // Upload images
      String? bannerUrl;
      String? posterUrl;
      String? permissionUrl;
      final fileUploadService = FileUploadService();

      if (_bannerFile != null) {
        try {
          bannerUrl = await fileUploadService.uploadFile(
            file: _bannerFile!,
            originalFilename: _bannerFile!.path.split('/').last,
            universityId: universityId ?? 'global',
          );
        } catch (e) {
          throw Exception('Failed to upload banner image: $e');
        }
      }
      if (_posterFile != null) {
        try {
          posterUrl = await fileUploadService.uploadFile(
            file: _posterFile!,
            originalFilename: _posterFile!.path.split('/').last,
            universityId: universityId ?? 'global',
          );
        } catch (e) {
          throw Exception('Failed to upload poster image: $e');
        }
      }
      if (_permissionFile != null) {
        try {
          permissionUrl = await fileUploadService.uploadFile(
            file: _permissionFile!,
            originalFilename: _permissionFile!.path.split('/').last,
            universityId: universityId ?? 'global',
          );
        } catch (e) {
          throw Exception('Failed to upload permission letter: $e');
        }
      }

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final event = EventModel(
        title: _titleController.text.trim(),
        shortDescription: _shortDescController.text.trim(),
        fullDescription: _fullDescController.text.trim(),
        category: _selectedCategory,
        tags: tags,
        bannerUrl: bannerUrl,
        posterUrl: posterUrl,
        date: _selectedDate,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        venue: _venueController.text.trim(),
        participantLimit: int.tryParse(_participantLimitController.text) ?? 0,
        registrationDeadline: _registrationDeadline,
        organizerUid: user.uid,
        organizerName: user.displayName ?? 'Organizer',
        conductedBy: _conductedByController.text.trim(),
        contactNumbers: _contactController.text.trim(),
        whatsappLink: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
        participationLink: _participationLinkController.text.trim().isEmpty ? null : _participationLinkController.text.trim(),
        providesAttendance: _providesAttendance,
        requiresPayment: _requiresPayment,
        feeAmount: _requiresPayment ? _feeAmountController.text.trim() : null,
        providesCertificate: _providesCertificate,
        permissionLetterUrl: permissionUrl,
        status: EventStatus.upcoming,
        isApproved: true, // Auto-approved
        universityId: universityId,
        prizeInfo: _prizeInfoController.text.trim().isEmpty ? null : _prizeInfoController.text.trim(),
        requirements: _requirementsController.text.trim().isEmpty ? null : _requirementsController.text.trim(),
      );

      final eventId = await EventService.instance.createEvent(event);

      if (mounted) {
        if (eventId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event submitted for approval!', style: GoogleFonts.outfit()),
              backgroundColor: U.teal,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create event. Please try again.', style: GoogleFonts.outfit()),
              backgroundColor: U.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit()),
            backgroundColor: U.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep < 4) {
      setState(() => _currentStep += 1);
    } else {
      _publishEvent();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Upload Event',
          style: GoogleFonts.outfit(color: U.text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isPublishing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: U.primary),
                  const SizedBox(height: 16),
                  Text('Publishing event...', style: GoogleFonts.outfit(color: U.sub, fontSize: 16)),
                ],
              ),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: U.primary,
                  secondary: U.teal,
                ),
              ),
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: _onStepContinue,
                onStepCancel: _onStepCancel,
                onStepTapped: (index) => setState(() => _currentStep = index),
                elevation: 0,
                type: StepperType.vertical,
                controlsBuilder: (context, details) {
                  final isLastStep = _currentStep == 4;
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            child: Text(isLastStep ? 'Publish Event' : 'Continue'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Back'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: Text('Basic Info', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
                    subtitle: Text('Banner, title, category', style: GoogleFonts.outfit(color: U.sub)),
                    content: _buildStep1(),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text('Scheduling', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
                    subtitle: Text('Date, time, venue', style: GoogleFonts.outfit(color: U.sub)),
                    content: _buildStep2(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text('Details', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
                    subtitle: Text('Description, contact', style: GoogleFonts.outfit(color: U.sub)),
                    content: _buildStep3(),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text('Options', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
                    subtitle: Text('Attendance, payment, certificate', style: GoogleFonts.outfit(color: U.sub)),
                    content: _buildStep4(),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text('Preview', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
                    content: _buildStep5Preview(),
                    isActive: _currentStep >= 4,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, IconData? icon, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: U.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: U.sub),
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: U.dim) : null,
        ),
      ),
    );
  }

  Widget _buildImagePicker(String label, File? file, VoidCallback onTap, VoidCallback onClear, IconData icon) {
    return GestureDetector(
      onTap: file == null ? onTap : null,
      child: Container(
        height: file != null ? 160 : 100,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border, style: BorderStyle.solid),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: U.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(label, style: GoogleFonts.outfit(color: U.text)),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8, left: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(file.path.split('/').last, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                ]
              ),
      ),
    );
  }

  // ── Step 1: Basic Info ──
  Widget _buildStep1() {
    return Column(
      children: [
        _buildImagePicker('Upload Banner Image', _bannerFile, () => _pickImage(isBanner: true), () => setState(() => _bannerFile = null), Icons.add_photo_alternate_outlined),
        _buildImagePicker('Upload Poster', _posterFile, () => _pickImage(isBanner: false), () => setState(() => _posterFile = null), Icons.image_outlined),
        _buildField('Event Title', _titleController, icon: Icons.title_rounded),
        _buildField('Short Description', _shortDescController, maxLines: 2, hint: 'Brief one-liner about your event'),
        // Category Dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: GoogleFonts.outfit(color: U.sub),
              prefixIcon: Icon(Icons.category_rounded, color: U.dim),
            ),
            style: GoogleFonts.outfit(color: U.text),
            dropdownColor: U.surface,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'Tech'),
          ),
        ),
        _buildField('Conducted By (Organizer)', _conductedByController, icon: Icons.group_rounded),
      ],
    ).animate().fadeIn();
  }

  // ── Step 2: Scheduling ──
  Widget _buildStep2() {
    return Column(
      children: [
        // Date
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: U.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_today_rounded, color: U.primary),
          ),
          title: Text('Event Date', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          subtitle: Text(_formatDate(_selectedDate), style: GoogleFonts.outfit(color: U.sub)),
          trailing: Icon(Icons.chevron_right_rounded, color: U.dim),
          onTap: _selectDate,
        ),
        const SizedBox(height: 12),
        // Start Time
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.access_time_rounded, color: U.teal),
                title: Text('Start', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                subtitle: Text(_formatTimeOfDay(_startTime), style: GoogleFonts.outfit(color: U.sub)),
                onTap: () => _selectTime(isStart: true),
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.access_time_filled_rounded, color: U.peach),
                title: Text('End', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                subtitle: Text(_formatTimeOfDay(_endTime), style: GoogleFonts.outfit(color: U.sub)),
                onTap: () => _selectTime(isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildField('Venue', _venueController, icon: Icons.location_on_rounded),
        _buildField('Participant Limit (0 = unlimited)', _participantLimitController, icon: Icons.people_rounded),
        // Registration Deadline
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.event_busy_rounded, color: U.red),
          title: Text('Registration Deadline', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          subtitle: Text(
            _registrationDeadline != null ? _formatDate(_registrationDeadline!) : 'Not set (open until event)',
            style: GoogleFonts.outfit(color: U.sub),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: U.dim),
          onTap: _selectDeadline,
        ),
      ],
    ).animate().fadeIn();
  }

  // ── Step 3: Details ──
  Widget _buildStep3() {
    return Column(
      children: [
        _buildField('Full Description', _fullDescController, maxLines: 5, hint: 'Detailed info about your event...'),
        _buildField('Requirements', _requirementsController, maxLines: 2, icon: Icons.checklist_rounded, hint: 'e.g. Laptop, Student ID'),
        _buildField('Prize Information', _prizeInfoController, maxLines: 2, icon: Icons.emoji_events_rounded, hint: 'e.g. ₹10,000 prize pool'),
        _buildField('Contact Numbers', _contactController, icon: Icons.phone_rounded),
        _buildField('WhatsApp Group Link', _whatsappController, icon: Icons.link_rounded),
        _buildField('Participation Link', _participationLinkController, icon: Icons.open_in_new_rounded, hint: 'External registration link'),
        _buildField('Tags (comma separated)', _tagsController, icon: Icons.tag_rounded, hint: 'e.g. coding, web, flutter'),
      ],
    ).animate().fadeIn();
  }

  // ── Step 4: Options ──
  Widget _buildStep4() {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Provides Attendance', style: GoogleFonts.outfit(color: U.text)),
          subtitle: Text('Attendees can log attendance', style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
          value: _providesAttendance,
          activeThumbColor: U.primary,
          activeTrackColor: U.primary.withValues(alpha: 0.3),
          onChanged: (v) => setState(() => _providesAttendance = v),
        ),
        SwitchListTile(
          title: Text('Requires Payment', style: GoogleFonts.outfit(color: U.text)),
          subtitle: Text('Entry fee for the event', style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
          value: _requiresPayment,
          activeThumbColor: U.primary,
          activeTrackColor: U.primary.withValues(alpha: 0.3),
          onChanged: (v) => setState(() => _requiresPayment = v),
        ),
        if (_requiresPayment) ...[
          const SizedBox(height: 16),
          _buildField('Registration Fee Amount', _feeAmountController, icon: Icons.currency_rupee_rounded, hint: 'e.g. 150 INR'),
        ],
        SwitchListTile(
          title: Text('Provides Certificate', style: GoogleFonts.outfit(color: U.text)),
          subtitle: Text('Certificate for participants', style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
          value: _providesCertificate,
          activeThumbColor: U.primary,
          activeTrackColor: U.primary.withValues(alpha: 0.3),
          onChanged: (v) => setState(() => _providesCertificate = v),
        ),
        const SizedBox(height: 16),
        _buildImagePicker(
          'Upload Permission Letter',
          _permissionFile,
          _pickPermissionLetter,
          () => setState(() => _permissionFile = null),
          Icons.upload_file_rounded,
        ),
      ],
    ).animate().fadeIn();
  }

  // ── Step 5: Preview ──
  Widget _buildStep5Preview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_bannerFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_bannerFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          if (_bannerFile != null) const SizedBox(height: 16),
          Text(
            _titleController.text.isEmpty ? 'Untitled Event' : _titleController.text,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: U.text),
          ),
          if (_shortDescController.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_shortDescController.text, style: GoogleFonts.outfit(color: U.sub, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          _previewRow(Icons.category_rounded, _selectedCategory),
          _previewRow(Icons.calendar_today_rounded, _formatDate(_selectedDate)),
          _previewRow(Icons.access_time_rounded, '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}'),
          if (_venueController.text.isNotEmpty) _previewRow(Icons.location_on_rounded, _venueController.text),
          if (_conductedByController.text.isNotEmpty) _previewRow(Icons.group_rounded, _conductedByController.text),
          if (_contactController.text.isNotEmpty) _previewRow(Icons.phone_rounded, _contactController.text),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_providesAttendance) _buildChip('Attendance', U.teal),
              if (_requiresPayment) _buildChip('Paid: ${_feeAmountController.text}', U.peach),
              if (_providesCertificate) _buildChip('Certificate', U.primary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _previewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: U.dim),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.outfit(color: U.text, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
