import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CosmicDash extends StatefulWidget {
  final int initialBalance;
  final Function(int) onBalanceUpdated;

  const CosmicDash({
    Key? key,
    required this.initialBalance,
    required this.onBalanceUpdated,
  }) : super(key: key);

  @override
  _CosmicDashState createState() => _CosmicDashState();
}

class _CosmicDashState extends State<CosmicDash>
    with SingleTickerProviderStateMixin {
  late int _balance;
  late Timer _gameTimer;
  late double _circlePositionX;
  late double _gameSpeed;
  late int _score;
  bool _isGameOver = false;
  List<Positioned> _obstacles = [];
  List<Positioned> _coins = [];
  late int _obstacleFrequency;
  late int _coinFrequency;
  late int _baseScoreIncrement;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _circlePositionX = 0.0; // Daire başlangıç pozisyonu (ekranın ortası)
      _gameSpeed = 2.0; // Başlangıç hızı
      _score = 0;
      _isGameOver = false;
      _obstacles = [];
      _coins = [];
      _obstacleFrequency = 50; // Başlangıç engel frekansı
      _coinFrequency = 30; // Başlangıç coin frekansı
      _baseScoreIncrement = 1; // Temel skor artış hızı
    });

    _startGameLoop();
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isGameOver) {
        timer.cancel();
        return;
      }

      setState(() {
        // Skoru artır
        _score += _baseScoreIncrement;

        // Hızı artır
        _gameSpeed += 0.001;

        // Engelleri ve coinleri hareket ettir
        _moveObstacles();
        _moveCoins();

        // Yeni engel ve coin ekle
        if (_score % _obstacleFrequency == 0) {
          _addObstacle();
          _obstacleFrequency =
              max(10, _obstacleFrequency - 1); // Engel frekansını azalt
        }
        if (_score % _coinFrequency == 0) {
          _addCoin();
          _coinFrequency = max(10, _coinFrequency - 1); // Coin frekansını azalt
        }

        // Çarpışma kontrolü
        _checkCollisions();
      });
    });
  }

  void _moveObstacles() {
    for (var i = 0; i < _obstacles.length; i++) {
      final obstacle = _obstacles[i];
      final newY = (obstacle.top ?? 0) + _gameSpeed;
      if (newY > MediaQuery.of(context).size.height) {
        _obstacles.removeAt(i);
        i--; // Listenin boyutunu değiştirdiğimiz için indeksi güncelliyoruz
      } else {
        _obstacles[i] = Positioned(
          left: obstacle.left,
          top: newY,
          child: obstacle.child,
        );
      }
    }
  }

  void _moveCoins() {
    for (var i = 0; i < _coins.length; i++) {
      final coin = _coins[i];
      final newY = (coin.top ?? 0) + _gameSpeed;
      if (newY > MediaQuery.of(context).size.height) {
        _coins.removeAt(i);
        i--; // Listenin boyutunu değiştirdiğimiz için indeksi güncelliyoruz
      } else {
        _coins[i] = Positioned(
          left: coin.left,
          top: newY,
          child: coin.child,
        );
      }
    }
  }

  void _addObstacle() {
    final random = Random();
    final obstacleX =
        random.nextDouble() * 2 - 1; // -1 ile 1 arasında rastgele X pozisyonu
    final obstacleWidget = Positioned(
      left: MediaQuery.of(context).size.width / 2 +
          obstacleX * MediaQuery.of(context).size.width / 2 -
          20,
      top: -40,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    _obstacles.add(obstacleWidget);
  }

  void _addCoin() {
    final random = Random();
    final coinX =
        random.nextDouble() * 2 - 1; // -1 ile 1 arasında rastgele X pozisyonu
    final coinWidget = Positioned(
      left: MediaQuery.of(context).size.width / 2 +
          coinX * MediaQuery.of(context).size.width / 2 -
          10,
      top: -20,
      child: GestureDetector(
        onTap: () {
          _collectCoin();
        },
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.yellow,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
    _coins.add(coinWidget);
  }

  void _checkCollisions() {
    for (var obstacle in _obstacles) {
      final obstacleRect = Rect.fromLTWH(
        obstacle.left ?? 0,
        obstacle.top ?? 0,
        40,
        40,
      );

      final circleRect = Rect.fromLTWH(
        MediaQuery.of(context).size.width / 2 +
            _circlePositionX * MediaQuery.of(context).size.width / 2 -
            25,
        MediaQuery.of(context).size.height - 100,
        50,
        50,
      );

      if (obstacleRect.overlaps(circleRect)) {
        _isGameOver = true;
        _endGame();
      }
    }
  }

  void _collectCoin() {
    setState(() {
      _score += 10; // Her coin için 10 puan
      _balance += 10; // Bakiyeyi güncelle
      widget.onBalanceUpdated(_balance); // Ana ekrana bakiyeyi aktar
    });
    // Coin toplama ses efekti ekle
    _playCoinSound();
  }

  void _endGame() {
    _gameTimer.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple.shade900,
        title: Text('Game Over', style: TextStyle(color: Colors.white)),
        content:
            Text('Your score: $_score', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: Text('Play Again', style: TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _balance); // Ana menüye dön
            },
            child: Text('Exit', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _moveCircle(double deltaX) {
    setState(() {
      _circlePositionX = (_circlePositionX + deltaX)
          .clamp(-1.0, 1.0); // Daire ekran sınırlarını aşamaz
    });
  }

  void _playCoinSound() {
    // Ses efektini burada ekle
    // Örneğin: AudioCache().play('coin_sound.mp3');
  }

  @override
  void dispose() {
    _gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.deepPurple.shade900],
          ),
        ),
        child: Stack(
          children: [
            // Daire
            Positioned(
              left: MediaQuery.of(context).size.width / 2 +
                  _circlePositionX * MediaQuery.of(context).size.width / 2 -
                  25,
              bottom: 50,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  _moveCircle(details.delta.dx / 100);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      Icon(Icons.rocket_launch, color: Colors.white, size: 30),
                ),
              ),
            ),

            // Engeller
            ..._obstacles,

            // Coinler
            ..._coins,

            // Skor Gösterge
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Score: $_score',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),

            // Oyun Bitti Ekranı
            if (_isGameOver)
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Game Over',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Final Score: $_score',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                        ),
                        child: Text('Play Again',
                            style:
                                TextStyle(color: Colors.purple, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
