import 'package:auraninja/data/sound_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:auraninja/audio/sound_controller.dart';

class ExamplePlayerPage extends StatefulWidget {
  const ExamplePlayerPage({super.key});

  @override
  State<ExamplePlayerPage> createState() => _ExamplePlayerPageState();
}

class _ExamplePlayerPageState extends State<ExamplePlayerPage> {
  final List<SoundController> _controllers = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final sounds = buildLocalizedSounds(context);
      _controllers.addAll(sounds.map((sound) => SoundController(sound)));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _controllers.length,
      itemBuilder: (context, index) {
        return ChangeNotifierProvider.value(
          value: _controllers[index],
          child: const SoundTile(),
        );
      },
    );
  }
}

class SoundTile extends StatelessWidget {
  const SoundTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SoundController>(context);
    final sound = controller.sound;

    return ListTile(
      title: Text(sound.name),
      subtitle: Text(controller.status.toString().split('.').last),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(controller.status == PlaybackStatus.playing
                ? Icons.pause
                : Icons.play_arrow),
            onPressed: () {
              if (controller.status == PlaybackStatus.playing) {
                controller.pause();
              } else {
                controller.play();
              }
            },
          ),
          Slider(
            min: 0,
            max: 1,
            value: controller.volume,
            onChanged: (v) => controller.setVolume(v),
          ),
        ],
      ),
    );
  }
}
