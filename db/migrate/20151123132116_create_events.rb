class CreateEvents < ActiveRecord::Migration
  def up
    create_table :events do |t|
      t.integer :identity, :null => false
      t.integer :score_id
      t.text :document
      t.text :ip
      t.text :created_by_profile
      t.timestamps
    end
  end

  def down
    drop_table :events
  end
end
