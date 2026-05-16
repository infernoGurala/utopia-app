import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int _currentStep = 0;

  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Tech');
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _conductedByController = TextEditingController();
  
  bool _providesAttendance = false;
  bool _requiresPayment = false;
  bool _providesCertificate = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _conductedByController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    } else {
      // Publish event
      Navigator.pop(context);
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
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: U.primary,
            onSurface: U.text,
          ).copyWith(
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
            final isLastStep = _currentStep == 3;
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
              subtitle: Text('Poster, title, category', style: GoogleFonts.outfit(color: U.sub)),
              content: _buildBasicInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('Scheduling', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
              subtitle: Text('Date, time, venue', style: GoogleFonts.outfit(color: U.sub)),
              content: _buildSchedulingStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('Details', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
              subtitle: Text('Description, flags', style: GoogleFonts.outfit(color: U.sub)),
              content: _buildDetailsStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('Preview', style: GoogleFonts.outfit(fontSize: 18, color: U.text)),
              content: _buildPreviewStep(),
              isActive: _currentStep >= 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: U.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: U.sub),
          prefixIcon: icon != null ? Icon(icon, color: U.dim) : null,
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: U.border, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: U.primary, size: 32),
              const SizedBox(height: 8),
              Text('Upload Banner Image', style: GoogleFonts.outfit(color: U.text)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField('Event Title', _titleController),
        _buildTextField('Category (e.g. Tech, Sports)', _categoryController),
        _buildTextField('Conducted By (Organizer)', _conductedByController, icon: Icons.group_rounded),
        const SizedBox(height: 8),
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: U.border, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, color: U.teal),
              const SizedBox(width: 8),
              Text('Upload Permission Letter', style: GoogleFonts.outfit(color: U.text)),
            ],
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildSchedulingStep() {
    return Column(
      children: [
        _buildTextField('Date (e.g. May 20, 2026)', _dateController, icon: Icons.calendar_today_rounded),
        _buildTextField('Time (e.g. 10:00 AM)', _timeController, icon: Icons.access_time_rounded),
        _buildTextField('Venue', _venueController, icon: Icons.location_on_rounded),
      ],
    ).animate().fadeIn();
  }

  Widget _buildDetailsStep() {
    return Column(
      children: [
        _buildTextField('Description', _descriptionController, maxLines: 4),
        _buildTextField('Contact Numbers', _contactController, icon: Icons.phone_rounded),
        _buildTextField('WhatsApp Group Link', _whatsappController, icon: Icons.link_rounded),
        SwitchListTile(
          title: Text('Provides Attendance', style: GoogleFonts.outfit(color: U.text)),
          value: _providesAttendance,
          activeColor: U.primary,
          onChanged: (v) => setState(() => _providesAttendance = v),
        ),
        SwitchListTile(
          title: Text('Requires Payment Fee', style: GoogleFonts.outfit(color: U.text)),
          value: _requiresPayment,
          activeColor: U.primary,
          onChanged: (v) => setState(() => _requiresPayment = v),
        ),
        SwitchListTile(
          title: Text('Credits / Certificate', style: GoogleFonts.outfit(color: U.text)),
          value: _providesCertificate,
          activeColor: U.primary,
          onChanged: (v) => setState(() => _providesCertificate = v),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildPreviewStep() {
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
          Text(
            _titleController.text.isEmpty ? 'Untitled Event' : _titleController.text,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: U.text),
          ),
          const SizedBox(height: 8),
          Text(
            '${_dateController.text} at ${_timeController.text}',
            style: GoogleFonts.outfit(color: U.sub),
          ),
          Text(
            _venueController.text,
            style: GoogleFonts.outfit(color: U.sub),
          ),
          const SizedBox(height: 16),
          Text(
            'Event looks good! Ready to publish?',
            style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
