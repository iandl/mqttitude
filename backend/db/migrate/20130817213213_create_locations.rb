class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string :lat
      t.string :lon
      t.string :acc
      t.string :alt 
      t.string :vac
      t.datetime :tst
     	t.belongs_to :user, index: true
    end
  end
end
