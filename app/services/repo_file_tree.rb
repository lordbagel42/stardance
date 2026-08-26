# frozen_string_literal: true

# Turns a flat list of repo entries ({ path:, size: }) into a nested tree for the
# cockpit file browser: directories (sorted first, alphabetically) then files.
# Each node is either { type: :dir, name:, children: [...] } or
# { type: :file, name:, path:, size: }.
class RepoFileTree
  def self.build(entries)
    root = { dirs: {}, files: [] }

    Array(entries).each do |entry|
      parts = entry[:path].to_s.split("/")
      name = parts.pop
      next if name.blank?

      node = parts.reduce(root) { |n, seg| n[:dirs][seg] ||= { dirs: {}, files: [] } }
      node[:files] << { type: :file, name: name, path: entry[:path], size: entry[:size] }
    end

    order(root)
  end

  # Directories first (alpha), then files (alpha) — the usual file-browser sort.
  def self.order(node)
    dirs = node[:dirs].keys.sort_by(&:downcase).map do |name|
      { type: :dir, name: name, children: order(node[:dirs][name]) }
    end
    files = node[:files].sort_by { |file| file[:name].downcase }
    dirs + files
  end
  private_class_method :order
end
