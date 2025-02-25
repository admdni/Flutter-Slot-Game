import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_slotapp/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Bliss Slot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0B0B2E),
      ),
      home: const GameWrapper(),
    );
  }
}

class GameWrapper extends StatefulWidget {
  const GameWrapper({Key? key}) : super(key: key);

  @override
  _GameWrapperState createState() => _GameWrapperState();
}

class _GameWrapperState extends State<GameWrapper> {
  late SharedPreferences prefs;
  String username = '';
  int highscore = 0;
  int energy = 300;
  int lastSpinTime = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      highscore = prefs.getInt('highscore') ?? 1000;
      energy = prefs.getInt('energy') ?? 300;
      lastSpinTime = prefs.getInt('lastSpinTime') ?? 0;
    });
    _navigateToMainMenu();
  }

  void _navigateToMainMenu() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CosmicAdventure(
          initialPoints: highscore,
          username: username,
          onCoinsUpdated: _updateHighscore,
          currentCoins: highscore,
        ),
      ),
    );
  }

  void _updateHighscore(int newCoins) {
    setState(() {
      highscore = newCoins;
      prefs.setInt('highscore', highscore);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.deepPurple,
        ),
      ),
    );
  }
}

class CosmicAdventure extends StatefulWidget {
  final int initialPoints;
  final String username;
  final Function(int newCoins) onCoinsUpdated;

  const CosmicAdventure({
    Key? key,
    required this.initialPoints,
    required this.username,
    required this.onCoinsUpdated,
    required int currentCoins,
  }) : super(key: key);

  @override
  _CosmicAdventureState createState() => _CosmicAdventureState();
}

