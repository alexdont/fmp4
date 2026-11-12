# Fmp4

Play a video conversion while ffmpeg is still writing it.

ffmpeg can copy a release's video into one **fragmented MP4** that grows as
it runs (`-movflags frag_keyframe+empty_moov+default_base_moof`): a fraction
of a core, no segment files, and the only form of HEVC Safari plays through
HLS. This package reads that file's shape — the fragments on disk, their
times and byte ranges — turns it into an HLS playlist of byte ranges, and
serves the file to a `<video>` element with range requests that wait for
the writer. Nothing is decoded.

```elixir
def deps do
  [{:fmp4, "~> 0.1"}]
end
```

## Reading the file

```elixir
{:ok, info} = Fmp4.scan("media.mp4")
info.init        #=> 1255          bytes of header (ftyp + moov)
info.start       #=> 0.0           seconds: where in the film the file begins
info.fragments   #=> [%{offset: 1255, size: 20569, time: 0.0, duration: 2.028}, …]

Fmp4.reach(info)     #=> 6.13      seconds of film written so far
Fmp4.bitrate(info)   #=> 86_000    bits per second, for a master playlist's BANDWIDTH
```

Only complete fragments are returned, so a scan during a conversion is
always playable. Before the header is on disk it is `{:error, :no_header}`.

A file begun part-way through a longer one (ffmpeg `-ss 1800 -copyts
-avoid_negative_ts disabled -movflags +frag_discont`) keeps the film's own
clock: `start` is 1800 and the fragments' times count from there, so a
player can seek in the whole film across several such files.

## The playlist

```elixir
Fmp4.playlist(info, "media.mp4", done: ffmpeg_finished?)
```

```
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:EVENT
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MAP:URI="media.mp4",BYTERANGE="1255@0"
#EXTINF:2.028,
#EXT-X-BYTERANGE:20569@1255
media.mp4
…
```

Serve it fresh on every request: while the file grows the playlist is
`EVENT` type and the player keeps reloading it; `done: true` ends it. Safari
plays it natively; hls.js needs `liveDurationInfinity: false` to show a
seek bar for an EVENT playlist.

## Serving the file

```elixir
def media(conn, %{"name" => name}) do
  Fmp4.RangeFile.send(conn, path(name), "video/mp4", growing?: not finished?(name))
end
```

Answers `Range` requests with `206` and `Content-Range`. A growing file has
no total yet: its ranges say `*`, come a piece at a time (so the browser
asks again as it fills), and a request past what exists waits up to
`:wait` ms for the writer before `416`. It works for any file — a plain
MP4, a Matroska release — not only fragmented ones.

## Making the file

```sh
ffmpeg -i release.mkv -c:v copy -c:a aac \
  -movflags frag_keyframe+empty_moov+default_base_moof \
  -frag_duration 2000000 media.mp4
```

## License

MIT © Alexander Don
