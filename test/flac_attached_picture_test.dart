import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/mdk.dart';
import 'package:fvp/src/flac_attached_picture.dart';

/// pure DartのfixtureからMediaInfoを組み立てる。
///
/// [audioTracks]本のaudioトラックの後ろに[videoFrames]の要素数だけvideoトラックを
/// 続けて生成する（index 0..audioTracks-1がaudio、以降がvideo）。
MediaInfo buildMediaInfo({
  String? format,
  int audioTracks = 0,
  List<int>? videoFrames,
}) {
  final mediaInfo = MediaInfo()..format = format;
  if (audioTracks > 0) {
    mediaInfo.audio = List.generate(
      audioTracks,
      (i) => AudioStreamInfo()..index = i,
    );
  }
  if (videoFrames != null) {
    mediaInfo.video = List.generate(
      videoFrames.length,
      (i) => VideoStreamInfo()
        ..index = audioTracks + i
        ..frames = videoFrames[i],
    );
  }
  return mediaInfo;
}

void main() {
  test('FLACで音声と1フレーム映像があれば映像indexを返す', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [1],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), [1]);
  });

  test('フレーム数不明の映像は無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [0],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('複数の1フレーム映像はすべてのindexを返す', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [1, 1],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), [1, 2]);
  });

  test('formatの大文字小文字差を無視する', () {
    final mediaInfo = buildMediaInfo(
      format: 'FLAC',
      audioTracks: 1,
      videoFrames: const [1],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), [1]);
  });

  test('audioトラックがなければ無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 0,
      videoFrames: const [1],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('videoトラックがなければ無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: null,
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('video framesが2以上なら無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [2],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('1フレームと複数フレームが混在する場合は無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [1, 2],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('FLAC以外は1フレーム映像があっても無効化しない', () {
    final mediaInfo = buildMediaInfo(
      format: 'mp4',
      audioTracks: 1,
      videoFrames: const [1],
    );

    expect(flacAttachedPictureVideoTrackIndexes(mediaInfo), isEmpty);
  });

  test('該当時はdisableVideoが1回呼ばれ無効化したindex一覧を返す', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [1],
    );
    var callCount = 0;

    final disabledTracks =
        disableFlacAttachedPictureTracks(mediaInfo, () => callCount++);

    expect(disabledTracks, [1]);
    expect(callCount, 1);
  });

  test('非該当時はdisableVideoが呼ばれず空リストを返す', () {
    final mediaInfo = buildMediaInfo(
      format: 'flac',
      audioTracks: 1,
      videoFrames: const [2],
    );
    var callCount = 0;

    final disabledTracks =
        disableFlacAttachedPictureTracks(mediaInfo, () => callCount++);

    expect(disabledTracks, isEmpty);
    expect(callCount, 0);
  });
}
