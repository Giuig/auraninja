// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get sounds => 'サウンド';

  @override
  String get mixes => 'ミックス';

  @override
  String get noMixes => '保存されたミックスはありません';

  @override
  String get noMixesHint => 'サウンドを再生し、プレイヤーの「ミックスを保存」をタップ';

  @override
  String get saveMix => 'ミックスを保存';

  @override
  String get mixSaved => 'ミックスを保存しました';

  @override
  String get activeSounds => '再生中のサウンド';

  @override
  String get weather => '天気';

  @override
  String get nature => '自然';

  @override
  String get rain => '雨';

  @override
  String get wind => '風';

  @override
  String get waves => '波';

  @override
  String get fire => '火';

  @override
  String get binaural => 'バイノーラル';

  @override
  String get creativeFlow => 'クリエイティブな流れ';

  @override
  String get deepCalm => '深い静けさ';

  @override
  String get deepSleep => '深い眠り';

  @override
  String get laserFocus => '集中';

  @override
  String get theDeepestSleep => '最も深い眠り';

  @override
  String get zenCalm => '禅の静けさ';

  @override
  String get credits => 'クレジット';

  @override
  String get birds => '鳥';

  @override
  String get cat => '猫';

  @override
  String get thunder => '雷';

  @override
  String get cancelSleepTimer => 'スリープタイマーをキャンセル';

  @override
  String get resumeAll => 'すべて再開';

  @override
  String get pauseAll => 'すべて一時停止';

  @override
  String get stopAll => 'すべて停止';

  @override
  String sleepInMinutes(int minutes) {
    return '$minutes分後にスリープ';
  }

  @override
  String sleepRemainingTime(int minutes, String seconds) {
    return '$minutes分$seconds秒後にスリープ';
  }

  @override
  String get setSleepTimer => 'スリープタイマーを設定';

  @override
  String get visualizer => 'ビジュアル';

  @override
  String get internetRadio => 'インターネットラジオ';

  @override
  String get copyToClipboard => 'クリップボードにコピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました！';

  @override
  String get noise => 'ノイズ';

  @override
  String get brown => '茶色';

  @override
  String get green => '緑';

  @override
  String get pink => 'ピンク';

  @override
  String get white => 'ホワイト';

  @override
  String get vizLiquidRibbons => '液体の帯';

  @override
  String get vizBreathingOrb => '呼吸する球';

  @override
  String get vizRadialRings => '放射リング';

  @override
  String get vizParticleDrift => '粒子の流れ';

  @override
  String get vizRotatingMandala => '曼荼羅';

  @override
  String get vizConstellation => '星座';

  @override
  String get vizMorphingPolygon => '変形図形';

  @override
  String get vizAurora => 'オーロラ';

  @override
  String get vizInkDiffusion => '墨流し';

  @override
  String get playingSounds => 'サウンド再生中';

  @override
  String get paused => '一時停止中';

  @override
  String get searchStationsHint => '名前でステーションを検索…';

  @override
  String get noStationsFound => 'ステーションが見つかりません';

  @override
  String get addRadioStation => 'ラジオ局を追加';

  @override
  String get search => '検索';

  @override
  String get url => 'URL';

  @override
  String get streamUrl => 'ストリームURL';

  @override
  String get streamUrlHint => 'https://…';

  @override
  String get stationNameOptional => '局名（任意）';

  @override
  String get addStation => '局を追加';

  @override
  String get favorites => 'お気に入り';

  @override
  String get river => '川';

  @override
  String get waterfall => '滝';

  @override
  String get walkInSnow => '雪の中を歩く';

  @override
  String get walkOnLeaves => '落ち葉の上を歩く';

  @override
  String get droplets => '水滴';

  @override
  String get jungle => 'ジャングル';

  @override
  String get howlingWind => '唸る風';

  @override
  String get windInTrees => '木々の間の風';

  @override
  String get things => '物音';

  @override
  String get keyboard => 'キーボード';

  @override
  String get typewriter => 'タイプライター';

  @override
  String get clock => '時計';

  @override
  String get windChimes => '風鈴';

  @override
  String get singingBowl => '歌う鉢';

  @override
  String get ceilingFan => '天井扇風機';

  @override
  String get boilingWater => '沸騰する水';

  @override
  String get bubbles => '泡';

  @override
  String get rain2 => '雨';

  @override
  String get lightRain => '小雨';

  @override
  String get heavyRain => '大雨';

  @override
  String get rainOnWindow => '窓を打つ雨';

  @override
  String get rainOnCarRoof => '車の屋根を打つ雨';

  @override
  String get rainOnUmbrella => '傘を打つ雨';

  @override
  String get otherSounds => 'その他の音';

  @override
  String get additionalSoundsSourcedFrom => '追加の音源';

  @override
  String get crickets => 'コオロギ';

  @override
  String get frog => 'カエル';

  @override
  String get owl => 'フクロウ';

  @override
  String get whale => 'クジラ';

  @override
  String get objects => '物';

  @override
  String get places => '場所';

  @override
  String get cafe => 'カフェ';

  @override
  String get library2 => '図書館';

  @override
  String get office => 'オフィス';

  @override
  String get train => '電車';

  @override
  String get airplane => '飛行機';

  @override
  String get underwater => '水中';

  @override
  String get searchSounds => '音を検索...';

  @override
  String get nameMix => 'ミックスに名前をつける';

  @override
  String get mixNameLabel => 'ミックス名';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get renameMix => 'ミックスをリネーム';

  @override
  String get deleteMixTitle => 'ミックスを削除?';

  @override
  String get deleteMixContent => 'このミックスは完全に削除されます。';

  @override
  String get duplicateMixName => 'この名前はすでに使用されています';

  @override
  String get updateMixSounds => 'サウンドを更新';

  @override
  String get mixUpdated => 'ミックスを更新しました';
}
