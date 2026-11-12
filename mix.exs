defmodule Fmp4.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Read a fragmented MP4 while ffmpeg is still writing it — the fragments on disk, their times and byte ranges — turn it into an HLS playlist of byte ranges, and serve it to a video element with HTTP range requests that wait for the writer. No decoding, no dependencies beyond Plug."
  @source_url "https://github.com/alexdont/fmp4"

  def project do
    [
      app: :fmp4,
      version: @version,
      description: @description,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:plug, "~> 1.14", optional: true},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "fmp4",
      maintainers: ["Alexander Don"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      name: "Fmp4",
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "Fmp4",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
