import 'package:flutter/material.dart';
import './dashboard_page.dart';
import './time_page.dart';
import './product_page.dart';
import './profile_page.dart';
import '../services/supabase_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const DashboardPage(),
    const TimePage(),
    const ProductPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkData();
  }

  Future<void> _checkData() async {
    try {
      // ตรวจสอบขถานะการ login
      if (!SupabaseService.isLoggedIn()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
          );
        }
        return;
      }

      // ตรวจสอบข้อมูลโปรไฟล์
      final profile = await SupabaseService.getUserProfile();
      if (profile != null) {
        print('Profile data: $profile');
      }

      // ตรวจสอบสถิติการทำงาน
      final timeStats = await SupabaseService.getTimeStats();
      if (timeStats != null) {
        print('Time stats: $timeStats');
      }

      // ตรวจสอบสถิติการเงิน
      final balanceStats = await SupabaseService.getBalanceStats();
      if (balanceStats != null) {
        print('Balance stats: $balanceStats');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Time',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Product',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 