# frozen_string_literal: true

# Classifies a repository file path for the cockpit file browser: a short badge
# label (DOC / CAD / KICAD / GBR / FW / IMG …) plus how the preview pane should
# render it. Extension-driven, with a couple of path-based rules for gerber output.
class RepoFileKind
  Kind = Data.define(:key, :label, :preview)
  # preview is one of: :markdown, :code, :image, :none (binary / not previewable)

  CAD      = %w[step stp stl f3d 3mf iges igs obj scad sldprt sldasm ipt catpart dxf dwg].freeze
  KICAD    = %w[kicad_pcb kicad_sch kicad_pro sch brd net lib].freeze
  GERBER   = %w[gbr ger gbl gtl gto gts gbs gko gm1 gpi drl xln nc].freeze
  FIRMWARE = %w[c cpp cc h hpp ino py rs go v sv vhd s asm].freeze
  CODE     = %w[js ts jsx tsx rb java kt cs swift php lua sh bash zsh].freeze
  DATA     = %w[json yml yaml toml ini cfg conf xml env properties].freeze
  DOC_TEXT = %w[txt rst adoc org log].freeze
  IMAGE    = %w[png jpg jpeg gif svg webp bmp ico avif].freeze

  # Extension-less files that are still plain text worth previewing.
  TEXT_BASENAMES = %w[
    makefile dockerfile license readme changelog authors contributing
    codeowners cmakelists gemfile rakefile procfile .gitignore .gitattributes
    .env .editorconfig .dockerignore
  ].freeze

  def self.for(path)
    lower = path.to_s.downcase
    ext = File.extname(lower).delete_prefix(".")
    base = File.basename(lower)

    return Kind.new(key: "gbr", label: "GBR", preview: :none) if gerber?(lower, ext)

    key, label, preview =
      case ext
      when "md", "markdown" then [ "doc", "DOC", :markdown ]
      when "csv", "tsv"     then [ "data", "CSV", :csv ]
      when *IMAGE           then [ "img", "IMG", :image ]
      when *CAD             then [ "cad", "CAD", :none ]
      when *KICAD           then [ "kicad", "KICAD", :none ]
      when *FIRMWARE        then [ "fw", "FW", :code ]
      when *CODE            then [ "code", "CODE", :code ]
      when *DATA            then [ "data", "DATA", :code ]
      when *DOC_TEXT        then [ "doc", "DOC", :code ]
      when "pdf"            then [ "doc", "PDF", :none ]
      else fallback(base, ext)
      end

    Kind.new(key: key, label: label, preview: preview)
  end

  def self.fallback(base, ext)
    return [ "file", "TXT", :code ] if TEXT_BASENAMES.include?(base)

    [ "file", (ext.present? ? ext.upcase[0, 5] : "FILE"), :none ]
  end
  private_class_method :fallback

  def self.gerber?(lower, ext)
    return true if GERBER.include?(ext)

    (lower.include?("gerber") || lower.include?("production")) && ext == "zip"
  end
  private_class_method :gerber?
end
