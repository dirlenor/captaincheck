import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // Sign In
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        throw Exception('การเข้าสู่ระบบล้มเหลว');
      }

      return response;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e');
    }
  }

  // Sign Up
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );

      if (response.user != null) {
        try {
          // Create profile record with initial values
          await _supabase.from('profiles').upsert({
            'id': response.user!.id,
            'name': name,
            'email': email,
            'total_work_days': 0,
            'total_work_hours': 0.0,
            'total_ot_hours': 0.0,
            'remaining_balance': 0.0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          // Initialize time records for the current month
          await _supabase.from('time_records').upsert({
            'user_id': response.user!.id,
            'month': DateTime.now().month,
            'year': DateTime.now().year,
            'work_days': 0,
            'work_hours': 0.0,
            'ot_hours': 0.0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

        } catch (e) {
          print('Error creating initial user data: $e');
          throw Exception('ไม่สามารถสร้างข้อมูลเริ่มต้น: $e');
        }
      } else {
        throw Exception('ไม่สามารถสร้างบัญชีผู้ใช้ได้');
      }

      return response;
    } catch (e) {
      print('Error signing up: $e');
      if (e.toString().contains('User already registered')) {
        throw Exception('อีเม���นี้ถูกใช้งานแล้ว');
      }
      if (e.toString().contains('Email signups are disabled')) {
        throw Exception('ระบบยังไม่เปิดให้ลงทะเบียนด้วยอีเมล กรุณาติดต่อผู้ดูแลระบบ');
      }
      throw Exception(e.toString());
    }
  }

  // Sign Out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการออกจากระบบ: $e');
    }
  }

  // Get User Profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    
    try {
      // ดึงข้อมูลโปรไฟล์
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      // ดึงข้อมูลสถิติรวมจาก time_records
      final timeRecordsResponse = await _supabase
          .from('time_records')
          .select()
          .eq('user_id', userId);

      // คำนวณสถิติรวม
      double totalWorkHours = 0;
      double totalOtHours = 0;
      double totalAmount = 0;
      Set<String> workDays = {};

      for (final record in timeRecordsResponse) {
        totalWorkHours += (record['work_hours'] ?? 0).toDouble();
        totalOtHours += (record['ot_hours'] ?? 0).toDouble();
        totalAmount += (record['total_amount'] ?? 0).toDouble();
        if (record['work_date'] != null) {
          workDays.add(record['work_date']);
        }
      }

      return {
        ...profileResponse,
        'total_work_days': workDays.length,
        'total_work_hours': totalWorkHours,
        'total_ot_hours': totalOtHours,
        'remaining_balance': profileResponse['remaining_balance'] ?? totalAmount,
      };
    } catch (e) {
      print('Error getting profile: $e');
      rethrow;
    }
  }

  // Update User Profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

    await _supabase
        .from('profiles')
        .update(data)
        .eq('id', user.id);
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  // Get Monthly Stats
  static Future<Map<String, dynamic>> getMonthlyStats() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final response = await _supabase.rpc('calculate_monthly_stats', params: {
      'user_id': userId,
      'start_date': startOfMonth.toIso8601String(),
      'end_date': endOfMonth.toIso8601String(),
    });

    return {
      'work_hours': response['work_hours'] ?? 0.0,
      'ot_hours': response['ot_hours'] ?? 0.0,
      'total_amount': response['total_amount'] ?? 0.0,
      'work_days': response['work_days'] ?? 0,
    };
  }

  // Get Time Stats
  static Future<Map<String, dynamic>> getTimeStats() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final response = await _supabase.rpc('calculate_time_stats', params: {
      'user_id': userId,
      'start_date': startOfMonth.toIso8601String(),
      'end_date': endOfMonth.toIso8601String(),
    });

    return {
      'work_days': response['work_days'] ?? 0,
      'work_hours': response['work_hours'] ?? 0.0,
      'ot_hours': response['ot_hours'] ?? 0.0,
    };
  }

  // Get Balance Stats
  static Future<Map<String, dynamic>> getBalanceStats() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final response = await _supabase.rpc('calculate_balance_stats', params: {
      'user_id': userId,
      'start_date': startOfMonth.toIso8601String(),
      'end_date': endOfMonth.toIso8601String(),
    });

    return {
      'total_amount': response['total_amount'] ?? 0.0,
      'remaining_balance': response['remaining_balance'] ?? 0.0,
    };
  }

  // Get Today's Time Record
  static Future<Map<String, dynamic>?> getTodayTimeRecord() async {
    final userId = _supabase.auth.currentUser!.id;
    final today = DateTime.now();
    
    try {
      final response = await _supabase
          .from('time_records')
          .select()
          .eq('user_id', userId)
          .eq('work_date', today.toIso8601String().split('T')[0])
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Get Time Records for a specific period
  static Future<List<Map<String, dynamic>>> getTimeRecords({
    required DateTime startDate, 
    required DateTime endDate
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('time_records')
        .select()
        .eq('user_id', userId)
        .gte('work_date', startDate.toIso8601String().split('T')[0])
        .lte('work_date', endDate.toIso8601String().split('T')[0]);

    return List<Map<String, dynamic>>.from(response);
  }

  // Check In
  static Future<void> checkIn(DateTime? workDate, String shiftType) async {
    if (workDate == null) {
      throw ArgumentError('กรุณาเลือกวันที่');
    }

    final userId = _supabase.auth.currentUser!.id;
    
    // ตรวจสอบว่ามีการลงเวลาในวันนี้แล้วหรือไม่
    final existingRecord = await _supabase
        .from('time_records')
        .select()
        .eq('user_id', userId)
        .eq('work_date', workDate.toIso8601String().split('T')[0]);
    
    if ((existingRecord as List).isNotEmpty) {
      throw Exception('ไม่สามารถลงเวลาได้ เนื่องจากมีการลงเวลาในวันนี้ไปแล้ว');
    }
    
    // กำหนดรายละเอียดกะ
    final Map<String, Map<String, dynamic>> shiftDetails = {
      'morning': {
        'start_time': '08:30',
        'end_time': '17:30',
        'work_hours': 8.0,
        'ot_hours': 0.0,
        'total_amount': 360.0,
      },
      'afternoon': {
        'start_time': '12:30',
        'end_time': '21:30',
        'work_hours': 8.0,
        'ot_hours': 0.0,
        'total_amount': 360.0,
      },
      'full': {
        'start_time': '08:30',
        'end_time': '21:30',
        'work_hours': 8.0,
        'ot_hours': 4.0,
        'total_amount': 600.0,
      }
    };

    final shiftData = shiftDetails[shiftType];
    if (shiftData == null) {
      throw ArgumentError('กรุณาเลือกกะการทำงาน');
    }

    try {
      // บันทึกข้อมูลการลงเวลา
      await _supabase.from('time_records').insert({
        'user_id': userId,
        'work_date': workDate.toIso8601String().split('T')[0],
        'shift_type': shiftType,
        'start_time': shiftData['start_time'],
        'end_time': shiftData['end_time'],
        'work_hours': shiftData['work_hours'],
        'ot_hours': shiftData['ot_hours'],
        'total_amount': shiftData['total_amount'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // อัพเดตยอดเงินคงเหลือ
      await _updateRemainingBalance(userId, shiftData['total_amount']);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
    }
  }

  // อัพเดตยอดเงินคงเหลือ
  static Future<void> _updateRemainingBalance(String userId, double amount) async {
    await _supabase.rpc('update_remaining_balance', params: {
      'user_id': userId,
      'amount': amount,
    });
  }

  // Product Functions

  // ดึงรายการสินค้าทั้งหมด
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการดึงข้อมูลสินค้า: $e');
    }
  }

  // เพิ่มสินค้าใหม่
  static Future<void> addProduct({
    required String name,
    required String category,
    required int quantity,
    required String unit,
  }) async {
    try {
      await _supabase.from('products').insert({
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเพิ่มสินค้า: $e');
    }
  }

  // อัพเดตจำนวนสินค้า
  static Future<void> updateProductQuantity({
    required String productId,
    required int quantity,
  }) async {
    try {
      await _supabase
          .from('products')
          .update({'quantity': quantity})
          .eq('id', productId);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการอัพเดตจำนวนสินค้า: $e');
    }
  }

  // บันทึกประวัติการเบิกสินค้า
  static Future<void> withdrawProduct({
    required String productId,
    required int quantity,
    String? note,
  }) async {
    try {
      // 1. ตรวจสอบจำนวนสินค้าคงเหลือ
      final product = await _supabase
          .from('products')
          .select('quantity')
          .eq('id', productId)
          .single();
      
      final currentQuantity = product['quantity'] as int;
      if (currentQuantity < quantity) {
        throw Exception('จำนวนสินค้าคงเหลือไม่เพียงพอ');
      }
      
      // 2. อัพเดตจำนวนสินค้าคงเหลือ
      await _supabase
          .from('products')
          .update({'quantity': currentQuantity - quantity})
          .eq('id', productId);
      
      // 3. บันทึกประวัติการเบิก
      await _supabase.from('withdrawal_history').insert({
        'product_id': productId,
        'quantity': quantity,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเบิกสินค้า: $e');
    }
  }

  // ดึงประวัติการเบิกสินค้า
  static Future<List<Map<String, dynamic>>> getWithdrawalHistory() async {
    try {
      final response = await _supabase
          .from('withdrawal_history')
          .select('*, products(name, unit)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการดึงประวัติการเบิกสินค้า: $e');
    }
  }

  // เพิ่มข้อมูลสินค้าเริ่มต้น
  static Future<void> initializeDefaultProducts() async {
    final defaultProducts = [
      {
        'name': 'ปากาลูกลื่น',
        'category': 'เครื่องเขียน',
        'quantity': 50,
        'unit': 'ด้าม',
      },
      {
        'name': 'กระดาษ A4',
        'category': 'กระดาษ',
        'quantity': 20,
        'unit': 'รีม',
      },
      {
        'name': 'แฟ้มอกสรร',
        'category': 'อุปกรณ์จัดเก็บ',
        'quantity': 30,
        'unit': 'แฟ้ม',
      },
      {
        'name': 'ลวดเย็บกระดาษ',
        'category': 'เครื่องเขียน',
        'quantity': 100,
        'unit': 'กล่อง',
      },
      {
        'name': 'ดินสอ 2B',
        'category': 'เครื่องเขียน',
        'quantity': 40,
        'unit': 'แท่ง',
      },
      {
        'name': 'กระดาษโน้ต',
        'category': 'กระดาษ',
        'quantity': 25,
        'unit': 'เล่ม',
      },
      {
        'name': 'กล่องใส่เอกสาร',
        'category': 'อุปกรณ์จัดเก็บ',
        'quantity': 15,
        'unit': 'กล่อง',
      },
      {
        'name': 'ยางลบ',
        'category': 'เครื่องเขียน',
        'quantity': 60,
        'unit': 'ก้อน',
      },
      {
        'name': 'กระดาษสี',
        'category': 'กระดาษ',
        'quantity': 10,
        'unit': 'แพ็ค',
      },
      {
        'name': 'ตู้เอกสาร',
        'category': 'อุปกร��์จัดเก็บ',
        'quantity': 5,
        'unit': 'ตู้',
      },
    ];

    try {
      // เพิ่มสินค้าทุกรายการ
      for (final product in defaultProducts) {
        await addProduct(
          name: product['name'] as String,
          category: product['category'] as String,
          quantity: product['quantity'] as int,
          unit: product['unit'] as String,
        );
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเพิ่มสินค้าเริ่มต้น: $e');
    }
  }

  // ลบสินค้า
  static Future<void> deleteProduct(String productId) async {
    try {
      // เรียกใช้ stored procedure ที่จะจัดการลบข้อมูลทั้งหมดที่เกี่ยวข้อง
      await _supabase.rpc('delete_product_with_history', params: {
        'product_id_param': productId
      });
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการลบสินค้า: $e');
    }
  }

  // ดึงรายการหมวดหมู่
  static Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('name')
          .order('name');
      return List<String>.from(response.map((item) => item['name'] as String));
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการดึงข้อมูลหมวดหมู่: $e');
    }
  }

  // เพิ่มหมวดหมู่
  static Future<void> addCategory(String name) async {
    try {
      await _supabase.from('categories').insert({
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเพิ่มหมวดหมู่: $e');
    }
  }

  // ลบหมวดหมู่
  static Future<void> deleteCategory(String name) async {
    try {
      await _supabase
          .from('categories')
          .delete()
          .eq('name', name);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการลบหมวดหมู่: $e');
    }
  }
} 