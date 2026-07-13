import 'media_info.dart';

/// MDKネイティブ層（`mdk.dll`）の`FrameReader::seekComplete`はvideo/audio
/// トラック間で早い者勝ちのコールバックレースを起こし、逆方向シーク後に
/// `Player.position()`が古い値へ固定される欠陥がある。FLACの添付カバー画像は
/// 1フレームのみのvideo trackとして扱われ、シークの度に即EOFとなって
/// このレースを誘発しやすいため、該当条件を満たす場合だけvideo trackを
/// 無効化して回避する。詳細:
/// docs/superpowers/investigations/2026-07-13-backward-audio-seek-mdk-position-freeze.md

/// FLACの添付カバー画像として無効化すべきvideo trackのindex一覧を返す。
///
/// `MediaInfo.format`がFLAC、audio trackが存在し、video trackが存在し、
/// すべてのvideo trackが正確に1フレームである場合だけindexを返す。
/// `frames == 0`（不明）や2フレーム以上を含む場合は無効化しない。
List<int> flacAttachedPictureVideoTrackIndexes(MediaInfo mediaInfo) {
  final audio = mediaInfo.audio;
  final video = mediaInfo.video;
  if (mediaInfo.format?.toLowerCase() != 'flac' ||
      audio == null ||
      audio.isEmpty ||
      video == null ||
      video.isEmpty ||
      !video.every((track) => track.frames == 1)) {
    return const [];
  }
  return List.unmodifiable(video.map((track) => track.index));
}

/// 該当時だけ[disableVideo]を1回呼び、無効化したvideo trackのindex一覧を返す
/// （非該当時は空リスト）。
List<int> disableFlacAttachedPictureTracks(
  MediaInfo mediaInfo,
  void Function() disableVideo,
) {
  final tracks = flacAttachedPictureVideoTrackIndexes(mediaInfo);
  if (tracks.isEmpty) {
    return tracks;
  }
  disableVideo();
  return tracks;
}
