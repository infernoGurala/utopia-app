import 'aus_attendance_service.dart';
import 'acet_attendance_service.dart';

enum AttendanceRangeMode { period, tillNow }

class AttendanceService {
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
    AttendanceRangeMode mode = AttendanceRangeMode.period,
  }) async {
    if (college == 'acet') {
      return AcetAttendanceService.fetchAttendance(
        rollNumber,
        password,
        fromDate: fromDate,
        toDate: toDate,
        mode: mode,
      );
    }
    return AusAttendanceService.fetchAttendance(
      rollNumber,
      password,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
