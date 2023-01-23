import 'package:flutter/material.dart';

class TimerRow extends StatefulWidget {
  final Function(int) onChange;
  final String title;
  final int value;
  final bool isCurrent;
  const TimerRow({Key? key, required this.onChange, required this.title, required this.value, required this.isCurrent}) : super(key: key);

  @override
  State<TimerRow> createState() => _TimerRowState();
}

class _TimerRowState extends State<TimerRow> {
  final TextEditingController _timerDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _timerDurationController.text = "${widget.value}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.isCurrent ? Colors.blue : Colors.white,
      child: Row(
        children: [
          Text(widget.title),
          Spacer(),
          Container(
            width: 60,
            child: TextField(
              controller: _timerDurationController,
              keyboardType: TextInputType.number,
              onChanged: (text) {
                setState(() {
                  widget.onChange(int.tryParse(text) ?? 0);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
