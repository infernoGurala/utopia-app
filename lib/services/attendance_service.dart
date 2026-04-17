import 'aus_attendance_service.dart';
import 'acet_attendance_service.dart';

class AttendanceService {
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
  }) async {
    if (college == 'acet') {
      return AcetAttendanceService.fetchAttendance(
        rollNumber,
        password,
        fromDate: fromDate,
        toDate: toDate,
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
