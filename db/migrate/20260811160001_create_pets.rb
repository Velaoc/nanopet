class CreatePets < ActiveRecord::Migration[8.1]
  def change
    create_table :pets do |t|
      t.string :name, null: false
      t.string :look, null: false, default: "mochi"
      t.boolean :active, null: false, default: false
      t.integer :base_hunger, null: false, default: 70
      t.integer :base_happiness, null: false, default: 70
      t.integer :base_energy, null: false, default: 70
      t.datetime :last_cared_at, null: false
      t.datetime :resting_until
      t.timestamps
    end

    add_index :pets, :active
  end
end
