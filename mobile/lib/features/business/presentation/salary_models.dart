part of 'business_shell.dart';

// ── Employees / Сотрудники ─────────────────────────────────────────────────────

class _Employee {
  const _Employee({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.fullName,
    required this.position,
    required this.iin,
    required this.phone,
    required this.salaryType,
    required this.monthlySalary,
    required this.hourlyRate,
    required this.pieceRate,
    required this.pieceRateSource,
    required this.salesPercent,
    required this.salesBasis,
    required this.standardDays,
    required this.hireDate,
    required this.status,
    required this.notes,
  });

  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String fullName;
  final String position;
  final String iin;
  final String phone;
  final String salaryType;
  final int monthlySalary;
  final int hourlyRate;
  final int pieceRate;
  final String pieceRateSource;
  final double salesPercent;
  final String salesBasis;
  final int standardDays;
  final String hireDate;
  final String status;
  final String notes;

  bool get isActive => status == 'active';

  bool get hasLinkedUser => userId.isNotEmpty;

  String get linkedUserLabel {
    if (!hasLinkedUser) return 'Не связан';
    if (userName.isNotEmpty && userPhone.isNotEmpty) {
      return '$userName · $userPhone';
    }
    if (userName.isNotEmpty) return userName;
    if (userPhone.isNotEmpty) return userPhone;
    return 'Пользователь';
  }

  String get salaryTypeLabel => salaryTypeLabelFor(salaryType);

  String get salesBasisLabel =>
      salesBasis == 'profit' ? 'с прибыли' : 'с выручки';

  /// Short human-readable description of how this employee is paid.
  String get payDescription {
    final parts = <String>[];
    switch (salaryType) {
      case 'monthly':
        parts.add('Оклад ${formatMoney(monthlySalary)}');
      case 'hourly':
        parts.add('${formatMoney(hourlyRate)}/час');
      case 'piece_rate':
        parts.add('Сдельная');
      case 'bonus':
        parts.add('Бонусная');
      case 'combined':
        parts.add('Оклад ${formatMoney(monthlySalary)}');
    }
    if (salesPercent > 0) {
      parts.add('${_formatPercent(salesPercent)}% $salesBasisLabel');
    }
    return parts.join(' + ');
  }
}

