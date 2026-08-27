require "test_helper"

class RepoFileKindTest < ActiveSupport::TestCase
  def kind(path) = RepoFileKind.for(path)

  test "markdown renders as markdown under the DOC badge" do
    assert_equal "DOC", kind("README.md").label
    assert_equal :markdown, kind("docs/guide.md").preview
  end

  test "renderable CAD (STL/STEP) previews as a 3D model" do
    %w[bracket.stl case/part.step body.stp].each do |path|
      assert_equal :model, kind(path).preview, path
    end
    assert_equal "STL", kind("bracket.stl").label
    assert_equal "STEP", kind("case/part.step").label
    assert_equal "STEP", kind("body.stp").label
  end

  test "non-renderable CAD stays a plain, non-previewable CAD badge" do
    %w[body.f3d model.3mf assembly.iges sketch.dxf part.sldprt].each do |path|
      assert_equal "CAD", kind(path).label, path
      assert_equal :none, kind(path).preview, path
    end
  end

  test "KiCad sources get the KICAD badge" do
    assert_equal "KICAD", kind("pcb/board.kicad_pcb").label
    assert_equal :none, kind("pcb/board.kicad_pcb").preview
  end

  test "gerbers are detected by extension and by production/gerber folders" do
    assert_equal "GBR", kind("output.gbr").label
    assert_equal "GBR", kind("jlcpcb/production_files/GERBER-kanji.zip").label
    assert_equal "GBR", kind("gerber/layers.zip").label
    # a zip that isn't a gerber output stays a generic file
    assert_not_equal "GBR", kind("firmware/release.zip").label
  end

  test "firmware and code preview as code" do
    %w[firmware/main.c src/app.cpp include/pins.h sketch.ino tool.py].each do |path|
      assert_equal :code, kind(path).preview, path
    end
    assert_equal "FW", kind("firmware/main.c").label
  end

  test "csv and tsv preview as a table" do
    assert_equal :csv, kind("data/readings.csv").preview
    assert_equal "CSV", kind("data/readings.csv").label
    assert_equal :csv, kind("log.tsv").preview
  end

  test "images preview as image" do
    assert_equal :image, kind("docs/wiring.png").preview
    assert_equal "IMG", kind("photo.JPG").label
  end

  test "extension-less text files still preview as code" do
    assert_equal :code, kind("Makefile").preview
    assert_equal :code, kind("LICENSE").preview
    assert_equal :code, kind(".gitignore").preview
  end

  test "unknown binary extensions are not previewable" do
    assert_equal :none, kind("firmware/app.bin").preview
    assert_equal "BIN", kind("firmware/app.bin").label
  end
end
