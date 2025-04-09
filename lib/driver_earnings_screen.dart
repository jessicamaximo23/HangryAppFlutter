import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  _DriverEarningsScreenState createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen>
    with SingleTickerProviderStateMixin {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  late TabController _tabController;
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  String _errorMessage = '';

  // Earnings data based on deliveries
  double _totalEarnings = 0.0;
  double _weeklyEarnings = 0.0;
  double _monthlyEarnings = 0.0;
  List<EarningsData> _dailyEarningsData = [];
  List<DeliveryEarning> _completedDeliveries = [];

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

      // Get all assignments for the driver
      final assignmentsSnapshot =
          await _databaseRef.child('users/${_user.uid}/assignments').get();

      if (!assignmentsSnapshot.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final assignmentsData =
          assignmentsSnapshot.value as Map<dynamic, dynamic>;

      // Process assignments and calculate earnings
      double total = 0.0;
      double weekly = 0.0;
      double monthly = 0.0;
      List<DeliveryEarning> deliveries = [];
      Map<String, double> dailyEarnings = {};

      // Get current date info for filtering
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // For each assignment, get the corresponding order details
      await Future.forEach(assignmentsData.entries,
          (MapEntry assignment) async {
        final String orderId = assignment.key;
        final Map<dynamic, dynamic> assignmentData =
            assignment.value as Map<dynamic, dynamic>;

        if (assignmentData['status'] == 'completed') {
          final String restaurantId = assignmentData['restaurantId'] ?? '';
          final String userId = assignmentData['userId'] ?? '';

          // Get order details from restaurant's records
          final orderSnapshot = await _databaseRef
              .child('users/$restaurantId/orders/$orderId')
              .get();

          if (orderSnapshot.exists) {
            final orderData = orderSnapshot.value as Map<dynamic, dynamic>;

            // Get restaurant info
            final restaurantSnapshot =
                await _databaseRef.child('users/$restaurantId').get();

            String restaurantName = 'Unknown Restaurant';
            if (restaurantSnapshot.exists) {
              final restaurantData =
                  restaurantSnapshot.value as Map<dynamic, dynamic>;
              restaurantName = restaurantData['name'] ?? 'Unknown Restaurant';
            }

            // Calculate earning for this delivery (fixed delivery fee)
            double deliveryFee = 3.99; // Default delivery fee
            if (orderData.containsKey('deliveryFee')) {
              try {
                deliveryFee = double.parse(orderData['deliveryFee'].toString());
              } catch (e) {
                // Keep default value if parsing fails
              }
            }

            // Get completion timestamp
            DateTime completionDate;
            try {
              if (assignmentData.containsKey('completedAt')) {
                completionDate = DateTime.fromMillisecondsSinceEpoch(
                    assignmentData['completedAt'] as int);
              } else {
                // Fallback to order date if completion timestamp not available
                completionDate =
                    DateTime.parse(orderData['orderDate'] ?? now.toString());
              }
            } catch (e) {
              completionDate = now; // Fallback to current date
            }

            // Format date
            String formattedDate =
                DateFormat('MMM dd, yyyy').format(completionDate);

            // Add to total earnings
            total += deliveryFee;

            // Check if within current week
            if (completionDate.isAfter(startOfWeek)) {
              weekly += deliveryFee;
            }

            // Check if within current month
            if (completionDate.isAfter(startOfMonth)) {
              monthly += deliveryFee;
            }

            // Get customer name
            String customerName = 'Customer';
            if (userId.isNotEmpty) {
              final userSnapshot =
                  await _databaseRef.child('users/$userId').get();
              if (userSnapshot.exists) {
                final userData = userSnapshot.value as Map<dynamic, dynamic>;
                customerName = userData['name'] ?? 'Customer';
              }
            }

            // Add to completed deliveries list
            deliveries.add(DeliveryEarning(
              id: orderId,
              date: formattedDate,
              amount: deliveryFee,
              customerName: customerName,
              restaurantName: restaurantName,
              rawDate: completionDate,
            ));

            // Add to daily earnings for chart
            String dayKey = DateFormat('yyyy-MM-dd').format(completionDate);
            if (dailyEarnings.containsKey(dayKey)) {
              dailyEarnings[dayKey] = dailyEarnings[dayKey]! + deliveryFee;
            } else {
              dailyEarnings[dayKey] = deliveryFee;
            }
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

      // Sort completed deliveries by date (newest first)
      deliveries.sort((a, b) => b.rawDate.compareTo(a.rawDate));

      // Sort chart data by date
      chartData.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _totalEarnings = total;
        _weeklyEarnings = weekly;
        _monthlyEarnings = monthly;
        _completedDeliveries = deliveries;
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

  List<DeliveryEarning> _getFilteredDeliveries() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);

    switch (_selectedPeriod) {
      case 'This Week':
        return _completedDeliveries
            .where((delivery) => delivery.rawDate
                .isAfter(startOfWeek.subtract(Duration(days: 1))))
            .toList();
      case 'This Month':
        return _completedDeliveries
            .where((delivery) => delivery.rawDate
                .isAfter(startOfMonth.subtract(Duration(days: 1))))
            .toList();
      case 'Last Month':
        return _completedDeliveries
            .where((delivery) =>
                delivery.rawDate
                    .isAfter(startOfLastMonth.subtract(Duration(days: 1))) &&
                delivery.rawDate
                    .isBefore(endOfLastMonth.add(Duration(days: 1))))
            .toList();
      default:
        return _completedDeliveries;
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
        // Calculate last month total from filtered deliveries
        double total = 0.0;
        for (var delivery in _getFilteredDeliveries()) {
          total += delivery.amount;
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
          'My Earnings',
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
            Tab(text: 'Deliveries', icon: Icon(Icons.delivery_dining)),
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

                    // Deliveries Tab
                    _buildDeliveriesTab(),
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
            "\$${filteredTotal.toStringAsFixed(2)}",
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
                  'Deliveries', _getFilteredDeliveries().length.toString()),
              _buildEarningsMetric(
                'Per Delivery',
                _getFilteredDeliveries().isEmpty
                    ? "\$0.00"
                    : "\$${(filteredTotal / _getFilteredDeliveries().length).toStringAsFixed(2)}",
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
              color: Colors.black.withValues(),
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
      // Convert DateTime to x-axis value
      spots.add(FlSpot(i.toDouble(), filteredData[i].amount));
    }

    // Find min and max values for y-axis
    double maxY =
        filteredData.map((data) => data.amount).reduce((a, b) => a > b ? a : b);
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding to top

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
                  horizontalInterval: maxY / 5,
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
                          "\$${value.toInt()}",
                          style: const TextStyle(
                            color: Color(0xff68737d),
                            fontSize: 10,
                          ),
                        );
                      },
                      interval: maxY / 5,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        // Show date labels for x-axis
                        final index = value.toInt();
                        if (index >= 0 && index < filteredData.length) {
                          // Skip some dates to avoid overcrowding
                          if (filteredData.length > 10) {
                            if (index % (filteredData.length ~/ 5) == 0) {
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
                maxX: (filteredData.length - 1).toDouble(),
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
    final filteredDeliveries = _getFilteredDeliveries();
    final filteredTotal = _getFilteredTotal();

    // Calculate average earnings per day for active days
    double avgEarningsPerDay = 0.0;
    if (filteredDeliveries.isNotEmpty) {
      // Get unique days
      Set<String> uniqueDays = <String>{};
      for (var delivery in filteredDeliveries) {
        uniqueDays.add(DateFormat('yyyy-MM-dd').format(delivery.rawDate));
      }

      if (uniqueDays.isNotEmpty) {
        avgEarningsPerDay = filteredTotal / uniqueDays.length;
      }
    }

    // the day with highest earnings
    String bestDay = "None";
    double bestDayAmount = 0.0;

    final filteredChartData = _getFilteredChartData();
    if (filteredChartData.isNotEmpty) {
      final highestEarningData =
          filteredChartData.reduce((a, b) => a.amount > b.amount ? a : b);
      bestDay = DateFormat('EEE, MMM d').format(highestEarningData.date);
      bestDayAmount = highestEarningData.amount;
    }

    return Column(
      children: [
        Container(
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
                'Total Deliveries',
                filteredDeliveries.length.toString(),
                Icons.delivery_dining,
              ),
              Divider(height: 24),
              _buildStatRow(
                'Avg. Per Day',
                avgEarningsPerDay > 0
                    ? "\$${avgEarningsPerDay.toStringAsFixed(2)}"
                    : "\$0.00",
                Icons.calendar_today,
              ),
              Divider(height: 24),
              _buildStatRow(
                'Best Day',
                bestDayAmount > 0
                    ? "$bestDay (\$${bestDayAmount.toStringAsFixed(2)})"
                    : 'None',
                Icons.star,
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Day of Week Analysis
        _buildDayOfWeekAnalysis(filteredDeliveries),
      ],
    );
  }

  Widget _buildDayOfWeekAnalysis(List<DeliveryEarning> deliveries) {
    // Initialize earnings for each day of the week
    Map<int, double> dayEarnings = {
      1: 0.0, // Monday
      2: 0.0, // Tuesday
      3: 0.0, // Wednesday
      4: 0.0, // Thursday
      5: 0.0, // Friday
      6: 0.0, // Saturday
      7: 0.0, // Sunday
    };

    Map<int, int> dayDeliveryCount = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    // Calculate earnings for each day of the week
    for (var delivery in deliveries) {
      // Get day of week (1 = Monday, 7 = Sunday)
      int dayOfWeek = delivery.rawDate.weekday;
      dayEarnings[dayOfWeek] = dayEarnings[dayOfWeek]! + delivery.amount;
      dayDeliveryCount[dayOfWeek] = dayDeliveryCount[dayOfWeek]! + 1;
    }

    // Find the best day of the week
    int bestDayOfWeek = 1;
    double bestDayEarning = 0.0;

    dayEarnings.forEach((day, amount) {
      if (amount > bestDayEarning) {
        bestDayEarning = amount;
        bestDayOfWeek = day;
      }
    });

    // If no deliveries, don't show this section
    if (deliveries.isEmpty) {
      return SizedBox.shrink();
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
            'Day of Week Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 16),

          // Day of week bars
          Column(
            children: dayEarnings.entries.map((entry) {
              // Get day name
              String dayName = _getDayName(entry.key);
              double amount = entry.value;
              int deliveryCount = dayDeliveryCount[entry.key] ?? 0;

              // Calculate percentage relative to the best day
              double percentage =
                  bestDayEarning > 0 ? (amount / bestDayEarning) * 100 : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: entry.key == bestDayOfWeek
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: entry.key == bestDayOfWeek
                                  ? hangryBlue
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                height: 8,
                                width: percentage > 0
                                    ? (MediaQuery.of(context).size.width -
                                            200) *
                                        (percentage / 100)
                                    : 0,
                                decoration: BoxDecoration(
                                  color: entry.key == bestDayOfWeek
                                      ? hangryYellow
                                      : hangryYellow.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "\$${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: entry.key == bestDayOfWeek
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: entry.key == bestDayOfWeek
                                ? hangryBlue
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    if (deliveryCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 90.0, top: 2.0),
                        child: Text(
                          '$deliveryCount ${deliveryCount == 1 ? "delivery" : "deliveries"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          if (bestDayEarning > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${_getDayName(bestDayOfWeek)} is your best earning day!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hangryBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
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

  Widget _buildDeliveriesTab() {
    final filteredDeliveries = _getFilteredDeliveries();

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildPeriodSelector(),
        ),

        // Deliveries list
        Expanded(
          child: filteredDeliveries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No completed deliveries in this period',
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
                    itemCount: filteredDeliveries.length,
                    itemBuilder: (context, index) {
                      return _buildDeliveryCard(filteredDeliveries[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(DeliveryEarning delivery) {
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
                    'Order #${delivery.id.substring(0, math.min(8, delivery.id.length))}...',
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
            Text(
              'From ${delivery.restaurantName}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'To ${delivery.customerName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  delivery.date,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  "\$${delivery.amount.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hangryYellow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Data classes for chart and deliveries
class EarningsData {
  final DateTime date;
  final double amount;

  EarningsData({required this.date, required this.amount});
}

class DeliveryEarning {
  final String id;
  final String date;
  final double amount;
  final String customerName;
  final String restaurantName;
  final DateTime rawDate;

  DeliveryEarning({
    required this.id,
    required this.date,
    required this.amount,
    required this.customerName,
    required this.restaurantName,
    required this.rawDate,
  });
}
