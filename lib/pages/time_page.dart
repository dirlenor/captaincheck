import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import '../models/time_record.dart';

class TimePage extends StatefulWidget {
  const TimePage({super.key});

  @override
  State<TimePage> createState() => _TimePageState();
}

class _TimePageState extends State<TimePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;
  TimeRecord? _todayRecord;
  final Set<DateTime> _markedDates = {};
  bool _hasCheckedInToday = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      // โหลดข้อมูลการลงเวลาวันนี้
      final todayData = await SupabaseService.getTodayTimeRecord();
      if (todayData != null) {
        _todayRecord = TimeRecord.fromJson(todayData);
        _hasCheckedInToday = true;
      } else {
        _hasCheckedInToday = false;
      }

      // โหลดข้อมูลการลงเวลาทั้งเดือน
      final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
      final monthData = await SupabaseService.getTimeRecords(
        startDate: monthStart,
        endDate: monthEnd,
      );

      if (!mounted) return;

      setState(() {
        _markedDates.clear();
        for (var record in monthData) {
          if (record['work_date'] != null) {
            _markedDates.add(DateTime.parse(record['work_date']));
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  void _showShiftDialog() {
    if (!isSameDay(_selectedDay, DateTime.now()) && _selectedDay.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถลงเวลาย้อนหลังได้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_hasCheckedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถลงเวลาได้ เนื่องจากมีการลงเวลาในวันนี้ไปแล้ว'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกกะการทำงาน'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildShiftOption(
                'กะเช้า (8:30-17:30)',
                'morning',
                Icons.wb_sunny,
                Colors.orange,
                '8 ชั่วโมง - 360 บาท (พัก 1 ชม.)',
              ),
              const SizedBox(height: 8),
              _buildShiftOption(
                'กะบ่าย (12:30-21:30)',
                'afternoon',
                Icons.wb_twilight,
                Colors.blue,
                '8 ชั่วโมง - 360 บาท (พัก 1 ชม.)',
              ),
              const SizedBox(height: 8),
              _buildShiftOption(
                'เช้า+OT (8:30-21:30)',
                'full',
                Icons.nightlight_round,
                Colors.purple,
                '12 ชั่วโมง - 600 บาท (8 ชม.ปกติ + 4 ชม.OT, พัก 1 ชม.)',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftOption(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () async {
          Navigator.pop(context);
          _confirmCheckIn(value, title);
        },
      ),
    );
  }

  void _confirmCheckIn(String shiftType, String shiftTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลงเวลา'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('วันที่: ${_selectedDay?.toString().split(' ')[0] ?? 'ไม่ได้เลือกวัน'}'),
              const SizedBox(height: 8),
              Text('กะ: $shiftTitle'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  if (_selectedDay == null) {
                    throw ArgumentError('กรุณาเลือกวันที่');
                  }
                  await SupabaseService.checkIn(
                    _selectedDay!,
                    shiftType,
                  );
                  setState(() {
                    _markedDates.add(_selectedDay!);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกเวลาเรียบร้อย')),
                    );
                    _loadData(); // รีโหลดข้อมูลหลังจากบันทึก
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                    );
                  }
                }
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckInButton() {
    // เช็คว่าเป็นวันที่ผ่านมาแล้วหรือไม่
    bool isPastDate = !isSameDay(_selectedDay, DateTime.now()) && _selectedDay.isBefore(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPastDate
              ? [Colors.grey[400]!, Colors.grey[600]!]
              : _hasCheckedInToday
                  ? [Colors.red[400]!, Colors.red[600]!]
                  : [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isPastDate
                ? Colors.grey.withOpacity(0.2)
                : _hasCheckedInToday
                    ? Colors.red.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPastDate
                ? 'ไม่สามารถลงเวลาย้อนหลัง'
                : _hasCheckedInToday
                    ? 'เลิกงาน'
                    : 'ลงเวลาทำงาน',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isPastDate
                ? null  // ปิดปุ่มถ้าเป็นวันที่ผ่านมาแล้ว
                : _hasCheckedInToday
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ฟังก์ชันนี้ยังไม่พร้อมใช้งาน'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    : _showShiftDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: isPastDate
                  ? Colors.grey[600]
                  : _hasCheckedInToday
                      ? Colors.red[600]
                      : Colors.blue[600],
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPastDate
                    ? Icons.block
                    : _hasCheckedInToday
                        ? Icons.logout
                        : Icons.access_time),
                const SizedBox(width: 8),
                Text(isPastDate
                    ? 'ไม่สามารถลงเวลาย้อนหลัง'
                    : _hasCheckedInToday
                        ? 'บันทึกเวลาเลิกงาน'
                        : 'เลือกกะการทำงาน'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ลงเวลางาน',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'เลือกวันและกะการทำงานของคุณ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Calendar Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ปฏิทิน',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _focusedDay = DateTime.now();
                                      _selectedDay = DateTime.now();
                                    });
                                  },
                                  child: const Text('วันนี้'),
                                ),
                              ],
                            ),
                          ),
                          TableCalendar(
                            firstDay: DateTime.utc(2023, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarFormat: CalendarFormat.month,
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                if (_markedDates.any((element) =>
                                    isSameDay(element, date))) {
                                  return Positioned(
                                    bottom: 1,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.green,
                                      ),
                                      width: 6.0,
                                      height: 6.0,
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Check-in Button
                    _buildCheckInButton(),
                    const SizedBox(height: 20),

                    // Time Stats Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          title: 'ชั่วโมงทำงาน',
                          value: '${_todayRecord?.workHours?.toStringAsFixed(1) ?? '0.0'} ชม.',
                          icon: Icons.access_time,
                          color: Colors.green,
                          subtitle: 'ชั่วโมงทำงานเดือ��นี้',
                          progress: (_todayRecord?.workHours ?? 0) / 200,
                        ),
                        _buildStatCard(
                          title: 'ชั่วโมง OT',
                          value: '${_todayRecord?.otHours?.toStringAsFixed(1) ?? '0.0'} ชม.',
                          icon: Icons.timer,
                          color: Colors.orange,
                          subtitle: 'ชั่วโมง OT เดือนนี้',
                          progress: (_todayRecord?.otHours ?? 0) / 50,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
} 