import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haptic_timer/timer_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:volume/volume.dart';

Future<void> main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haptic Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Haptic Timer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  // Storage keys
  static const String TimerDurationsKey = "TimerDurations";
  static const String CooldownDurationKey = "CooldownDuration";
  static const String VolumeSetpointKey = "VolumeSetpointKey";

  // Text input
  int _cooldownDuration = 0;
  List<int> _timers = [];

  // Text managment
  TextEditingController _cooldownDurationController = TextEditingController();
  bool _expanded = true;

  // Timer managment
  bool _timerRunning = false;
  Timer? _timer;
  int _nextIndex = 0;

  // Volume
  double _volumeSetpoint = 1;
  int? _previousVolume;

  // Output
  int _timeRemaining = 0;
  bool _isOnCooldown = false;

  void _toggleTimer() {
    if (_timerRunning) {
      _cancelTimer();
    } else {
      Volume.getVol.then((value) async {
        _previousVolume = value;
        int maxVol = await Volume.getMaxVol;
        Volume.setVol((maxVol * _volumeSetpoint).ceil(), showVolumeUI: ShowVolumeUI.HIDE);
      });
      _startTimer(isOnCooldown: false, nextIndex: 0);
    }
  }

  void _cancelTimer() {
    setState(() {
      _timerRunning = false;
      _timeRemaining = 0;
      _isOnCooldown = false;
    });

    if (_previousVolume != null) {
      Volume.setVol(_previousVolume, showVolumeUI: ShowVolumeUI.HIDE);
    }
    Wakelock.disable();
    _timer?.cancel();
  }

  Future<void> _startTimer({required bool isOnCooldown, required int nextIndex}) async {
    setState(() {
      _timerRunning = true;
      _timeRemaining = isOnCooldown ? _cooldownDuration : _timers[nextIndex];
      _isOnCooldown = isOnCooldown;
      _nextIndex = nextIndex;
    });

    Wakelock.enable();
    if (_timeRemaining == 0) {
      _isOnCooldown = !_isOnCooldown;
      _timeRemaining = isOnCooldown ? _cooldownDuration : _timers[nextIndex];
    }
    _timer = Timer.periodic(Duration(seconds: 1), _updateTimer);
  }

  AudioCache player = AudioCache();
  Future<void> vibrate(int times) async {
    await player.play("alert.wav", mode: PlayerMode.LOW_LATENCY);
    for (var i = 0; i < times; i++) {
      await HapticFeedback.vibrate();
      sleep(Duration(milliseconds: 100));
    }
  }

  void _updateTimer(Timer timer) async {
    setState(() => _timeRemaining -= 1);

    if (_timeRemaining > 0) return;
    timer.cancel();

    await vibrate(1);
    if (!_isOnCooldown) {
      await vibrate(1);
    }

    if (_nextIndex == _timers.length - 1) {
      _cancelTimer();
      return;
    }

    // Only decrement repeat after cooldown
    _startTimer(isOnCooldown: !_isOnCooldown, nextIndex: _nextIndex + (_isOnCooldown ? 1 : 0));
  }

  @override
  void initState() {
    super.initState();
    Volume.controlVolume(AudioManager.STREAM_MUSIC);
    player.load("alert.wav");
    WidgetsBinding.instance?.addObserver(this);
    SharedPreferences.getInstance().then((preferences) {
      setState(() {
        _timers = (preferences.getStringList(TimerDurationsKey) ?? ["0"]).map((string) => int.parse(string)).toList();
        _cooldownDuration = preferences.getInt(CooldownDurationKey) ?? 0;

        _cooldownDurationController.text = _cooldownDuration == 0 ? '' : '$_cooldownDuration';
        _volumeSetpoint = preferences.getDouble(VolumeSetpointKey) ?? 1;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();

    WidgetsBinding.instance?.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      SharedPreferences.getInstance().then((preferences) {
        preferences.setStringList(TimerDurationsKey, _timers.map((e) => "$e").toList());
        preferences.setInt(CooldownDurationKey, _cooldownDuration);
        preferences.setDouble(VolumeSetpointKey, _volumeSetpoint);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Text("Alarm volume:"),
                  Spacer(),
                ],
              ),
              Slider(
                value: _volumeSetpoint,
                onChanged: (value) => setState(() => _volumeSetpoint = value),
              ),
              Row(
                children: [
                  Text("Cooldown:"),
                  Spacer(),
                  Container(
                    width: 60,
                    child: TextField(
                      controller: _cooldownDurationController,
                      keyboardType: TextInputType.number,
                      onChanged: (text) {
                        setState(() => _cooldownDuration = int.tryParse(text) ?? 0);
                      },
                    ),
                  )
                ],
              ),
              SizedBox(height: 32),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Row(
                  children: [
                    Text(
                      "Timers",
                      style: TextStyle(color: Colors.black),
                    ),
                    Spacer(),
                    Icon(_expanded ? Icons.arrow_drop_down : Icons.arrow_drop_up),
                  ],
                ),
              ),
              if (_expanded)
                Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _timers.length,
                      itemBuilder: (context, index) => ConditionalParentWidget(
                        condition: index != 0,
                        child: TimerRow(
                          onChange: (value) {
                            _timers[index] = value;
                          },
                          title: "Timer ${index + 1}",
                          value: _timers[index],
                          isCurrent: _timerRunning && (index == _nextIndex),
                        ),
                        conditionalBuilder: (child) => Dismissible(
                            key: UniqueKey(),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => setState(() => _timers.removeAt(index)),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: child),
                      ),
                    ),
                    SizedBox(height: 32),
                    TextButton(
                        onPressed: _timerRunning ? null : () => setState(() => _timers.add(_timers.last)),
                        style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.disabled) ? Colors.grey : Colors.blue),
                            foregroundColor: MaterialStateProperty.all<Color>(Colors.white)),
                        child: Text("Add Timer")),
                  ],
                ),
              SizedBox(height: 32),
              Text("$_timeRemaining", style: TextStyle(fontSize: 50)),
              SizedBox(height: 32),
              TextButton(
                  onPressed: _toggleTimer,
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(_timerRunning ? Colors.red : Colors.green),
                      foregroundColor: MaterialStateProperty.all<Color>(Colors.black)),
                  child: Text(_timerRunning ? "Stop" : "Start"))
            ],
          ),
        ),
      ),
    );
  }
}

class ConditionalParentWidget extends StatelessWidget {
  const ConditionalParentWidget({
    Key? key,
    required this.condition,
    required this.child,
    required this.conditionalBuilder,
  }) : super(key: key);

  final Widget child;
  final bool condition;
  final Widget Function(Widget child) conditionalBuilder;

  @override
  Widget build(BuildContext context) {
    return condition ? this.conditionalBuilder(this.child) : this.child;
  }
}
