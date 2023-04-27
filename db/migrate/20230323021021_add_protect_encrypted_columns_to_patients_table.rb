class AddProtectEncryptedColumnsToPatientsTable < ActiveRecord::Migration[7.0]
  def change
    add_column :patients, :__full_name_encrypted, :text
    add_column :patients, :__full_name_match, :integer, limit: 2, array: true
    add_column :patients, :__full_name_ore, :ore_64_8_v1
    add_column :patients, :__full_name_unique, :text

    add_column :patients, :__email_encrypted, :text
    add_column :patients, :__email_match, :integer, limit: 2, array: true
    add_column :patients, :__email_ore, :ore_64_8_v1
    add_column :patients, :__email_unique, :text

    add_column :patients, :__dob_encrypted, :text
    add_column :patients, :__dob_ore, :ore_64_8_v1_term

    add_column :patients, :__weight_encrypted, :text
    add_column :patients, :__weight_ore, :ore_64_8_v1_term

    add_column :patients, :__allergies_encrypted, :text
    add_column :patients, :__allergies_match, :integer, limit: 2, array: true
    add_column :patients, :__allergies_ore, :ore_64_8_v1
    add_column :patients, :__allergies_unique, :text

    add_column :patients, :__medications_encrypted, :text
    add_column :patients, :__medications_match, :integer, limit: 2, array: true
    add_column :patients, :__medications_ore, :ore_64_8_v1
    add_column :patients, :__medications_unique, :text

    # Add indexes to the encrypted columns.
    add_index :patients, :__full_name_ore
    add_index :patients, :__email_ore
    add_index :patients, :__dob_ore
    add_index :patients, :__weight_ore
    add_index :patients, :__allergies_ore
    add_index :patients, :__medications_ore

    add_index :patients, :__full_name_match, using: :gin
    add_index :patients, :__email_match, using: :gin
    add_index :patients, :__allergies_match, using: :gin
    add_index :patients, :__medications_match, using: :gin
  end
end
