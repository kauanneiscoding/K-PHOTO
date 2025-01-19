import 'package:flutter/material.dart';
import '../currency_service.dart';

class CurrencyDisplay extends StatefulWidget {
  const CurrencyDisplay({Key? key}) : super(key: key);

  @override
  _CurrencyDisplayState createState() => _CurrencyDisplayState();
}

class _CurrencyDisplayState extends State<CurrencyDisplay> {
  int _kCoins = 0;
  int _starCoins = 0;
  int _secondsUntilNextReward = 60;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _startRewardTimer();
  }

  Future<void> _loadCurrencies() async {
    final kCoins = await CurrencyService.getKCoins();
    final starCoins = await CurrencyService.getStarCoins();
    setState(() {
      _kCoins = kCoins;
      _starCoins = starCoins;
    });
  }

  void _startRewardTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_secondsUntilNextReward > 0) {
            _secondsUntilNextReward--;
          } else {
            _addReward();
            _secondsUntilNextReward = 60;
          }
        });
        _startRewardTimer();
      }
    });
  }

  void _addReward() async {
    await CurrencyService.addKCoins(50);
    _loadCurrencies();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // K-Coins
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.pink[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Image.asset('assets/kcoin.png', width: 24, height: 24),
                  SizedBox(width: 8),
                  Text(
                    '$_kCoins',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(_secondsUntilNextReward ~/ 60).toString().padLeft(2, '0')}:${(_secondsUntilNextReward % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: Colors.pink[200]),
            ),
          ],
        ),
        SizedBox(width: 8),
        // Star-Coins
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.pink[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Image.asset('assets/starcoin.png', width: 24, height: 24),
              SizedBox(width: 8),
              Text(
                '$_starCoins',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
