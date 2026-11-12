defmodule Fmp4.RangeFileTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @fixture Path.expand("fixtures/frag.mp4", __DIR__)
  @size 66017

  defp get(range, opts \\ [], path \\ @fixture) do
    conn = conn(:get, "/media.mp4")
    conn = if range, do: put_req_header(conn, "range", range), else: conn
    Fmp4.RangeFile.send(conn, path, "video/mp4", opts)
  end

  test "a finished file: whole, a range, an open range, a suffix, past the end" do
    conn = get(nil)
    assert conn.status == 200
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert byte_size(conn.resp_body) == @size

    conn = get("bytes=0-1")
    assert conn.status == 206
    assert get_resp_header(conn, "content-range") == ["bytes 0-1/#{@size}"]
    assert get_resp_header(conn, "content-length") == ["2"]
    assert conn.resp_body == binary_part(File.read!(@fixture), 0, 2)

    conn = get("bytes=66000-")
    assert get_resp_header(conn, "content-range") == ["bytes 66000-#{@size - 1}/#{@size}"]
    assert byte_size(conn.resp_body) == 17

    conn = get("bytes=-10")
    assert get_resp_header(conn, "content-range") == ["bytes #{@size - 10}-#{@size - 1}/#{@size}"]

    conn = get("bytes=0-999999")
    assert get_resp_header(conn, "content-range") == ["bytes 0-#{@size - 1}/#{@size}"]

    conn = get("bytes=#{@size}-")
    assert conn.status == 416
    assert get_resp_header(conn, "content-range") == ["bytes */#{@size}"]
    assert get_resp_header(conn, "cache-control") == ["private, max-age=3600"]
  end

  test "a growing file: no total, a piece at a time, and it waits for the writer" do
    tmp = Path.join(System.tmp_dir!(), "fmp4-range-#{System.unique_integer([:positive])}.mp4")
    on_exit(fn -> File.rm(tmp) end)
    File.write!(tmp, binary_part(File.read!(@fixture), 0, 5000))

    conn = get("bytes=0-", [growing?: true, chunk: 1000], tmp)
    assert conn.status == 206
    assert get_resp_header(conn, "content-range") == ["bytes 0-999/*"]
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert byte_size(conn.resp_body) == 1000

    # Past what is written: the writer catches up within the wait.
    Task.start(fn ->
      Process.sleep(150)
      File.write!(tmp, binary_part(File.read!(@fixture), 0, 7000))
    end)

    conn = get("bytes=6000-6499", [growing?: true, wait: 2_000, poll: 50], tmp)
    assert conn.status == 206
    assert get_resp_header(conn, "content-range") == ["bytes 6000-6499/*"]

    # Past what is written and nobody writing: 416 after the wait.
    conn = get("bytes=60000-", [growing?: true, wait: 100, poll: 20], tmp)
    assert conn.status == 416
    assert get_resp_header(conn, "content-range") == ["bytes */*"]
  end
end
