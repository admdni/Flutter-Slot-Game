import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_slotapp/bonus.dart';
import 'package:new_slotapp/classic.dart';
import 'package:new_slotapp/galactic.dart';
import 'package:new_slotapp/leaderboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Bliss Slots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: const SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIfFirstTime();
  }

  Future<void> _checkIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (username != null) {
      _navigateToMainMenu(username);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUsername(String username) async {
    if (username.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username.trim());
    await prefs.setInt('balance', 1000); // Initial coins
    await prefs.setInt('energy', 300); // Initial energy
    await prefs.setInt('lastSpinTime', 0); // For spin cooldown
    _navigateToMainMenu(username.trim());
  }

  void _navigateToMainMenu(String username) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MainMenu(username: username)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C0A37), Color(0xFF1A1A2E), Color(0xFF0A0A1F)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.casino,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'COSMIC\BLISS SLOT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your username to start playing',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Username',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _saveUsername(_nameController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'START PLAYING',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainMenu extends StatefulWidget {
  final String username;
  const MainMenu({Key? key, required this.username}) : super(key: key);

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  late SharedPreferences prefs;
  int _balance = 1000;
  int _energy = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _balance = prefs.getInt('balance') ?? 1000;
      _energy = prefs.getInt('energy') ?? 300;
      _isLoading = false;
    });
  }

  void _updateBalance(int newBalance) {
    setState(() {
      _balance = newBalance;
      prefs.setInt('balance', newBalance);
    });
  }

  Future<void> _updateEnergy(int earned) async {
    setState(() {
      _energy += earned;
    });
    await prefs.setInt('energy', _energy);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You earned $earned energy!')),
    );
  }

  Future<void> _checkEnergy(VoidCallback onSuccess) async {
    if (_energy >= 5) {
      setState(() {
        _energy -= 5;
      });
      await prefs.setInt('energy', _energy);
      onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough energy! Spin the wheel to earn more.'),
        ),
      );
    }
  }

  Widget _buildGameMode(String title, String subtitle, Color color,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () => _checkEnergy(onTap),
      child: Container(
        width: 235,
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  icon,
                  size: 120,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PLAY NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.play_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.energy_savings_leaf,
                              color: Colors.purple,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '5',
                              style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C0A37), Color(0xFF1A1A2E), Color(0xFF0A0A1F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.amber.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.casino,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'COSMIC BLISS SLOT',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        SpinWheel(onEnergyEarned: _updateEnergy),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.energy_savings_leaf,
                                color: Colors.purple,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _energy.toString(),
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _balance.toString(),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LeaderboardScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.leaderboard,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGameMode(
                          'Classic ',
                          'Traditional slot  with cosmic symbols',
                          Colors.purple,
                          Icons.auto_awesome,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CosmicAdventure(
                                  username: widget.username,
                                  initialPoints: _balance,
                                  onCoinsUpdated: _updateBalance,
                                  currentCoins: _balance,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildGameMode(
                          'Galactic ',
                          'Increasing rewards with each spin',
                          Colors.blue,
                          Icons.trending_up,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameScreen(),
                              ),
                            );
                          },
                        ),
                        _buildGameMode(
                          'Bonus ',
                          'Bonus game',
                          Colors.teal,
                          Icons.diamond,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CosmicDash(
                                  initialBalance: _balance,
                                  onBalanceUpdated: _updateBalance,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpinWheel extends StatefulWidget {
  final Function(int) onEnergyEarned;
  const SpinWheel({Key? key, required this.onEnergyEarned}) : super(key: key);

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  Animation<double>? _spinAnimation;

  bool _isSpinning = false;
  int _lastSpinTime = 0;
  Timer? _cooldownTimer;
  String _cooldownText = '';

  @override
  void initState() {
    super.initState();
    _loadLastSpinTime();
    _spinController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
        });
        _awardEnergy();
      }
    });

    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final timePassed = now - _lastSpinTime;
      final timeRemaining = 1800000 - timePassed; // 30 minutes in milliseconds

      if (timeRemaining <= 0) {
        setState(() {
          _cooldownText = '';
        });
        _cooldownTimer?.cancel();
      } else {
        final remainingMinutes = (timeRemaining / 60000).ceil();
        setState(() {
          _cooldownText = '$remainingMinutes min';
        });
      }
    });
  }

  Future<void> _loadLastSpinTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSpinTime = prefs.getInt('lastSpinTime') ?? 0;
    });
  }

  Future<void> _saveLastSpinTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('lastSpinTime', now);
    setState(() {
      _lastSpinTime = now;
    });
  }

  bool get _canSpin {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - _lastSpinTime >= 1800000; // 30 minutes cooldown
  }

  void _spin() {
    if (!_canSpin) {
      final remaining =
          (1800000 - (DateTime.now().millisecondsSinceEpoch - _lastSpinTime)) ~/
              60000;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Please wait $remaining minutes before spinning again')),
      );
      return;
    }

    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    final random = Random();
    final spins = 5 + random.nextDouble() * 5;

    _spinAnimation = Tween<double>(
      begin: 0,
      end: spins * 2 * pi,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    ));

    _spinController.reset();
    _spinController.forward();

    _saveLastSpinTime();
  }

  void _awardEnergy() {
    final random = Random();
    final energyEarned =
        5 + random.nextInt(6); // Random energy between 5 and 10
    widget.onEnergyEarned(energyEarned);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _spin,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.amber.withOpacity(0.2),
          border: Border.all(
            color: Colors.amber,
            width: 2,
          ),
        ),
        child: AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _spinAnimation?.value ?? 0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.energy_savings_leaf,
                    color: Colors.amber,
                    size: 40,
                  ),
                  if (!_isSpinning && !_canSpin)
                    Container(
                      color: Colors.black54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Colors.white,
                            size: 20,
                          ),
                          if (_cooldownText.isNotEmpty)
                            Text(
                              _cooldownText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
