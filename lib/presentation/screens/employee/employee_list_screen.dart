import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/employee_model.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/common/loading_widget.dart';
import 'employee_detail_screen.dart';

/// Employee list screen with cards
class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<EmployeeModel> _filteredEmployees = [];
  String _lastApiSearchKeyword = '';

  @override
  void initState() {
    super.initState();
    // Fetch employees on screen load
    Future.microtask(() {
      ref.read(employeeProvider.notifier).fetchEmployees();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {
      _applyFilter();
    });
  }

  List<EmployeeModel> _applyFilter() {
    final employeeState = ref.read(employeeProvider);
    final searchText = _searchController.text.trim();
    
    if (searchText.isEmpty) {
      return employeeState.employees;
    }
    
    final searchLower = searchText.toLowerCase();
    return employeeState.employees.where((employee) {
      final fullName = employee.fullName.toLowerCase();
      final empCode = employee.empCode?.toLowerCase() ?? '';
      final email = employee.emailId?.toLowerCase() ?? '';
      final designation = employee.designation?.toLowerCase() ?? '';
      final department = employee.department?.toLowerCase() ?? '';
      
      return fullName.contains(searchLower) ||
             empCode.contains(searchLower) ||
             email.contains(searchLower) ||
             designation.contains(searchLower) ||
             department.contains(searchLower);
    }).toList();
  }

  void _onSearchButtonPressed() {
    final keyword = _searchController.text.trim();
    _lastApiSearchKeyword = keyword;
    ref.read(employeeProvider.notifier).fetchEmployees(keyword: keyword);
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeProvider);
    
    // Always apply the current filter when employee data changes
    _filteredEmployees = _applyFilter();
    
    print('UI rebuild: ${employeeState.employees.length} employees, filtered: ${_filteredEmployees.length}, isLoading=${employeeState.isLoading}, isLoadingMore=${employeeState.isLoadingMore}');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Employee Management',
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
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Employee count
          if (!employeeState.isLoading && employeeState.employees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _searchController.text.isNotEmpty && _lastApiSearchKeyword.isEmpty
                        ? 'Showing ${_filteredEmployees.length} of ${employeeState.employees.length} employees'
                        : 'Showing ${employeeState.employees.length} out of ${employeeState.totalRecords} employees',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),

          // Employee list
          Expanded(
            child: _buildBody(employeeState),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                          if (_lastApiSearchKeyword.isNotEmpty) {
                            _lastApiSearchKeyword = '';
                            ref.read(employeeProvider.notifier).fetchEmployees();
                          }
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _onSearchButtonPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Icon(Icons.search, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EmployeeState state) {
    if (state.isLoading && state.employees.isEmpty) {
      return const LoadingWidget(message: 'Loading employees...');
    }

    if (state.errorMessage != null && state.employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(employeeProvider.notifier).fetchEmployees();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No employees found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      );
    }

    // Local search resulted in no matches
    if (_filteredEmployees.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No matching employees found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(employeeProvider.notifier).fetchEmployees(
            keyword: _searchController.text,
          ),
      child: ListView.builder(
        key: ValueKey(_filteredEmployees.length),
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredEmployees.length + (state.hasMore && _searchController.text.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredEmployees.length) {
            return _buildLoadMoreButton(state.isLoadingMore);
          }
          final employee = _filteredEmployees[index];
          return _buildEmployeeCard(employee, index);
        },
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: () {
                  ref.read(employeeProvider.notifier).loadMore();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Load More'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee, int index) {
    return Card(
      key: ValueKey('employee_${employee.id}_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeDetailScreen(employee: employee),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Employee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (employee.empCode != null)
                      Text(
                        employee.empCode!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    if (employee.designation != null)
                      Text(
                        employee.designation!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    if (employee.department != null)
                      Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              employee.department!,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Status badge and chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (employee.empStatusType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: employee.empStatusType == 'Active'
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        employee.empStatusType!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: employee.empStatusType == 'Active'
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
