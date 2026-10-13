import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/employee_model.dart';
import '../../widgets/common/contact_actions.dart';
import 'org_chart_screen.dart';

/// Employee detail screen showing full information
class EmployeeDetailScreen extends StatelessWidget {
  final EmployeeModel employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Employee Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D1F),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF1A1D1F),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            _buildProfileHeader(context),
            const SizedBox(height: 8),
            ContactBar(mobile: employee.mobileNo, email: employee.emailId),
            if (employee.id != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrgChartScreen(employeeId: employee.id)),
                  ),
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: const Text('View in org chart'),
                ),
              ),
            const SizedBox(height: 8),

            // Personal Information
            _buildSection(
              context,
              'Personal Information',
              Icons.person_outline_rounded,
              [
                if (employee.empCode != null)
                  _buildInfoRow('Employee Code', employee.empCode!),
                _buildInfoRow('Name', employee.fullName),
                if (employee.gender != null)
                  _buildInfoRow('Gender', employee.gender!),
                if (employee.dob != null) _buildInfoRow('Date of Birth', _formatDate(employee.dob!)),
                if (employee.maritalStatusName != null)
                  _buildInfoRow('Marital Status', employee.maritalStatusName!),
                if (employee.bloodGroup != null)
                  _buildInfoRow('Blood Group', employee.bloodGroup!),
                if (employee.nationality != null)
                  _buildInfoRow('Nationality', employee.nationality!),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Information
            _buildSection(
              context,
              'Contact Information',
              Icons.contact_phone_outlined,
              [
                if (employee.emailId != null)
                  _buildInfoRow('Email', employee.emailId!),
                if (employee.personalEmailId != null)
                  _buildInfoRow('Personal Email', employee.personalEmailId!),
                if (employee.mobileNo != null)
                  _buildInfoRow('Mobile', employee.mobileNo!),
              ],
            ),
            const SizedBox(height: 16),

            // Employment Information
            _buildSection(
              context,
              'Employment Information',
              Icons.work_outline_rounded,
              [
                if (employee.designation != null)
                  _buildInfoRow('Designation', employee.designation!),
                if (employee.department != null)
                  _buildInfoRow('Department', employee.department!),
                if (employee.role != null) _buildInfoRow('Role', employee.role!),
                if (employee.joiningDate != null)
                  _buildInfoRow('Joining Date', _formatDate(employee.joiningDate!)),
                if (employee.relevingDate != null)
                  _buildInfoRow('Relieving Date', _formatDate(employee.relevingDate!)),
                if (employee.empStatusType != null)
                  _buildInfoRow('Status', employee.empStatusType!),
                if (employee.businessUnitName != null)
                  _buildInfoRow('Business Unit', employee.businessUnitName!),
                if (employee.reportingToName != null)
                  _buildInfoRow('Reporting To', employee.reportingToName!),
              ],
            ),
            const SizedBox(height: 16),

            // Organization Information
            if (employee.orgName != null)
              _buildSection(
                context,
                'Organization Information',
                Icons.business_outlined,
                [
                  _buildInfoRow('Organization', employee.orgName!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  employee.initials,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              employee.fullName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Designation
            if (employee.designation != null)
              Text(
                employee.designation!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),

            // Status badge
            if (employee.empStatusType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: employee.empStatusType == 'Active'
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  employee.empStatusType!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: employee.empStatusType == 'Active'
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
