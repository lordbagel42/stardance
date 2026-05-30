class AddGuestEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :guest_email, :string
    add_index :users, :guest_email
  end
end