class _CosmicAdventureState extends State<CosmicAdventure>
    with TickerProviderStateMixin {
  late List<List<GameSymbol>> _reels;
  late List<AnimationController> _reelControllers;
  int _points = 0;
  int _lastScore = 0;
  bool _isSpinning = false;
  int _consecutiveMatches = 0;
  double _multiplier = 1.0;
  Timer? _autoSpinTimer;
  bool _isAutoSpinEnabled = false;

  List<Color> _currentGradientColors = [
    Colors.deepPurple.shade900,
    Colors.black
  ];

  late AnimationController _winScreenController;
  late Animation<Offset> _winScreenSlideAnimation;
  bool _showWinScreen = false;

  bool _showPaylines = false;

  @override
  void initState() {
    super.initState();
    _points = widget.initialPoints;
    _initializeGame();
    _setupWinScreenAnimation();
  }

  void _initializeGame() {
    _reels = List.generate(
      5,
      (_) => List.generate(3, (_) => _generateRandomSymbol()),
    );
    _reelControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 200)),
        vsync: this,
      ),
    );
  }

  void _setupWinScreenAnimation() {
    _winScreenController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _winScreenSlideAnimation = Tween(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _winScreenController,
      curve: Curves.easeOutBack,
    ));
  }

  GameSymbol _generateRandomSymbol() {
    final random = Random();
    final symbolIndex = random.nextInt(GameSymbols.all.length);
    return GameSymbols.all[symbolIndex];
  }

  Future<void> _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _currentGradientColors = [
        Colors.primaries[Random().nextInt(Colors.primaries.length)],
        Colors.primaries[Random().nextInt(Colors.primaries.length)],
      ];
    });

    for (int i = 0; i < _reelControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: 200 * i));
      _reelControllers[i].forward(from: 0.0);
      setState(() {
        _reels[i] = List.generate(3, (_) => _generateRandomSymbol());
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _evaluateMatch();
  }

  void _evaluateMatch() {
    int totalScore = 0;
    List<List<bool>> matchingPositions = List.generate(
      5,
      (_) => List.generate(3, (_) => false),
    );

    for (final payline in Paylines.all) {
      totalScore += _evaluatePayline(payline, matchingPositions);
    }

    totalScore = (totalScore * _multiplier).round();

    if (totalScore > 0) {
      _handleMatch(totalScore);
    } else {
      _handleNoMatch();
    }

    setState(() {
      _lastScore = totalScore;
      _points += totalScore;
      _isSpinning = false; // Spin durumunu burada güncelle
      widget.onCoinsUpdated(_points);
    });

    // Skoru API'ye gönder - async olarak arka planda çalışsın
    if (totalScore > 0) {
      ApiService().updateScore(widget.username, _points).then((_) {
        if (mounted) {}
      }).catchError((error) {
        print('Failed to update score: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  int _evaluatePayline(List<int> payline, List<List<bool>> matchingPositions) {
    List<GameSymbol> lineSymbols = [];
    for (int i = 0; i < payline.length; i++) {
      lineSymbols.add(_reels[i][payline[i]]);
    }

    Map<String, int> symbolCount = {};
    GameSymbol? mostFrequent;
    int maxCount = 0;

    for (var symbol in lineSymbols) {
      symbolCount[symbol.name] = (symbolCount[symbol.name] ?? 0) + 1;
      if (symbolCount[symbol.name]! > maxCount) {
        maxCount = symbolCount[symbol.name]!;
        mostFrequent = symbol;
      }
    }

    if (maxCount >= 3 && mostFrequent != null) {
      for (int i = 0; i < payline.length; i++) {
        if (lineSymbols[i].name == mostFrequent.name) {
          matchingPositions[i][payline[i]] = true;
        }
      }
      return mostFrequent.value * maxCount;
    }
    return 0;
  }

  void _handleMatch(int scoreAmount) {
    _consecutiveMatches++;
    _multiplier = min(3.0, 1.0 + (_consecutiveMatches * 0.2));

    setState(() {
      _showWinScreen = true;
      _showPaylines = true;
    });

    _winScreenController.forward(from: 0.0);
    _checkBonusFeatures();
  }

  void _handleNoMatch() {
    _consecutiveMatches = 0;
    _multiplier = 1.0;
    setState(() {
      _showPaylines = false;
    });
  }

  void _checkBonusFeatures() {
    int specialSymbols = 0;
    for (var reel in _reels) {
      for (var symbol in reel) {
        if (symbol.isSpecial) specialSymbols++;
      }
    }

    if (specialSymbols >= 3) {
      setState(() {
        _points += 1000; // Bonus points
        _multiplier *= 2;
      });
    }
  }

  void _toggleAutoSpin() {
    setState(() {
      if (_autoSpinTimer == null) {
        _startAutoSpin();
      } else {
        _stopAutoSpin();
      }
    });
  }

  void _startAutoSpin() {
    if (!_isSpinning) {
      _spin();
      _autoSpinTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) {
          if (!_isSpinning) {
            _spin();
          } else {
            _stopAutoSpin();
          }
        },
      );
    }
  }

  void _stopAutoSpin() {
    _autoSpinTimer?.cancel();
    _autoSpinTimer = null;
    setState(() {
      _isAutoSpinEnabled = false;
    });
  }

  void _closeWinScreen() {
    _winScreenController.reverse().then((_) {
      setState(() {
        _showWinScreen = false;
      });
    });
  }

  void _navigateToMainMenu() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _currentGradientColors,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildSlotMachine()),
                  _buildControlBar(),
                ],
              ),
            ),
          ),
          if (_showWinScreen)
            SlideTransition(
              position: _winScreenSlideAnimation,
              child: _buildWinScreen(),
            ),
        ],
      ),
    );
  }

  Widget _buildWinScreen() {
    return Align(
      alignment: Alignment.center,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.purple.shade800.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉 MATCH FOUND! 🎉',
                style: GoogleFonts.rubik(
                  color: Colors.amber,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Score: $_lastScore',
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Multiplier: ${_multiplier.toStringAsFixed(1)}x',
                style: GoogleFonts.rubik(
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _closeWinScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _navigateToMainMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: Text(
                  'Main Menu',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.purple.shade700,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPointsDisplay(),
          _buildMultiplierDisplay(),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('How to Play'),
                  content: Text(
                    'Spin the reels and match symbols across paylines to win points.\n\n'
                    'Boost: Increases multiplier.\n'
                    'Auto: Automatically spins the reels.\n'
                    'Lines: Shows winning lines.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPointsDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
            '$_points',
            style: GoogleFonts.rubik(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
            '${_multiplier.toStringAsFixed(1)}x',
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReel(int reelIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 4,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (symbolIndex) => Expanded(
                child: AnimatedBuilder(
                  animation: _reelControllers[reelIndex],
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _reels[reelIndex][symbolIndex].isHighlighted
                            ? Colors.purple.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.asset(
                          _reels[reelIndex][symbolIndex].imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotMachine() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.shade700, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                flex: 100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Expanded(child: _buildReel(index)),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildControlBar(),
              ),
            ],
          ),
        ),
        if (_showPaylines)
          ...Paylines.all.map((payline) {
            return CustomPaint(
              painter: PaylinePainter(payline),
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.6),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.purple.shade700,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('Boost', () {
            setState(() {
              _multiplier *= 1.5;
            });
          }),
          _buildSpinButton(),
          _buildActionButton('Auto', _toggleAutoSpin),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.purple.shade700,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    bool canSpin = !_isSpinning;
    return GestureDetector(
      onTap: canSpin ? _spin : null,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              canSpin ? Colors.purple : Colors.grey,
              canSpin ? Colors.blue : Colors.grey.shade700,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow,
          color: canSpin ? Colors.white : Colors.grey.shade300,
          size: 50,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _reelControllers) {
      controller.dispose();
    }
    _winScreenController.dispose();
    _autoSpinTimer?.cancel();
    super.dispose();
  }
}

class PaylinePainter extends CustomPainter {
  final List<int> payline;

  PaylinePainter(this.payline);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    final reelWidth = size.width / 5;
    final reelHeight = size.height / 3;

    Offset startPoint = Offset(reelWidth / 2, reelHeight * (payline[0] + 1));
    path.moveTo(startPoint.dx, startPoint.dy);

    for (int i = 1; i < payline.length; i++) {
      final nextPoint =
          Offset(reelWidth * (i + 0.5), reelHeight * (payline[i] + 1));
      path.lineTo(nextPoint.dx, nextPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class GameSymbol {
  final String name;
  final String imagePath;
  final int value;
  final bool isSpecial;
  final Color color;
  bool isHighlighted;

  GameSymbol({
    required this.name,
    required this.imagePath,
    required this.value,
    this.isSpecial = false,
    required this.color,
    this.isHighlighted = false,
  });
}

class GameSymbols {
  static final List<GameSymbol> all = [
    GameSymbol(
      name: 'Supernova',
      imagePath: 'assets/symbols/supernova.png',
      value: 2000,
      isSpecial: true,
      color: Colors.yellow,
    ),
    GameSymbol(
      name: 'Black Hole',
      imagePath: 'assets/symbols/black_hole.png',
      value: 1500,
      isSpecial: true,
      color: Colors.purple,
    ),
    GameSymbol(
      name: 'Nebula',
      imagePath: 'assets/symbols/nebula.png',
      value: 1200,
      isSpecial: true,
      color: Colors.pink,
    ),
    GameSymbol(
      name: 'Saturn',
      imagePath: 'assets/symbols/saturn.png',
      value: 500,
      color: Colors.orange,
    ),
    GameSymbol(
      name: 'Jupiter',
      imagePath: 'assets/symbols/jupiter.png',
      value: 400,
      color: Colors.red,
    ),
    GameSymbol(
      name: 'Mars',
      imagePath: 'assets/symbols/mars.png',
      value: 300,
      color: Colors.deepOrange,
    ),
    GameSymbol(
      name: 'Earth',
      imagePath: 'assets/symbols/earth.png',
      value: 250,
      color: Colors.blue,
    ),
    GameSymbol(
      name: 'Venus',
      imagePath: 'assets/symbols/venus.png',
      value: 200,
      color: Colors.amber,
    ),
    GameSymbol(
      name: 'Mercury',
      imagePath: 'assets/symbols/mercury.png',
      value: 150,
      color: Colors.grey,
    ),
    GameSymbol(
      name: 'Moon',
      imagePath: 'assets/symbols/moon.png',
      value: 100,
      color: Colors.white,
    ),
  ];
}

class Paylines {
  static const List<List<int>> all = [
    [1, 1, 1, 1, 1], // Middle line
    [0, 0, 0, 0, 0], // Top line
    [2, 2, 2, 2, 2], // Bottom line
    [0, 1, 2, 1, 0], // V shape
    [2, 1, 0, 1, 2], // Inverted V
    [1, 0, 0, 0, 1], // Top zigzag
    [1, 2, 2, 2, 1], // Bottom zigzag
    [0, 0, 1, 2, 2], // Diagonal top-left
    [2, 2, 1, 0, 0], // Diagonal bottom-left
    [1, 0, 1, 2, 1], // Diamond shape
  ];
}
