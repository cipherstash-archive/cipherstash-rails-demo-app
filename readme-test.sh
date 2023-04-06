#!/usr/bin/env sh

set -euo pipefail

echo 'Simple automated readme tester'
echo
echo '   ***IMPORTANT***'
echo 'This is for the second run and onwards. If this is the first time, please follow README.md.'
echo
echo "Assumptions
  * You've run through this demo manually at lease once 
  * You've installed asdf
  * You've installed asdf ruby plugin
  * You've installed asdf postgres plugin
  * You've installed cipherstash-cli and the 'stash' command in in your path
  * You've installed direnv
  * You've created a dataset and client
  * You've set up .envrc with 'export CS_CLIENT_KEY=...' and 'export CS_CLIENT_ID=...'
  * You've logged in with 'stash login'
  * This directory is clean - no changes in Gemfile, no generated migration etc etc
"
echo
echo
echo 'Are all of the above correct? Are you ready to proceed?'
echo
printf 'Press enter to continue and press CTL-C to exit: '
read

printf 'Which version would you like to use? (eg. 2.7.2, 3.1.3, 3.2.2): '

read version

# .ruby-version update
sed -i.bak "s/^ruby .*$/ruby ${version}/" .tool-versions
/bin/rm -f .tool-versions.bak

# Gemfile update
sed -i.bak "s/^ruby .*$/ruby \"${version}\"/" Gemfile
/bin/rm -f Gemfile.bak

# Assumes asdf and ruby plugin is installed (also postgres)
asdf install
asdf exec gem install bundler
asdf exec bundle install
asdf exec rails db:drop
asdf exec rails db:setup

echo
echo
echo 'Press enter to start rails server.'
echo 'Go to http://localhost:3000/admin/patients and browse through some records.'
echo 'Feel free to update or create records'
echo "Press CTL-C to exit once you're done."
echo
printf 'Press enter to start rails server and continue: '

read

asdf exec rails s

echo
echo
echo "Welcome back!"
echo
echo

# Assume stash is installed and in the path, signup and login are already done

echo 'Press enter to update Gemfile.'
echo "'pg' will be removed and 'activerecord-cipherstash-pg-adapter' will be added."
echo "'bundle install' will also be executed following the change."
echo
printf 'press enter to continue: '
read

# replace pg with activerecord-cipherstash-pg-adapter
sed -i.bak 's/^gem "pg.*$/gem "activerecord-cipherstash-pg-adapter"/' Gemfile
/bin/rm -f Gemfile.bak

asdf exec bundle install

echo
echo
echo "Press enter to update config/database.yaml to replace postgresql adapter with pastgres_cipherstash."
echo
printf 'Press enter to update database.yml: '
read

# replace postgresql adapter with postgres_cipherstash
sed -i.bak 's/adapter: postgresql/adapter: postgres_cipherstash/' config/database.yml
/bin/rm -f config/database.yml.bak

# Assume stash login is done

# Assume dataset and client have been created and are in .direnv

echo
echo
printf 'About to upload dataset.yml. Press enter to continue: '
read

stash upload-config --file dataset.yml --client-id $CS_CLIENT_ID --client-key $CS_CLIENT_KEY


echo
echo
echo 'About to generate and run migration for adding protect db extensions.'
echo
printf 'Press enter to continue: '
read

asdf exec rails generate migration AddProtectDatabaseExtensions

migration=$(find db/migrate -iname '*add_protect_database_extensions.rb')

echo 'class AddProtectDatabaseExtensions < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::ConnectionAdapters::CipherStashPG.install
  end

  def down
    ActiveRecord::ConnectionAdapters::CipherStashPG.uninstall
  end
end
' > $migration

asdf exec rails db:migrate


echo
echo
echo 'About to generate and run migration for adding encrypted columns.'
echo
printf 'Press enter to continue: '
read

asdf exec rails generate migration AddProtectEncryptedColumnsToPatientsTable

migration=$(find db/migrate -iname '*add_protect_encrypted_columns_to_patients_table.rb')

echo 'class AddProtectEncryptedColumnsToPatientsTable < ActiveRecord::Migration[7.0]
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
' > $migration

asdf exec rails db:migrate

echo
echo
echo 'About to run cipherstash:migrate[Patient]'
echo
printf 'Press enter to continue: '
read

asdf exec rails 'cipherstash:migrate[Patient]'

echo
echo
echo 'About to update Patient model.'
echo
printf 'Press enter to continue: '
read

echo "class Patient < ApplicationRecord
  # This will be removed when Protect GA is released.
  self.ignored_columns = %w[wildcardoperatorfix]
  # This will be removed when Protect GA is released.
  def self.columns
    super.reject {|column| column.name.starts_with?('__')}
  end
end
" > app/models/patient.rb


echo
echo
echo 'About to update dataset.yml to use encrypted-duplicate mode instead of palintext-duplicate, and upload again.'
echo
printf 'Press enter to continue: '
read

# .ruby-version update
sed -i.bak "s/plaintext-duplicate/encrypted-duplicate/" dataset.yml
/bin/rm -f dataset.yml.bak

stash upload-config --file dataset.yml --client-id $CS_CLIENT_ID --client-key $CS_CLIENT_KEY

echo
echo
echo 'About to create a new Patient record via rails console (Grace Hopper)'
echo
printf 'Press enter to continue: '
read

echo 'Patient.create(full_name: "Grace Hopper", email: "grace@hopper.example", dob: Date.parse("9 December 1906"))' | asdf exec rails c

printf 'Press enter to continue: '
read

echo
echo
echo 'Going to query psql to check columns are encrypted.'
echo
printf 'Press enter to continue: '
read

echo 'SELECT __full_name_encrypted, __full_name_match, __full_name_ore FROM patients LIMIT 5;' | psql rails_demo


echo
echo
echo 'About to query for the newly-created Patient record via rails console (Grace Hopper)'
echo
printf 'Press enter to continue: '
read

echo 'Patient.where(email: "grace@hopper.example")' | asdf exec rails c

printf 'Press enter to continue to ordering by full name: '
read

echo 'Patient.order(:full_name)' | asdf exec rails c

printf 'Press enter to continue: '
read

echo
echo
echo 'Press enter to start rails server.'
echo 'Go to http://localhost:3000/admin/patients and browse through some records.'
echo 'Feel free to update or create records'
echo "Press CTL-C to exit once you're done."
echo
printf 'Press enter to start rails server and continue: '

read

asdf exec rails s

