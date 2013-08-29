class Addkeytousers < ActiveRecord::Migration
  def up
    add_column :users, :key, :string
  end

  def down
    remove_column :users, :key
  end
end
