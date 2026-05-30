class AddGuestEmailToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :guest_email, :string
    add_index :users, :guest_email, algorithm: :concurrently
  end
end
