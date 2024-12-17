import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Product> _products = [];
  List<WithdrawalHistory> _withdrawalHistory = [];
  String _selectedCategory = 'ทั้งหมด';
  List<String> _categories = ['ทั้งหมด'];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // โหลดข้อมูลสมวดหมู่
      final categoriesData = await SupabaseService.getCategories();
      _categories = ['ทั้งหมด', ...categoriesData];

      // โหลดข้อมูลสินค้า
      final productsData = await SupabaseService.getProducts();
      _products = productsData.map((data) => Product(
        id: data['id'],
        name: data['name'],
        category: data['category'],
        quantity: data['quantity'],
        unit: data['unit'],
        image: 'assets/images/inventory.png',
      )).toList();

      // โหลดประวัติการเบิก
      final historyData = await SupabaseService.getWithdrawalHistory();
      _withdrawalHistory = historyData.map((data) => WithdrawalHistory(
        productName: data['products']['name'],
        quantity: data['quantity'],
        unit: data['products']['unit'],
        note: data['note'] ?? '',
        date: DateTime.parse(data['created_at']).toString().substring(0, 16),
      )).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  

  void _showRequestDialog(Product product) {
    int requestQuantity = 1;
    String note = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('เบิกสินค้า'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2, color: Colors.blue[800]),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'คงเหลือ: ${product.quantity} ${product.unit}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (requestQuantity > 1) {
                            setState(() => requestQuantity--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$requestQuantity ${product.unit}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () {
                          if (requestQuantity < product.quantity) {
                            setState(() => requestQuantity++);
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) => note = value,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ (ถ้ามี)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // แสดง loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      // เบิกสินค้า
                      await SupabaseService.withdrawProduct(
                        productId: product.id,
                        quantity: requestQuantity,
                        note: note.isNotEmpty ? note : null,
                      );

                      // ปิด loading indicator
                      Navigator.pop(context);
                      // ปิด dialog การเบิกสิน��้า
                      Navigator.pop(context);

                      // รีโหลดข้อมูล
                      await _loadData();

                      if (mounted) {
                        // แสดงข้อความแจ้งเตือนสำเร็จ
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เบิก ${product.name} จำนวน $requestQuantity ${product.unit} สำเร็จ'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      // ปิด loading indicator ในกรณีที่เกิดข้อผิดพลาด
                      Navigator.pop(context);
                      // ปิด dialog การเบิกสินค้า
                      Navigator.pop(context);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เกิดข้อผิดพลาด: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('ยืนยันการเบิก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog() {
    String name = '';
    String category;
    int quantity = 0;
    String unit = 'ชิ้น';

    final availableCategories = _categories.where((c) => c != 'ทั้งหมด').toList();
    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มหมวดหมู่ก่อนเพิ่มสินค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    category = availableCategories.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เพิ่มสินค้าใหม่'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => name = value,
                decoration: const InputDecoration(
                  labelText: 'ชื่อสินค้า',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่',
                  border: OutlineInputBorder(),
                ),
                items: availableCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    category = value;
                  }
                },
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) => quantity = int.tryParse(value) ?? 0,
                      decoration: const InputDecoration(
                        labelText: 'จำนวน',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      onChanged: (value) => unit = value,
                      decoration: const InputDecoration(
                        labelText: 'หน่วย',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกชื่อสินค้า'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  Navigator.pop(context);
                  await SupabaseService.addProduct(
                    name: name,
                    category: category,
                    quantity: quantity,
                    unit: unit,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เพิ่มหินค้า "$name" สำเร็จ'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('เพิ่มหินค้า'),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryDialog() {
    String newCategory = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('จัดการหมวดหมู่'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => newCategory = value,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหมวดหมู่ใหม่',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('หมวดหมู่ที่มีอยู่:'),
              const SizedBox(height: 10),
              Container(
                height: 200,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  itemCount: _categories.length - 1, // ไม่รวม "ทั้งหมด"
                  itemBuilder: (context, index) {
                    final category = _categories[index + 1];
                    return ListTile(
                      title: Text(category),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          try {
                            await SupabaseService.deleteCategory(category);
                            await _loadData(); // เพิ่มการโหลดข้อมูลใหม่หลังลบ
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('ลบหมวดหมู่ "$category" สำเร็จ'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('เกิดข้อผิดพลาด: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ปิด',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCategory.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกชื่อหมวดหมู่'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  await SupabaseService.addCategory(newCategory);
                  await _loadData(); // เพิ่มการโหลดข้อมูลใหม่หลังเพิ่ม
                  Navigator.pop(context); // ปิด dialog หลังจากเพิ่มสำเร็จ
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เพิ่มหมวดหมู่ "$newCategory" สำเร็จ'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('เพิ่มหมวดหมู่'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Product> filteredProducts = _selectedCategory == 'ทั้งหมด'
        ? _products
        : _products.where((product) => product.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Header section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'คลังสินค้า',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Row(
                              children: [
                                if (_products.isEmpty)
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        await SupabaseService.initializeDefaultProducts();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('เพิ่มสินค้าเริ่มต้นสำเร็จ'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          _loadData();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('เกิดข้อผิดพลาด: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.playlist_add),
                                    iconSize: 30,
                                    color: Colors.green,
                                    tooltip: 'เพิ่มสินค้าเริ่มต้น',
                                  ),
                                IconButton(
                                  onPressed: _showCategoryDialog,
                                  icon: const Icon(Icons.category),
                                  iconSize: 30,
                                  color: Colors.orange,
                                  tooltip: 'จัดการหมวดหมู่',
                                ),
                                IconButton(
                                  onPressed: _showAddProductDialog,
                                  icon: const Icon(Icons.add_circle_outline),
                                  iconSize: 30,
                                  color: Colors.blue,
                                  tooltip: 'เพิ่มสินค้าใหม่',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Tab Bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.blue,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey[600],
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 16,
                            ),
                            padding: const EdgeInsets.all(5),
                            tabs: [
                              Tab(
                                height: 45,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.inventory_2),
                                    SizedBox(width: 8),
                                    Text('รายการสินค้า'),
                                  ],
                                ),
                              ),
                              Tab(
                                height: 45,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.history),
                                    SizedBox(width: 8),
                                    Text('ประวัติการเบิก'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab Bar View with custom transition
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // รายการสินค้า
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            // Category Filter
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Container(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _categories.length,
                                  itemBuilder: (context, index) {
                                    final category = _categories[index];
                                    final isSelected = category == _selectedCategory;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(category),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() => _selectedCategory = category);
                                        },
                                        backgroundColor: Colors.white,
                                        selectedColor: Colors.blue.withOpacity(0.2),
                                        checkmarkColor: Colors.blue,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.blue : Colors.grey[700],
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: isSelected ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Products List
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: ListView.builder(
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: InkWell(
                                        onTap: () => _showRequestDialog(product),
                                        borderRadius: BorderRadius.circular(15),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Row(
                                            children: [
                                              // Icon Container
                                              Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.inventory_2,
                                                    size: 30,
                                                    color: Colors.blue[800],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              // Product Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      product.category,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Quantity Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${product.quantity} ${product.unit}',
                                                  style: TextStyle(
                                                    color: Colors.blue[800],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              // Delete Button
                                              IconButton(
                                                onPressed: () async {
                                                  // แสดง dialog ยืนยันการลบ
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text('ยืนยันการลบ'),
                                                        content: Text('คุณต้องการลบ "${product.name}" ใช่หรือไม่?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, false),
                                                            child: Text(
                                                              'ยกเลิก',
                                                              style: TextStyle(color: Colors.grey[600]),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, true),
                                                            child: const Text(
                                                              'ลบ',
                                                              style: TextStyle(color: Colors.red),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );

                                                  if (confirmed == true) {
                                                    try {
                                                      // แสดง loading
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (BuildContext context) {
                                                          return const Center(
                                                            child: CircularProgressIndicator(),
                                                          );
                                                        },
                                                      );

                                                      await SupabaseService.deleteProduct(product.id);
                                                      
                                                      // ปิด loading
                                                      Navigator.pop(context);

                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('ลบ "${product.name}" สำเร็จ'),
                                                            backgroundColor: Colors.green,
                                                          ),
                                                        );
                                                        // รีโหลดข้อมูล
                                                        _loadData();
                                                      }
                                                    } catch (e) {
                                                      // ปิด loading
                                                      Navigator.pop(context);
                                                      
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('เกิดข้อผิดพลาด: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                icon: const Icon(Icons.delete_outline),
                                                color: Colors.red,
                                                tooltip: 'ลบสินค้า',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ประวัติการเบิก
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _withdrawalHistory.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ไม่มีประวัติการเบิกสินค้า',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _withdrawalHistory.length,
                                  itemBuilder: (context, index) {
                                    final history = _withdrawalHistory[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(15),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.inventory_2,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    history.productName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'จำนวน: ${history.quantity} ${history.unit}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  if (history.note.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'หมายเหตุ: ${history.note}',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'สำเร็จ',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  history.date,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final String image;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.image,
  });
}

class WithdrawalHistory {
  final String productName;
  final int quantity;
  final String unit;
  final String note;
  final String date;

  WithdrawalHistory({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.note,
    required this.date,
  });
} 