import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:new_slotapp/leaderboard.dart';
import 'package:new_slotapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://appledeveloper.com.tr/cosmic/app.php';

  Future<void> updateScore(String username, int score) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateScore',
          'username': username,
          'score': score,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update score');
      }

      final data = json.decode(response.body);
      if (!data['success']) {
        throw Exception(data['message']);
      }
    } catch (e) {
      print('Error updating score: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'getLeaderboard'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get leaderboard');
      }

      final data = json.decode(response.body);
      if (!data['success']) {
        throw Exception(data['message']);
      }

      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      print('Error getting leaderboard: $e');
      rethrow;
    }
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late SharedPreferences prefs;
  final ApiService apiService = ApiService();

  List<GameSymbol> reels = List.generate(3, (_) => GameSymbols.all[0]);
  List<AnimationController> controllers = [];
  List<Animation<double>> animations = [];

  int balance = 1000;
  int bet = 100;
  int totalWins = 0;
  bool isSpinning = false;
  double multiplier = 1.0;
  int consecutiveWins = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      balance = prefs.getInt('balance') ?? 1000;
      totalWins = prefs.getInt('totalWins') ?? 0;
    });
  }

  void _saveData() {
    prefs.setInt('balance', balance);
    prefs.setInt('totalWins', totalWins);
  }

  void _initializeGame() {
    controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 200)),
        vsync: this,
      ),
    );

    animations = controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      );
    }).toList();
  }

  Future<void> spin() async {
    if (isSpinning || balance < bet) return;

    setState(() {
      isSpinning = true;
      balance -= bet;
    });

    List<GameSymbol> newSymbols = List.generate(
      3,
      (_) => GameSymbols.all[Random().nextInt(GameSymbols.all.length)],
    );

    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 200 * i));
      controllers[i].forward(from: 0.0);

      setState(() {
        reels[i] = newSymbols[i];
      });
    }

    await Future.delayed(Duration(milliseconds: 2600));
    _checkWin();
  }

  void _checkWin() {
    // Yeni kazanma kontrol mantığı
    Map<String, int> symbolCount = {};
    int maxValue = 0;

    // Sembolleri say ve en yüksek değerli sembolü bul
    for (GameSymbol symbol in reels) {
      symbolCount[symbol.name] = (symbolCount[symbol.name] ?? 0) + 1;
      if (symbol.value > maxValue) {
        maxValue = symbol.value;
      }
    }

    // En çok tekrar eden sembol sayısını bul
    int maxCount = symbolCount.values.reduce(max);

    bool isWin = false;
    int winAmount = 0;

    // Kazanma koşulları
    if (maxCount == 3) {
      // 3'lü eşleşme - tam ödül
      GameSymbol winningSymbol =
          reels[0]; // Hepsi aynı olduğu için herhangi biri
      winAmount = (winningSymbol.value * bet * multiplier).round();
      isWin = true;
    } else if (maxCount == 2) {
      // 2'li eşleşme - sembol değerinin %40'ı
      int symbolValue =
          reels.firstWhere((symbol) => symbolCount[symbol.name] == 2).value;
      winAmount = (symbolValue * 0.4 * bet * multiplier).round();
      isWin = true;
    }

    if (isWin) {
      setState(() {
        balance += winAmount;
        totalWins += winAmount;
        consecutiveWins++;
        multiplier = min(5.0, 1.0 + (consecutiveWins * 0.5));
        _showWinDialog(winAmount);
      });

      apiService.updateScore('player', totalWins);
    } else {
      setState(() {
        consecutiveWins = 0;
        multiplier = 1.0;
      });
    }

    _saveData();
    setState(() {
      isSpinning = false;
    });
  }

  void _showWinDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WinDialog(
        amount: amount,
        multiplier: multiplier,
        onContinue: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool? shouldExit = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.purple.shade900,
            title: Text('Exit Game?', style: TextStyle(color: Colors.white)),
            content: Text('Your progress will be saved.',
                style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Stay', style: TextStyle(color: Colors.amber)),
              ),
              TextButton(
                onPressed: () {
                  _saveData();
                  Navigator.pop(context, true);
                },
                child: Text('Exit', style: TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        );

        if (shouldExit ?? false) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => MainMenu(
                      username: '',
                    )),
          );
        }
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/space.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildSlotMachine()),
                _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.9),
            Colors.deepPurple.shade700.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBalanceDisplay(),
          _buildMultiplierDisplay(),
          _buildBetControls(),
        ],
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.orange.shade900],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on, color: Colors.white),
          SizedBox(width: 8),
          Text(
            '$balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.deepPurple.shade700],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            '${multiplier.toStringAsFixed(1)}x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade300),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle, color: Colors.white),
            onPressed: !isSpinning
                ? () {
                    setState(() {
                      if (bet > 100) bet -= 100;
                    });
                  }
                : null,
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade900,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$bet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: Colors.white),
            onPressed: !isSpinning
                ? () {
                    setState(() {
                      if (bet < 1000) bet += 100;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSlotMachine() {
    return Container(
      margin: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.purple.shade300, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.purple.shade900,
                Colors.deepPurple.shade700,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) => _buildReel(index)),
          ),
        ),
      ),
    );
  }

  Widget _buildReel(int index) {
    return Expanded(
      child: AnimatedBuilder(
        animation: animations[index],
        builder: (context, child) {
          return Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.shade300.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: _buildSymbol(reels[index]),
          );
        },
      ),
    );
  }

  Widget _buildSymbol(GameSymbol symbol) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: symbol.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: symbol.color.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: symbol.color.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(
        symbol.imagePath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            'MENU',
            Icons.menu,
            Colors.blue,
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => MainMenu(
                        username: '',
                      )),
            ),
          ),
          _buildSpinButton(),
          _buildControlButton(
            'STATS',
            Icons.bar_chart,
            Colors.green,
            () => _showStatsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.7), color.withOpacity(0.4)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    bool canSpin = !isSpinning && balance >= bet;

    return GestureDetector(
      onTap: canSpin ? spin : null,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: canSpin
                ? [Colors.purple.shade400, Colors.deepPurple.shade700]
                : [Colors.grey.shade800, Colors.grey.shade900],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (canSpin ? Colors.purple : Colors.grey).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 60,
        ),
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple.shade900,
        title: Text('Statistics', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Wins: $totalWins',
                style: TextStyle(color: Colors.white)),
            Text('Current Streak: $consecutiveWins',
                style: TextStyle(color: Colors.white)),
            Text('Current Multiplier: ${multiplier.toStringAsFixed(1)}x',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class WinDialog extends StatelessWidget {
  final int amount;
  final double multiplier;
  final VoidCallback onContinue;

  const WinDialog({
    Key? key,
    required this.amount,
    required this.multiplier,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade900,
              Colors.deepPurple.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉 BIG WIN! 🎉',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              '+$amount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Multiplier: ${multiplier.toStringAsFixed(1)}x',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'CONTINUE',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameSymbol {
  final String name;
  final String imagePath;
  final int value;
  final bool isSpecial;
  final Color color;

  const GameSymbol({
    required this.name,
    required this.imagePath,
    required this.value,
    this.isSpecial = false,
    required this.color,
  });
}

class GameSymbols {
  static const List<GameSymbol> all = [
    GameSymbol(
      name: 'Supernova',
      imagePath: 'assets/symbols/supernova.png',
      value: 2500,
      isSpecial: true,
      color: Colors.amber,
    ),
    GameSymbol(
      name: 'BlackHole',
      imagePath: 'assets/symbols/black_hole.png',
      value: 2000,
      isSpecial: true,
      color: Colors.purple,
    ),
    GameSymbol(
      name: 'Nebula',
      imagePath: 'assets/symbols/nebula.png',
      value: 1500,
      isSpecial: true,
      color: Colors.pink,
    ),
    GameSymbol(
      name: 'Galaxy',
      imagePath: 'assets/symbols/galaxy.png',
      value: 1000,
      color: Colors.blue,
    ),
    GameSymbol(
      name: 'Star',
      imagePath: 'assets/symbols/star.png',
      value: 500,
      color: Colors.yellow,
    ),
  ];
}