String _formatPercent(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

String salaryTypeLabelFor(String salaryType) {
  switch (salaryType) {
    case 'monthly':
      return 'Оклад';
    case 'hourly':
      return 'Почасовая';
    case 'piece_rate':
      return 'Сдельная';
    case 'bonus':
      return 'Бонусная';
    case 'combined':
      return 'Комбинированная';
    default:
      return salaryType;
  }
}

_Employee _employeeFromJson(Map<String, dynamic> j) => _Employee(
      id: j['id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      userName: j['user_name'] as String? ?? '',
      userPhone: j['user_phone'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      position: j['position'] as String? ?? '',
      iin: j['iin'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      salaryType: j['salary_type'] as String? ?? 'monthly',
      monthlySalary: j['monthly_salary'] as int? ?? 0,
      hourlyRate: j['hourly_rate'] as int? ?? 0,
      pieceRate: j['piece_rate'] as int? ?? 0,
      pieceRateSource: j['piece_rate_source'] as String? ?? 'none',
      salesPercent: (j['sales_percent'] as num?)?.toDouble() ?? 0,
      salesBasis: j['sales_basis'] as String? ?? 'revenue',
      standardDays: j['standard_days'] as int? ?? 22,
      hireDate: j['hire_date'] as String? ?? '',
      status: j['status'] as String? ?? 'active',
      notes: j['notes'] as String? ?? '',
    );

class _PayrollUser {
  const _PayrollUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.roleLabel,
  });

  final String userId;
  final String fullName;
  final String phone;
  final String role;
  final String roleLabel;

  String get label {
    if (fullName.isNotEmpty && phone.isNotEmpty) return '$fullName · $phone';
    if (fullName.isNotEmpty) return fullName;
    if (phone.isNotEmpty) return phone;
    return roleLabel;
  }
}

_PayrollUser _payrollUserFromJson(Map<String, dynamic> j) => _PayrollUser(
      userId: j['user_id'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      role: j['role'] as String? ?? 'staff',
      roleLabel: j['role_label'] as String? ?? 'Сотрудник',
    );

// ── Payroll periods / Ведомости ────────────────────────────────────────────────

class _PayrollPeriod {
  const _PayrollPeriod({
    required this.id,
    required this.periodYear,
    required this.periodMonth,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.employeeCount,
    required this.totalNet,
    required this.paidCount,
  });

  final String id;
  final int periodYear;
  final int periodMonth;
  final String title;
  final String status;
  final String createdAt;
  final int employeeCount;
  final int totalNet;
  final int paidCount;

  String get statusLabel {
    switch (status) {
      case 'calculated':
        return 'Рассчитана';
      case 'paid':
        return 'Выплачена';
      case 'cancelled':
        return 'Отменена';
      default:
        return 'Черновик';
    }
  }

  StatusKind get statusKind {
    switch (status) {
      case 'calculated':
        return StatusKind.info;
      case 'paid':
        return StatusKind.success;
      case 'cancelled':
        return StatusKind.error;
      default:
        return StatusKind.neutral;
    }
  }
}

_PayrollPeriod _payrollPeriodFromJson(Map<String, dynamic> j) => _PayrollPeriod(
      id: j['id'] as String? ?? '',
      periodYear: j['period_year'] as int? ?? 0,
      periodMonth: j['period_month'] as int? ?? 0,
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? 'draft',
      createdAt: j['created_at'] as String? ?? '',
      employeeCount: j['employee_count'] as int? ?? 0,
      totalNet: j['total_net'] as int? ?? 0,
      paidCount: j['paid_count'] as int? ?? 0,
    );

class _PayrollEntry {
  const _PayrollEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.salaryType,
    required this.daysWorked,
    required this.hoursWorked,
    required this.overtimeHours,
    required this.vacationDays,
    required this.sickDays,
    required this.absentDays,
    required this.baseAmount,
    required this.pieceAmount,
    required this.bonusAmount,
    required this.overtimeAmount,
    required this.vacationAmount,
    required this.deductions,
    required this.grossAmount,
    required this.netAmount,
    required this.isPaid,
    required this.paidAt,
    required this.notes,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String position;
  final String salaryType;
  final double daysWorked;
  final double hoursWorked;
  final double overtimeHours;
  final double vacationDays;
  final double sickDays;
  final double absentDays;
  final int baseAmount;
  final int pieceAmount;
  final int bonusAmount;
  final int overtimeAmount;
  final int vacationAmount;
  final int deductions;
  final int grossAmount;
  final int netAmount;
  final bool isPaid;
  final String paidAt;
  final String notes;

  String get salaryTypeLabel => salaryTypeLabelFor(salaryType);
}

_PayrollEntry _payrollEntryFromJson(Map<String, dynamic> j) => _PayrollEntry(
      id: j['id'] as String? ?? '',
      employeeId: j['employee_id'] as String? ?? '',
      employeeName: j['employee_name'] as String? ?? '',
      position: j['position'] as String? ?? '',
      salaryType: j['salary_type'] as String? ?? 'monthly',
      daysWorked: (j['days_worked'] as num?)?.toDouble() ?? 0,
      hoursWorked: (j['hours_worked'] as num?)?.toDouble() ?? 0,
      overtimeHours: (j['overtime_hours'] as num?)?.toDouble() ?? 0,
      vacationDays: (j['vacation_days'] as num?)?.toDouble() ?? 0,
      sickDays: (j['sick_days'] as num?)?.toDouble() ?? 0,
      absentDays: (j['absent_days'] as num?)?.toDouble() ?? 0,
      baseAmount: j['base_amount'] as int? ?? 0,
      pieceAmount: j['piece_amount'] as int? ?? 0,
      bonusAmount: j['bonus_amount'] as int? ?? 0,
      overtimeAmount: j['overtime_amount'] as int? ?? 0,
      vacationAmount: j['vacation_amount'] as int? ?? 0,
      deductions: j['deductions'] as int? ?? 0,
      grossAmount: j['gross_amount'] as int? ?? 0,
      netAmount: j['net_amount'] as int? ?? 0,
      isPaid: j['is_paid'] as bool? ?? false,
      paidAt: j['paid_at'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
    );

class _PayrollPeriodDetail {
  const _PayrollPeriodDetail({
    required this.period,
    required this.entries,
  });

  final _PayrollPeriod period;
  final List<_PayrollEntry> entries;
}

_PayrollPeriodDetail _payrollPeriodDetailFromJson(Map<String, dynamic> j) =>
    _PayrollPeriodDetail(
      period: _payrollPeriodFromJson(
        j['period'] as Map<String, dynamic>? ?? const {},
      ),
      entries: (j['entries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_payrollEntryFromJson)
          .toList(growable: false),
    );

String _formatHours(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

class _EmployeeStatementEntry {
  const _EmployeeStatementEntry({
    required this.periodYear,
    required this.periodMonth,
    required this.title,
    required this.status,
    required this.daysWorked,
    required this.hoursWorked,
    required this.baseAmount,
    required this.pieceAmount,
    required this.bonusAmount,
    required this.overtimeAmount,
    required this.vacationAmount,
    required this.deductions,
    required this.grossAmount,
    required this.netAmount,
    required this.isPaid,
    required this.paidAt,
  });

  final int periodYear;
  final int periodMonth;
  final String title;
  final String status;
  final double daysWorked;
  final double hoursWorked;
  final int baseAmount;
  final int pieceAmount;
  final int bonusAmount;
  final int overtimeAmount;
  final int vacationAmount;
  final int deductions;
  final int grossAmount;
  final int netAmount;
  final bool isPaid;
  final String paidAt;

  String get periodLabel {
    if (title.isNotEmpty) return title;
    return '${periodMonth.toString().padLeft(2, '0')}.$periodYear';
  }
}

class _EmployeeStatement {
  const _EmployeeStatement({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.from,
    required this.to,
    required this.totalBase,
    required this.totalPiece,
    required this.totalBonus,
    required this.totalOvertime,
    required this.totalVacation,
    required this.totalDeductions,
    required this.totalGross,
    required this.totalNet,
    required this.totalPaid,
    required this.entries,
  });

  final String employeeId;
  final String employeeName;
  final String position;
  final String from;
  final String to;
  final int totalBase;
  final int totalPiece;
  final int totalBonus;
  final int totalOvertime;
  final int totalVacation;
  final int totalDeductions;
  final int totalGross;
  final int totalNet;
  final int totalPaid;
  final List<_EmployeeStatementEntry> entries;
}

_EmployeeStatementEntry _employeeStatementEntryFromJson(
        Map<String, dynamic> j) =>
    _EmployeeStatementEntry(
      periodYear: j['period_year'] as int? ?? 0,
      periodMonth: j['period_month'] as int? ?? 0,
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? '',
      daysWorked: (j['days_worked'] as num?)?.toDouble() ?? 0,
      hoursWorked: (j['hours_worked'] as num?)?.toDouble() ?? 0,
      baseAmount: j['base_amount'] as int? ?? 0,
      pieceAmount: j['piece_amount'] as int? ?? 0,
      bonusAmount: j['bonus_amount'] as int? ?? 0,
      overtimeAmount: j['overtime_amount'] as int? ?? 0,
      vacationAmount: j['vacation_amount'] as int? ?? 0,
      deductions: j['deductions'] as int? ?? 0,
      grossAmount: j['gross_amount'] as int? ?? 0,
      netAmount: j['net_amount'] as int? ?? 0,
      isPaid: j['is_paid'] as bool? ?? false,
      paidAt: j['paid_at'] as String? ?? '',
    );

_EmployeeStatement _employeeStatementFromJson(Map<String, dynamic> j) =>
    _EmployeeStatement(
      employeeId: j['employee_id'] as String? ?? '',
      employeeName: j['employee_name'] as String? ?? '',
      position: j['position'] as String? ?? '',
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      totalBase: j['total_base'] as int? ?? 0,
      totalPiece: j['total_piece'] as int? ?? 0,
      totalBonus: j['total_bonus'] as int? ?? 0,
      totalOvertime: j['total_overtime'] as int? ?? 0,
      totalVacation: j['total_vacation'] as int? ?? 0,
      totalDeductions: j['total_deductions'] as int? ?? 0,
      totalGross: j['total_gross'] as int? ?? 0,
      totalNet: j['total_net'] as int? ?? 0,
      totalPaid: j['total_paid'] as int? ?? 0,
      entries: (j['entries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_employeeStatementEntryFromJson)
          .toList(growable: false),
    );
