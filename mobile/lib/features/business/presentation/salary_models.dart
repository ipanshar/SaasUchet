part of 'business_shell.dart';

// ── Employees / Сотрудники ─────────────────────────────────────────────────────

class _Employee {
  const _Employee({
    required this.id,
    required this.fullName,
    required this.position,
    required this.iin,
    required this.phone,
    required this.salaryType,
    required this.monthlySalary,
    required this.hourlyRate,
    required this.pieceRate,
    required this.pieceRateSource,
    required this.standardDays,
    required this.hireDate,
    required this.status,
    required this.notes,
  });

  final String id;
  final String fullName;
  final String position;
  final String iin;
  final String phone;
  final String salaryType;
  final int monthlySalary;
  final int hourlyRate;
  final int pieceRate;
  final String pieceRateSource;
  final int standardDays;
  final String hireDate;
  final String status;
  final String notes;

  bool get isActive => status == 'active';

  String get salaryTypeLabel => salaryTypeLabelFor(salaryType);

  String get pieceRateSourceLabel {
    switch (pieceRateSource) {
      case 'production':
        return 'Производство';
      case 'sales':
        return 'Продажи';
      case 'purchases':
        return 'Закупки';
      default:
        return '—';
    }
  }

  /// Short human-readable description of how this employee is paid.
  String get payDescription {
    switch (salaryType) {
      case 'monthly':
        return 'Оклад ${formatMoney(monthlySalary)}';
      case 'hourly':
        return '${formatMoney(hourlyRate)}/час';
      case 'piece_rate':
        return 'Сдельно ${formatMoney(pieceRate)} ($pieceRateSourceLabel)';
      case 'bonus':
        return 'Бонусная';
      case 'combined':
        final parts = <String>['Оклад ${formatMoney(monthlySalary)}'];
        if (pieceRate > 0 && pieceRateSource != 'none') {
          parts.add('сдельно ${formatMoney(pieceRate)}');
        }
        return parts.join(' + ');
      default:
        return '';
    }
  }
}

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
      fullName: j['full_name'] as String? ?? '',
      position: j['position'] as String? ?? '',
      iin: j['iin'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      salaryType: j['salary_type'] as String? ?? 'monthly',
      monthlySalary: j['monthly_salary'] as int? ?? 0,
      hourlyRate: j['hourly_rate'] as int? ?? 0,
      pieceRate: j['piece_rate'] as int? ?? 0,
      pieceRateSource: j['piece_rate_source'] as String? ?? 'none',
      standardDays: j['standard_days'] as int? ?? 22,
      hireDate: j['hire_date'] as String? ?? '',
      status: j['status'] as String? ?? 'active',
      notes: j['notes'] as String? ?? '',
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
