import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class RestaurantEarningsScreen extends StatefulWidget {
  const RestaurantEarningsScreen({Key? key}) : super(key: key);

  @override
  _RestaurantEarningsScreenState createState() =>
      _RestaurantEarningsScreenState();
}

class _RestaurantEarningsScreenState extends State<RestaurantEarningsScreen>
    with SingleTickerProviderStateMixin {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  late TabController _tabController;
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  String _errorMessage = '';

  // Earnings data based on orders
  double _totalEarnings = 0.0;
  double _weeklyEarnings = 0.0;
  double _monthlyEarnings = 0.0;
  List<EarningsData> _dailyEarningsData = [];
  List<OrderEarning> _completedOrders = [];

  // Filter
  String _selectedPeriod = 'All Time';
  final List<String> _periodOptions = [
    'All Time',
    'This Week',
    'This Month',
    'Last Month'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEarningsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchEarningsData() async {
    if (_user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get all orders for the restaurant
      final ordersSnapshot =
          await _databaseRef.child('users/${_user!.uid}/orders').get();

      if (!ordersSnapshot.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>;

      // Process orders and calculate gains
      double total = 0.0;
      double weekly = 0.0;
      double monthly = 0.0;
      List<OrderEarning> orders = [];
      Map<String, double> dailyEarnings = {};

      // Get current date info for filtering
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      ordersData.forEach((orderId, orderData) {
        if (orderData is Map &&
            (orderData['status'] == 'delivered' ||
                orderData['status'] == 'completed')) {
          // gather order data
          double orderTotal = 0.0;
          try {
            orderTotal = double.parse(orderData['total'].toString());
          } catch (e) {
            orderTotal = 0.0;
          }

          // Parse order date
          DateTime orderDate;
          try {
            orderDate = DateTime.parse(orderData['orderDate']);
          } catch (e) {
            orderDate =
                now; // Fallback to current date in case that does not work
          }

          // Format date
          String formattedDate = DateFormat('MMM dd, yyyy').format(orderDate);

          // Add to total earnings
          total += orderTotal;

          // Check if within current week
          if (orderDate.isAfter(startOfWeek)) {
            weekly += orderTotal;
          }

          // Check if within current month
          if (orderDate.isAfter(startOfMonth)) {
            monthly += orderTotal;
          }

          // Add to completed orders list
          orders.add(OrderEarning(
            id: orderId,
            date: formattedDate,
            amount: orderTotal,
            customerName: orderData['userName'] ?? 'Customer',
            rawDate: orderDate,
          ));

          // Add to daily earnings for chart
          String dayKey = DateFormat('yyyy-MM-dd').format(orderDate);
          if (dailyEarnings.containsKey(dayKey)) {
            dailyEarnings[dayKey] = dailyEarnings[dayKey]! + orderTotal;
          } else {
            dailyEarnings[dayKey] = orderTotal;
          }
        }
      });

      // Convert daily earnings to list for chart
      List<EarningsData> chartData = [];
      dailyEarnings.forEach((day, amount) {
        chartData.add(EarningsData(
          date: DateTime.parse(day),
          amount: amount,
        ));
      });

      // Sort completed orders by date (newest first)
      orders.sort((a, b) => b.rawDate.compareTo(a.rawDate));

      // Sort chart data by date
      chartData.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _totalEarnings = total;
        _weeklyEarnings = weekly;
        _monthlyEarnings = monthly;
        _completedOrders = orders;
        _dailyEarningsData = chartData;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching earnings data: $error');
    }
  }

  List<OrderEarning> _getFilteredOrders() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);

    switch (_selectedPeriod) {
      case 'This Week':
        return _completedOrders
            .where((order) =>
                order.rawDate.isAfter(startOfWeek.subtract(Duration(days: 1))))
            .toList();
      case 'This Month':
        return _completedOrders
            .where((order) =>
                order.rawDate.isAfter(startOfMonth.subtract(Duration(days: 1))))
            .toList();
      case 'Last Month':
        return _completedOrders
            .where((order) =>
                order.rawDate
                    .isAfter(startOfLastMonth.subtract(Duration(days: 1))) &&
                order.rawDate.isBefore(endOfLastMonth.add(Duration(days: 1))))
            .toList();
      default:
        return _completedOrders;
    }
  }

  List<EarningsData> _getFilteredChartData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);

    switch (_selectedPeriod) {
      case 'This Week':
        return _dailyEarningsData
            .where((data) =>
                data.date.isAfter(startOfWeek.subtract(Duration(days: 1))))
            .toList();
      case 'This Month':
        return _dailyEarningsData
            .where((data) =>
                data.date.isAfter(startOfMonth.subtract(Duration(days: 1))))
            .toList();
      case 'Last Month':
        return _dailyEarningsData
            .where((data) =>
                data.date
                    .isAfter(startOfLastMonth.subtract(Duration(days: 1))) &&
                data.date.isBefore(endOfLastMonth.add(Duration(days: 1))))
            .toList();
      default:
        return _dailyEarningsData;
    }
  }

  double _getFilteredTotal() {
    switch (_selectedPeriod) {
      case 'This Week':
        return _weeklyEarnings;
      case 'This Month':
        return _monthlyEarnings;
      case 'Last Month':
        // Calculate last month total from filtered orders
        double total = 0.0;
        for (var order in _getFilteredOrders()) {
          total += order.amount;
        }
        return total;
      default:
        return _totalEarnings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Earnings',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: hangryBlue,
          labelColor: hangryBlue,
          unselectedLabelColor: Colors.black54,
          tabs: [
            Tab(text: 'Overview', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Orders', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Overview Tab
                    _buildOverviewTab(),

                    // Orders Tab
                    _buildOrdersTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchEarningsData,
        backgroundColor: hangryYellow,
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading earnings data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(_errorMessage),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchEarningsData,
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _fetchEarningsData,
      color: hangryYellow,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _buildPeriodSelector(),
            SizedBox(height: 16),

            // Earnings summary card
            _buildEarningsSummaryCard(),
            SizedBox(height: 24),

            // Earnings chart
            _buildEarningsChart(),
            SizedBox(height: 24),

            // Stats and metrics
            _buildStatsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: hangryBlue),
          items: _periodOptions.map((String period) {
            return DropdownMenuItem<String>(
              value: period,
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: hangryBlue,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedPeriod = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildEarningsSummaryCard() {
    final filteredTotal = _getFilteredTotal();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hangryBlue, Color(0xFF004D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedPeriod,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '\$${filteredTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEarningsMetric(
                  'Orders', _getFilteredOrders().length.toString()),
              _buildEarningsMetric(
                'Avg. Order',
                _getFilteredOrders().isEmpty
                    ? '\$0.00'
                    : '\$${(filteredTotal / _getFilteredOrders().length).toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsChart() {
    final filteredData = _getFilteredChartData();

    if (filteredData.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No earnings data available for this period',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Prepare data for line chart
    List<FlSpot> spots = [];
    for (int i = 0; i < filteredData.length; i++) {
      // Convert DateTime to x-axis value (using index for simplicity)
      spots.add(FlSpot(i.toDouble(), filteredData[i].amount));
    }

    // Find min and max values for y-axis
    double maxY = filteredData.isEmpty
        ? 100 // Default value if no data
        : filteredData
            .map((data) => data.amount)
            .reduce((a, b) => a > b ? a : b);

    // Add padding and ensure it's at least 10
    maxY = Math.max((maxY * 1.2).ceilToDouble(), 10.0);

    // Calculate safe intervals that can't be zero
    double horizontalInterval = Math.max(maxY / 4, 1.0);
    double leftTitleInterval = Math.max(maxY / 4, 1.0);

    return Container(
      height: 250,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval, // Safe value
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(
                            color: Color(0xff68737d),
                            fontSize: 10,
                          ),
                        );
                      },
                      interval: leftTitleInterval, // Safe value
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1, // Safe default interval for x-axis
                      getTitlesWidget: (value, meta) {
                        // Show date labels for x-axis
                        final index = value.toInt();
                        if (index >= 0 && index < filteredData.length) {
                          // Skip some dates to avoid overcrowding
                          if (filteredData.length > 10) {
                            if (index %
                                    Math.max((filteredData.length ~/ 5), 1) ==
                                0) {
                              return Text(
                                DateFormat('MM/dd')
                                    .format(filteredData[index].date),
                                style: const TextStyle(
                                  color: Color(0xff68737d),
                                  fontSize: 10,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat('MM/dd')
                                .format(filteredData[index].date),
                            style: const TextStyle(
                              color: Color(0xff68737d),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                minX: 0,
                maxX: Math.max((filteredData.length - 1).toDouble(), 0),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: hangryYellow,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: hangryYellow.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final filteredOrders = _getFilteredOrders();
    final filteredTotal = _getFilteredTotal();

    // Find the highest value order
    OrderEarning? highestOrder;
    if (filteredOrders.isNotEmpty) {
      highestOrder =
          filteredOrders.reduce((a, b) => a.amount > b.amount ? a : b);
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 16),
          _buildStatRow(
            'Total Orders',
            filteredOrders.length.toString(),
            Icons.receipt_long,
          ),
          Divider(height: 24),
          _buildStatRow(
            'Average Order',
            filteredOrders.isEmpty
                ? '\$0.00'
                : '\$${(filteredTotal / filteredOrders.length).toStringAsFixed(2)}',
            Icons.calculate,
          ),
          Divider(height: 24),
          _buildStatRow(
            'Highest Order',
            highestOrder != null
                ? '\$${highestOrder.amount.toStringAsFixed(2)}'
                : '\$0.00',
            Icons.arrow_upward,
          ),
          if (highestOrder != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Text(
                'From ${highestOrder.customerName} on ${highestOrder.date}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hangryYellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: hangryYellow,
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: hangryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    final filteredOrders = _getFilteredOrders();

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildPeriodSelector(),
        ),

        // Orders list
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No completed orders in this period',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchEarningsData,
                  color: hangryYellow,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(filteredOrders[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderEarning order) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.id.substring(0, Math.min(8, order.id.length))}...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: hangryBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.date,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  '\$${order.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hangryYellow,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Customer: ${order.customerName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data classes for chart and orders
class EarningsData {
  final DateTime date;
  final double amount;

  EarningsData({required this.date, required this.amount});
}

class OrderEarning {
  final String id;
  final String date;
  final double amount;
  final String customerName;
  final DateTime rawDate;

  OrderEarning({
    required this.id,
    required this.date,
    required this.amount,
    required this.customerName,
    required this.rawDate,
  });
}
