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

### registerWith オプション `audioBackends` の追加

`lib/src/video_player_mdk.dart`: `registerWith(options: {'audioBackends': [...]})` で
mdk の音声バックエンドを差し替えられるようにした（`Player.audioBackends` を
`create()` の setMedia 前に適用）。iOS ロック/スリープ中に AudioQueue 出力が
無音になる問題の切り分け用（本体 `app/lib/main.dart` から iOS のみ
`['OpenAL']` を指定）。mdk v0.37.0 の iOS バイナリに `AudioBackendOpenAL` が
含まれ OpenAL.framework をリンクしていることは strings で確認済み。

### mdk-sdk の取得先を release タグ固定に変更

`cmake/deps.cmake` のデフォルトダウンロード先を sourceforge nightly から
GitHub release `v0.37.0` に固定した。nightly `0.37.0.0 b345e19` に
10bit (P010) 動画が紫/白に化けるレンダリングリグレッションがあり、
無固定 nightly では再ダウンロードのたびに壊れたビルドへ入れ替わり得るため。

- Windows x64 のアーカイブ名は release 側の命名 `mdk-sdk-windows-x64-vs2026.7z` に変更
  （v0.37.0 release に旧名 `mdk-sdk-windows-x64.7z` は存在しない）
- `FVP_DEPS_URL` 環境変数によるオーバーライドは従来どおり有効
- `FVP_DEPS_LATEST` は release 固定中は使わないこと（release アセットに `.md5` が
  提供されず、md5 比較が常に不一致になり毎回再ダウンロードされる）
- Apple 側は `darwin/fvp/Package.swift` で元から v0.37.0 固定
- 検証済みアーカイブのハッシュ（GitHub release はアセット差し替えが技術的に可能な
  ため、将来「なぜか壊れた」時の切り分け用に記録）:
  `mdk-sdk-windows-x64-vs2026.7z` SHA256 =
  `5C08BA8B7DC08FC118180E89907478F29004D2D78D0E705CED71325D97D5018A`
- mdk-sdk を更新するときは 10bit HEVC (Main10/P010) 動画の色表示を実機確認すること
- キャッシュ判定は従来 `FindMDK.cmake` の有無だけで行っており、パッケージ名/
  バージョンの一致を見ていなかった。そのため旧 nightly が展開済みの環境では、
  取得先をこのタグ固定に変更してもダウンロード・再展開が丸ごとスキップされ、
  壊れたビルドのまま気づかず使い続ける恐れがあった（code review で検出）。
  展開済みパッケージ名を `mdk-sdk/.fvp_pkg_name` に記録し、`MDK_SDK_PKG` との
  不一致を検出したら強制的に再取得するよう `deps.cmake` を修正済み

## 検証

```powershell
flutter test test/disposable_event_controller_test.dart
flutter analyze lib/src/video_player_mdk.dart lib/src/disposable_event_controller.dart test/disposable_event_controller_test.dart
```

Windows 実機では、SMB 動画再生中の NAS 強制切断と、動画切替・プレビュー終了の反復を確認する。
