# fvp fork notes

- ベース: upstream master `a58bca574da09fc6dd259cdc4119f4679dda136c`
- 対象リリース: pub.dev `fvp 0.37.3`
- fork: https://github.com/kidonaru/fvp
- 参照方法: 親リポジトリの `app/pubspec.yaml` から `dependency_overrides.fvp.path: ../third_party/fvp`

## 上流からの改変点

### dispose 後イベントの未捕捉例外対策

`MdkVideoPlayer.dispose()` が出力用 `StreamController` を close した後も、
`onMediaStatus`、`onEvent`、`onStateChanged` の購読および
`textureSize.then(...)` がイベントを追加し、
`Bad state: Cannot add event after closing` になる競合を修正した。

- 3 本の MDK イベント購読を player が保持し、dispose 時に cancel する。
- dispose 後のイベントとエラーを安全に無視する。
- dispose を冪等化する。

### seek in-flight dispose のポート閉鎖後 postCObject error 対策

`lib/src/player.dart` `Player.dispose()`: ポートを閉じる直前に保留中の
seek 完了（`_seeked`）を最大 50ms 待つ。seek in-flight のまま dispose すると
native seek コールバックが閉じたポートへ post して `callbacks.cpp` の
`MdkSeek` が `postCObject error` を出す問題（ログノイズ・実害なし）を解消するため。

- 待機は `_seeked` が未完了のときのみで、大多数の dispose では発生しない。
- コールバック到達で即解決し、来ない稀なケースは 50ms でタイムアウトして従来挙動へ戻す。
- native（C++）は変更していない。MdkSnapshot 経路は対象外。

## 検証

```powershell
flutter test test/disposable_event_controller_test.dart
flutter analyze lib/src/video_player_mdk.dart lib/src/disposable_event_controller.dart test/disposable_event_controller_test.dart
```

Windows 実機では、SMB 動画再生中の NAS 強制切断と、動画切替・プレビュー終了の反復を確認する。
