import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:audio_service/audio_service.dart';

Future<WrapperAudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => WrapperAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'io.github.giuig.auraninja.audio',
      androidNotificationChannelName: 'Auraninja Audio',
      androidNotificationOngoing: true,
    ),
  );
}
