module LookoutManagerHelper
  # Returns a human-readable duration string, e.g. "1h 23m" or "45m" or "< 1m".
  def format_recording_duration(seconds)
    return "< 1m" if seconds < 60

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    parts = []
    parts << "#{hours}h" if hours > 0
    parts << "#{minutes}m" if minutes > 0
    parts.join(" ")
  end
end
