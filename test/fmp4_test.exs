defmodule Fmp4Test do
  use ExUnit.Case, async: true

  @frag Path.expand("fixtures/frag.mp4", __DIR__)
  @offset Path.expand("fixtures/frag-offset.mp4", __DIR__)

  # 6 s of testsrc + sine, fragmented every 2 s (ffmpeg -movflags frag_keyframe+empty_moov+default_base_moof).
  test "scan reads the header and every complete fragment" do
    assert {:ok, info} = Fmp4.scan(@frag)
    assert info.init == 1255
    assert info.timescale == 10240
    assert info.start == 0.0
    assert length(info.fragments) == 4

    [first | _] = info.fragments
    assert first.offset == info.init
    assert_in_delta first.duration, 2.03, 0.01
    assert_in_delta Fmp4.duration(info), 6.13, 0.01
    assert_in_delta Fmp4.reach(info), 6.13, 0.01

    # The fragments tile the file after the header (ffmpeg ends it with an `mfra` index, 224 bytes).
    Enum.reduce(info.fragments, info.init, fn f, pos ->
      assert f.offset == pos
      pos + f.size
    end)
    |> then(&assert(&1 == File.stat!(@frag).size - 224))

    # Each fragment begins where the one before ended.
    Enum.reduce(info.fragments, 0.0, fn f, t ->
      assert_in_delta f.time, t, 0.001
      t + f.duration
    end)

    assert Fmp4.bitrate(info) > 50_000
  end

  # The same, begun at 30 s of a 36 s film (-ss 30 -copyts -avoid_negative_ts disabled +frag_discont).
  test "a file begun part-way carries the film's own clock" do
    assert {:ok, info} = Fmp4.scan(@offset)
    assert info.start == 30.0
    assert [%{time: 30.0}, %{time: 32.0}, %{time: 34.0}] = info.fragments
    assert Fmp4.reach(info) == 36.0
    assert Fmp4.duration(info) == 6.0
  end

  test "a file still being written is read as far as it is complete" do
    {:ok, info} = Fmp4.scan(@frag)
    [f1, f2 | _] = info.fragments
    tmp = Path.join(System.tmp_dir!(), "fmp4-growing-#{System.unique_integer([:positive])}.mp4")
    on_exit(fn -> File.rm(tmp) end)

    # Header plus one fragment plus half of the next: one fragment counts.
    File.write!(tmp, binary_part(File.read!(@frag), 0, f2.offset + div(f2.size, 2)))
    assert {:ok, %{fragments: [^f1]}} = Fmp4.scan(tmp)

    # Half a header: nothing yet.
    File.write!(tmp, binary_part(File.read!(@frag), 0, 600))
    assert Fmp4.scan(tmp) == {:error, :no_header}

    # The header alone: no fragment.
    File.write!(tmp, binary_part(File.read!(@frag), 0, info.init))
    assert {:ok, %{fragments: []}} = Fmp4.scan(tmp)

    assert {:error, :enoent} = Fmp4.scan(tmp <> ".missing")
    assert Fmp4.bitrate(%{fragments: []}) == nil
  end

  test "playlist names the header and one byte range per fragment" do
    {:ok, info} = Fmp4.scan(@frag)
    open = Fmp4.playlist(info, "media.mp4")
    assert open =~ "#EXT-X-PLAYLIST-TYPE:EVENT"
    assert open =~ ~s(#EXT-X-MAP:URI="media.mp4",BYTERANGE="1255@0")
    assert open =~ "#EXTINF:2.028,\n#EXT-X-BYTERANGE:20569@1255\nmedia.mp4\n"
    assert open =~ "#EXT-X-TARGETDURATION:10"
    refute open =~ "ENDLIST"

    done = Fmp4.playlist(info, "media.mp4", done: true, target: 2, sequence: 3)
    assert done =~ "#EXT-X-PLAYLIST-TYPE:VOD"
    assert done =~ "#EXT-X-TARGETDURATION:3"
    assert done =~ "#EXT-X-MEDIA-SEQUENCE:3"
    assert String.ends_with?(done, "#EXT-X-ENDLIST\n")
  end
end
