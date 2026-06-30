class AddHackatimeTrackingToLookoutSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :lookout_sessions, :hackatime_project_name, :string
    add_column :lookout_sessions, :hackatime_forwarded_at, :datetime
    add_column :lookout_sessions, :hackatime_skipped, :boolean, default: false, null: false
  end
end
