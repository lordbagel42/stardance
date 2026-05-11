module User::Preferences
  extend ActiveSupport::Concern

  included do
    after_create :create_preference!
  end
end
