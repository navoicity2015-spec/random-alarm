import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void alarmCallback() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('alarm_ringing', true);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Будильник',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const AlarmScreen(),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  TimeOfDay _fromTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _toTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedTask = 'math';
  DateTime? _alarmTime;
  bool _isSet = false;
  bool _isRinging = false;
  Timer? _clockTimer;
  Timer? _checkTimer;
  String _currentTime = '';
  String _currentDate = '';

  // Challenge
  String _challengeQuestion = '';
  int _correctAnswer = 0;
  final _answerController = TextEditingController();
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkAlarm());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _checkTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    final seconds = now.second.toString().padLeft(2, '0');

    final days = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];

    setState(() {
      _currentTime = '$hours:$minutes:$seconds';
      _currentDate = '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]}';
    });
  }

  void _checkAlarm() async {
    if (!_isSet || _isRinging || _alarmTime == null) return;
    final now = DateTime.now();
    if (now.isAfter(_alarmTime!)) {
      setState(() {
        _isRinging = true;
        _isSet = false;
      });
      _generateChallenge();
      _showNotification();
    }
  }

  void _generateChallenge() {
    final rng = Random();
    switch (_selectedTask) {
      case 'math':
        final a = rng.nextInt(30) + 10;
        final b = rng.nextInt(30) + 10;
        _challengeQuestion = '$a + $b = ?';
        _correctAnswer = a + b;
        break;
      case 'multiply':
        final a = rng.nextInt(9) + 3;
        final b = rng.nextInt(9) + 3;
        _challengeQuestion = '$a × $b = ?';
        _correctAnswer = a * b;
        break;
      case 'reverse':
        final num = rng.nextInt(900) + 100;
        _challengeQuestion = 'Введи $num задом наперёд';
        _correctAnswer = int.parse(num.toString().split('').reversed.join());
        break;
      case 'sequence':
        final start = rng.nextInt(5) + 1;
        final step = rng.nextInt(4) + 2;
        _challengeQuestion =
            '$start → ${start + step} → ${start + step * 2} → ${start + step * 3} → ?';
        _correctAnswer = start + step * 4;
        break;
    }
    setState(() {
      _hint = '';
      _answerController.clear();
    });
  }

  Future<void> _showNotification() async {
    const details = AndroidNotificationDetails(
      'alarm_channel',
      'Будильник',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
    );
    await notifications.show(
      0,
      'Просыпайся!',
      'Реши задачу чтобы отключить будильник',
      const NotificationDetails(android: details),
    );
  }

  void _setAlarm() {
    final now = DateTime.now();

    DateTime fromDt = DateTime(
        now.year, now.month, now.day, _fromTime.hour, _fromTime.minute);
    DateTime toDt =
        DateTime(now.year, now.month, now.day, _toTime.hour, _toTime.minute);

    if (fromDt.isBefore(now)) fromDt = fromDt.add(const Duration(days: 1));
    if (toDt.isBefore(fromDt)) toDt = toDt.add(const Duration(days: 1));

    final diffMs = toDt.difference(fromDt).inMilliseconds;
    final randomMs = Random().nextInt(diffMs);
    final alarmDt = fromDt.add(Duration(milliseconds: randomMs));

    setState(() {
      _alarmTime = alarmDt;
      _isSet = true;
    });
  }

  void _cancelAlarm() {
    setState(() {
      _isSet = false;
      _alarmTime = null;
    });
  }

  void _checkAnswer() {
    final input = int.tryParse(_answerController.text);
    if (input == _correctAnswer) {
      setState(() {
        _isRinging = false;
        _hint = '';
      });
      _answerController.clear();
    } else {
      setState(() {
        _hint = 'Неверно, попробуй ещё раз';
        _answerController.clear();
      });
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _fromTime : _toTime,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isRinging ? _buildRinging() : _buildSetup(),
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clock
          Center(
            child: Column(
              children: [
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentDate,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          if (_isSet) ...[
            _buildStatusCard(),
            const SizedBox(height: 16),
          ],

          if (!_isSet) ...[
            // Time range
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Диапазон времени'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTimePicker('Не раньше', _fromTime, () => _pickTime(true))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimePicker('Не позже', _toTime, () => _pickTime(false))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Task selector
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Задача для отключения'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _taskOption('Сложение', 'math'),
                      _taskOption('Умножение', 'multiply'),
                      _taskOption('Число наоборот', 'reverse'),
                      _taskOption('Последовательность', 'sequence'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Set button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _setAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Поставить будильник',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                'точное время выбирается случайно',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final h = _alarmTime!.hour.toString().padLeft(2, '0');
    final m = _alarmTime!.minute.toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('будильник установлен на',
              style: TextStyle(fontSize: 13, color: Colors.white54)),
          const SizedBox(height: 8),
          Text('$h:$m',
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: -2)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancelAlarm,
            child: const Text('отменить',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildRinging() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔',
              style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Просыпайся!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            'сработал в ${_alarmTime!.hour.toString().padLeft(2, '0')}:${_alarmTime!.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text(
                  _challengeQuestion,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _answerController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    hintText: 'твой ответ',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => _checkAnswer(),
                ),
                if (_hint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_hint,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Остановить будильник',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w400, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskOption(String label, String value) {
    final selected = _selectedTask == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTask = value),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
