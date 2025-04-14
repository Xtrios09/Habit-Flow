import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(FocusApp());

class FocusApp extends StatefulWidget {
  @override
  _FocusAppState createState() => _FocusAppState();
}

class _FocusAppState extends State<FocusApp> {
  String? _name;
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('userName');
    final storedTheme = prefs.getBool('darkTheme') ?? false;
    setState(() => _themeMode = storedTheme ? ThemeMode.dark : ThemeMode.light);
    if (storedName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
    } else {
      setState(() => _name = storedName);
    }
  }

  Future<void> _askName() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("What's your name?"),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: "Enter your name"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userName', name);
                setState(() => _name = name);
                Navigator.of(context).pop();
              }
            },
            child: Text("OK"),
          )
        ],
      ),
    );
  } 

  @override
  Widget build(BuildContext context) {
    if (_name == null) {
      return MaterialApp(home: Scaffold());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Focus App',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF4F9FF),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
      ),
      darkTheme: ThemeData.dark(),
      home: HomeScreen(userName: _name!, onThemeChanged: (isDark) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('darkTheme', isDark);
        setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
      }),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final Function(bool) onThemeChanged;
  HomeScreen({required this.userName, required this.onThemeChanged});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = true;
  bool _musicOn = true;
  int _focusIndex = 0;
  AudioPlayer player = AudioPlayer();

  late AnimationController _animationController;

  List<Map<String, dynamic>> tasks = [
    {'title': 'Finish report', 'time': '1h', 'done': false},
    {'title': 'Call with client', 'stepHint': 'Add step', 'done': false},
    {'title': 'Brainstorm ideas', 'hasIcon': true, 'done': false},
  ];

  TextEditingController taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
    _startTimer();
    _playBackground();
  }

  Future<void> _playBackground() async {
    if (_musicOn) {
      await player.play(AssetSource('rain.mp3'), volume: 0.5);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && _isRunning) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
  }

  void _toggleMusic() async {
    setState(() => _musicOn = !_musicOn);
    if (_musicOn) {
      await _playBackground();
    } else {
      await player.stop();
    }
  }

  void _addTask() {
    if (taskController.text.trim().isNotEmpty) {
      setState(() {
        tasks.insert(0, {'title': taskController.text.trim(), 'done': false});
        taskController.clear();
      });
    }
  }

  void _toggleTaskDone(int index) {
    setState(() {
      tasks[index]['done'] = true;
    });
  }

  void _setFocusTask(int index) {
    setState(() => _focusIndex = index);
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            value: _musicOn,
            onChanged: (_) => _toggleMusic(),
            secondary: Icon(Icons.music_note),
            title: Text("Background Music"),
          ),
          SwitchListTile(
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (val) => widget.onThemeChanged(val),
            secondary: Icon(Icons.dark_mode),
            title: Text("Dark Theme"),
          ),
          ListTile(
            leading: Icon(Icons.timer),
            title: Text("Change Timer Duration"),
            onTap: () => _changeTimerDialog(),
          ),
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text("Donate ✨"),
          ),
        ],
      ),
    );
  }

  void _changeTimerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Set Timer Duration (minutes)"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: "25"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              int? newDuration = int.tryParse(controller.text);
              if (newDuration != null && newDuration > 0) {
                setState(() => _remainingSeconds = newDuration * 60);
              }
              Navigator.pop(context);
            },
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    player.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_remainingSeconds / (25 * 60));
    final focusTask = tasks[_focusIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Focus Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          )
        ],
      ),
      body: Center(
        child: Container(
          width: 1080 / 3,
          height: 1920 / 3,
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey ${widget.userName},\nready to crush it?',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 30),
                Text('Focus'),
                Text(focusTask['title'], style: TextStyle(fontSize: 18)),
                SizedBox(height: 20),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: CircularProgressIndicator(
                          value: 1 - progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (_, child) => Opacity(
                              opacity: 0.5 + 0.5 * _animationController.value,
                              child: Text(_formatTime(_remainingSeconds),
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(height: 10),
                          IconButton(
                            icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                            iconSize: 32,
                            onPressed: _toggleTimer,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                SizedBox(height: 30),
                Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
                TextField(
                  controller: taskController,
                  decoration: InputDecoration(
                    hintText: 'Add a new task',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addTask,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Column(
                  children: tasks
                      .asMap()
                      .entries
                      .where((e) => !e.value['done'])
                      .map((entry) => GestureDetector(
                            onTap: () => _setFocusTask(entry.key),
                            child: TaskTile(
                              title: entry.value['title'],
                              time: entry.value['time'],
                              stepHint: entry.value['stepHint'],
                              hasIcon: entry.value['hasIcon'] ?? false,
                              isDone: entry.value['done'],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final String title;
  final String? time;
  final String? stepHint;
  final bool hasIcon;
  final bool isDone;

  const TaskTile({
    required this.title,
    this.time,
    this.stepHint,
    this.hasIcon = false,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(
              isDone ? Icons.check_box : Icons.check_box_outline_blank,
              color: isDone ? Colors.green : Colors.grey,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16)),
                if (stepHint != null)
                  Text(stepHint!, style: TextStyle(color: Colors.blue, fontSize: 13))
              ],
            ),
          ]),
          if (time != null) Text(time!),
          if (hasIcon) Icon(Icons.bubble_chart_rounded, color: Colors.indigoAccent)
        ],
      ),
    );
  }
}
