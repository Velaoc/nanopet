class CreateCareEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :care_events do |t|
      t.references :pet, null: false, foreign_key: true
      t.string :action, null: false
      t.string :message
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :care_events, [ :pet_id, :occurred_at ]
  end
end
