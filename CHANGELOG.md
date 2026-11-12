# Changelog

## 0.1.0

Initial release.

- `Fmp4.scan/1` — the header and every complete fragment of a fragmented
  MP4, as ffmpeg writes it, read while the file grows.
- `Fmp4.playlist/3` — an HLS media playlist of byte ranges for it, open
  while the file grows and closed when done; `reach/1`, `duration/1`,
  `bitrate/1`.
- `Fmp4.RangeFile.send/4` — serves a file to a video element with HTTP
  range requests, including a file still being written.
