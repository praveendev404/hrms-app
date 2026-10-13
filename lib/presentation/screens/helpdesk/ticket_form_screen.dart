import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ticket_model.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/dropdown_options_provider.dart';

/// Add/Edit ticket form screen
class TicketFormScreen extends ConsumerStatefulWidget {
  final TicketModel? ticket;

  const TicketFormScreen({super.key, this.ticket});

  @override
  ConsumerState<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends ConsumerState<TicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedPriorityId;
  int? _selectedLabelId;
  int? _selectedStatusId;

  bool get isEditMode => widget.ticket != null;

  @override
  void initState() {
    super.initState();
    // Fetch dropdown options
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dropdownOptionsProvider.notifier).fetchAllOptions();
    });
    
    if (isEditMode) {
      _subjectController.text = widget.ticket!.subject ?? '';
      _bodyController.text = widget.ticket!.body ?? '';
      _selectedCategoryId = widget.ticket!.ticketCategoryId;
      _selectedPriorityId = widget.ticket!.proprityId;
      _selectedLabelId = widget.ticket!.labelId;
      _selectedStatusId = widget.ticket!.ticketStatusId;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final ticket = TicketModel(
      id: widget.ticket?.id ?? 0,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      ticketCategoryId: _selectedCategoryId ?? 1,
      proprityId: _selectedPriorityId ?? 3,
      labelId: _selectedLabelId ?? 1,
      ticketStatusId: _selectedStatusId ?? 1,
      empId: widget.ticket?.empId ?? 1,
      assignedEmpId: widget.ticket?.assignedEmpId,
      empName: widget.ticket?.empName,
      ticketStatusName: widget.ticket?.ticketStatusName,
      assignedEmpName: widget.ticket?.assignedEmpName,
      labelName: widget.ticket?.labelName,
      proprityName: widget.ticket?.proprityName,
      ticketCategoryName: widget.ticket?.ticketCategoryName,
      uniqueNo: widget.ticket?.uniqueNo,
      ticketStatusColor: widget.ticket?.ticketStatusColor,
      priorityColor: widget.ticket?.priorityColor,
      labelColor: widget.ticket?.labelColor,
      custPropData: widget.ticket?.custPropData,
      baseListInfo: widget.ticket?.baseListInfo,
    );

    final success = await ref.read(ticketProvider.notifier).saveTicket(ticket);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(ticketProvider).saveSuccessMessage ?? 'Ticket saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(ticketProvider).errorMessage ?? 'Failed to save ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(ticketProvider);
    final optionsState = ref.watch(dropdownOptionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Ticket' : 'New Ticket',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category
              _buildSectionTitle('Category'),
              const SizedBox(height: 8),
              optionsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDropdown(
                      value: _selectedCategoryId,
                      hint: 'Select category',
                      items: optionsState.categories
                          .map((option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(option.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
              const SizedBox(height: 20),

              // Priority
              _buildSectionTitle('Priority'),
              const SizedBox(height: 8),
              optionsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDropdown(
                      value: _selectedPriorityId,
                      hint: 'Select priority',
                      items: optionsState.priorities
                          .map((option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(option.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPriorityId = value;
                        });
                      },
                    ),
              const SizedBox(height: 20),

              // Label
              _buildSectionTitle('Label'),
              const SizedBox(height: 8),
              optionsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDropdown(
                      value: _selectedLabelId,
                      hint: 'Select label',
                      items: optionsState.labels
                          .map((option) => DropdownMenuItem(
                                value: option.value,
                                child: Row(
                                  children: [
                                    if (option.colorCode != null) ...[
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _parseColor(option.colorCode!),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(option.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLabelId = value;
                        });
                      },
                    ),

              if (isEditMode) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Status'),
                const SizedBox(height: 8),
                optionsState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDropdown(
                        value: _selectedStatusId,
                        hint: 'Select status',
                        items: optionsState.statuses
                            .map((option) => DropdownMenuItem(
                                  value: option.value,
                                  child: Text(option.label),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatusId = value;
                          });
                        },
                      ),
              ],
              const SizedBox(height: 20),

              // Subject
              _buildSectionTitle('Subject'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _subjectController,
                hintText: 'Enter ticket subject',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description
              _buildSectionTitle('Description'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _bodyController,
                hintText: 'Describe your issue or request in detail...',
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: ticketState.isSaving ? null : _saveTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: ticketState.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isEditMode ? 'Update Ticket' : 'Create Ticket',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1D1F),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1D1F),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 14,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required int? value,
    required String hint,
    required List<DropdownMenuItem<int>> items,
    required void Function(int?) onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      hint: Text(
        hint,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
      isExpanded: true,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1D1F),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
      validator: (value) {
        if (value == null) {
          return 'Please select an option';
        }
        return null;
      },
    );
  }
  
  Color _parseColor(String colorCode) {
    try {
      return Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}
