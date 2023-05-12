# CipherStash Rails App Demo

This repo contains a Rails app which can be used to demonstrate how to configure CipherStash Protect for a Rails app.

The demo app is an admin view of generated fake medical data for patients.

To view the the Demo app with the completed code checkout the branch `completed-demo-app`.

## Running the Demo

### Prerequisites

- Ruby >= 3.1.3
- Rails: Follow the rails [getting started guide](https://guides.rubyonrails.org/v5.1/getting_started.html) for installing Ruby and Rails.
- [PostgreSQL](https://www.postgresql.org/download/)
- Optional: [direnv](https://direnv.net/docs/installation.html)

If you're using [asdf](https://asdf-vm.com/), we ship a `.tool-versions` you can use to set these up:

```bash
asdf install
```

### Get started

1. Install dependencies:

```bash
bundle install
```

2. Create db, run migrations and seed db with dummy patient data:

```bash
rails db:setup
```

3. Run rails server:

```bash
rails s
```

4. Go to the [patients dashboard](http://localhost:3000/admin/patients).

We now have a running Rails application to use to learn how to configure CipherStash to encrypt data.

### Install the CipherStash CLI

The CipherStash CLI is used to manage your encryption schema.

The encryption schema defines what encrypted indexes exist, and what queries you can perform on those indexes.

#### On macOS

Install via Homebrew:

```bash
brew install cipherstash/tap/stash
```

> **Note**
> 
> You will need to grant an exception in System Settings the first time you run the binary.
> 
>We will release a fix for this in Q2 2023.

#### On Linux

Download the binary for your platform:

- [Linux ARM64](https://github.com/cipherstash/cli-releases/releases/latest/download/stash-aarch64-unknown-linux-gnu)
- [Linux ARM64 musl](https://github.com/cipherstash/cli-releases/releases/latest/download/stash-aarch64-unknown-linux-musl)
- [Linux x86_64](https://github.com/cipherstash/cli-releases/releases/latest/download/stash-x86_64-unknown-linux-gnu)
- [Linux x86_64 musl](https://github.com/cipherstash/cli-releases/releases/latest/download/stash-x86_64-unknown-linux-musl)

1. Make the binary executable:
   ```bash
   # on x86_64
   chmod +x $path_to/stash-x86_64-unknown-linux-gnu

   # on ARM64
   chmod +x $path_to/stash-aarch64-unknown-linux-gnu
   ```
2. Rename the binary:
   ```bash
   # on x86_64
   mv stash-x86_64-unknown-linux-gnu stash

   # on ARM64
   mv stash-aarch64-unknown-linux-gnu stash
   ```
3. Place the binary on your `$PATH`, so you can run it.


### Get a CipherStash account and workspace

To use CipherStash you'll need a CipherStash account and workspace.

You can signup from the CLI:

```bash
stash signup
```

> Your browser will open to [https://cipherstash.com/signup/stash](https://cipherstash.com/signup/stash) where you can sign up with either your GitHub account, or a standalone email.

### Install the CipherStash database driver

The CipherStash database driver transparently maps SQL statements to encrypted database columns.

We need to add it to the Rails app, and tell Rails to use it.

Add the `activerecord-cipherstash-pg-adapter` to your Gemfile:

```ruby
gem "activerecord-cipherstash-pg-adapter"
```

Remove (or comment out as below) the `pg` gem from your Gemfile.

```
# gem "pg", "~> 1.1"
```

Run `bundle install`.

And update the default adapter settings in `config/database.yml` with `postgres_cipherstash`:

```yaml
default: &default
  adapter: postgres_cipherstash
```

### Log in

Make sure `stash` is logged in:

```bash
stash login
```

This will save a special token `stash` will use for talking to CipherStash.

### Create a dataset

Next, we need to create a dataset for tracking what data needs to be encrypted.

A dataset holds configuration for one or more database tables that contain data to be encrypted.

Create our first dataset by running:

```
stash datasets create patients --description "Data about patients"
```

The output will look like this:

```
Dataset created:
ID         : <a UUID style ID>
Name       : patients
Description: Data about patients
```

Note down the dataset ID, as you'll need it in step 3.

### Create a client

Next we need to create a client.

A client allows an application to programatically access a dataset.

A dataset can have many clients (for example, different applications working with the same data), but a client belongs to exactly one dataset.

Use the dataset ID from step 2 to create a client (making sure you substitute your own dataset ID):

```
stash clients create --dataset-id $DATASET_ID "Rails app"
```

The output will look like this:

```
Client created:
Client ID  : <a UUID style ID>
Name       : Rails
Description:
Dataset ID : <your provided dataset ID>

#################################################
#                                               #
#  Copy and store these credentials securely.   #
#                                               #
#  THIS IS THE LAST TIME YOU WILL SEE THE KEY.  #
#                                               #
#################################################

Client ID          : <a UUID style ID>

Client Key [hex]   : <a long hex string>
```

Note down the client key somewhere safe, like a password vault.
You will only ever see this credential once.
This is your personal key, and you should not share it.

Set these in your [Rails credentials](https://guides.rubyonrails.org/security.html#custom-credentials) file:

```yaml
cipherstash:
  client_id:
  client_key:
```

Or set these as environment variables in a `.envrc` file using the below variable names:

```bash
export CS_CLIENT_KEY=
export CS_CLIENT_ID=
```

If you are using direnv run:

```bash
direnv allow
```

If you're not you can export the variables by running:

```bash
source .envrc
```

### Push the dataset configuration

Now we need to configure what columns are encrypted, and what indexes we want on those columns.

This configuration is used by the CipherStash driver to transparently rewrite your app's SQL queries to use the underlying encrypted columns.

Our demo rails app has a schema that looks like this:

```ruby
class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.string :full_name
      t.string :email
      t.date :dob
      t.float :weight
      t.string :allergies
      t.string :medications

      t.timestamps
    end
  end
end
```

We will want to encrypt all columns, as they contain sensitive information.

We do this with a configuration file which is in the root of the rails demo titled `dataset.yml`:

This configuration file defines two types of encrypted indexes for the columns we want to protect:

- A `match` index on the `full_name`, `email`, `allergies` and `medications` columns, for full text matches
- A `ore` index on the `full_name`, `email`, `dob` and `weight` columns, for sorting and range queries

Now we push this configuration to CipherStash:

```bash
stash datasets config upload --file dataset.yml --client-id $CS_CLIENT_ID --client-key $CS_CLIENT_KEY
```

### Add and apply migrations

The first migration to run, is the install of the Protect custom types into your database.

This migration adds in the custom types `ore_64_8_v1` and `ore_64_8_v1_term`.

- `ore_64_8_v1` is used for `string` and `text` types.
- `ore_64_8_v1_term` is used for non string types.

We do this by creating a Rails migration:

```
rails generate migration AddProtectDatabaseExtensions
```

And adding the following code:

```ruby
class AddProtectDatabaseExtensions < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::ConnectionAdapters::CipherStashPG.install
  end

  def down
    ActiveRecord::ConnectionAdapters::CipherStashPG.uninstall
  end
end
```

Apply the migration:

```bash
rails db:migrate
```

The CipherStash driver works by rewriting your app's SQL queries to use the underlying encrypted columns.

To set up those encrypted columns, generate another Rails migration:

```bash
rails generate migration AddProtectEncryptedColumnsToPatientsTable
```

And add the following code:

```ruby
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
```

The `_encrypted` columns are the encrypted values, and the `_match` and `_ore` columns are the encrypted indexes.

Apply the migration:

```bash
rails db:migrate
```

### Encrypt the sensitive data

Now we have the necessary database structure in place, it's time to encrypt your data.

Using bash:

```bash
rails cipherstash:migrate[Patient]
```

Using zsh:

```zsh
rails cipherstash:migrate\[Patient\]
```

This will pull the unencrypted data, encrypt it, and write it back to the new columns.

### Update your model

Add the below to the Patient model.

```ruby
class Patient < ApplicationRecord
  # This will be removed when Protect GA is released.
  self.ignored_columns = %w[wildcardoperatorfix]
end
```

This is a temporary fix to enable CipherStash to work.

We intend to ship a fix for this in Q2 2023

### Test querying records via Rails console

The provided CipherStash configuration in the `dataset.yml` file sets all columns to the `plaintext-duplicate` mode.

In this mode, all data is read from the plaintext fields, but writes will save both plaintext and ciphertext.

To test that queries are working properly, change all columns in the `dataset.yml` to use `encrypted-duplicate` mode.

```yaml
mode: encrypted-duplicate
```

In this mode all data is read from ciphertext fields and writes will save both plaintext and ciphertext.

Push this configration to CipherStash:

```bash
stash datasets config upload --file dataset.yml --client-id $CS_CLIENT_ID --client-key $CS_CLIENT_KEY
```

_NOTE:_

_The Rails demo app uses [Active Admin](https://activeadmin.info/), which uses a library called Ransack for the filters on the side of the dashboard view._

_So the filters continue to work when reading encrypted fields, we need to update the Active Admin filters._

Uncomment the below in the `patients.rb` file:

```ruby
# app/admin/patients.rb

  filter :dob, as: :date_range
  filter :weight

  filter :full_name_filter,
  as: :string,
  label: 'Full name',
  filters: [:contains, :equals]

  filter :email_filter,
  as: :string,
  label: 'Email',
  filters: [:contains, :equals]

  filter :allergies_filter,
  as: :string,
  label: 'Allergies',
  filters: [:contains, :equals]

  filter :medications_filter,
  as: :string,
  label: 'Medications',
  filters: [:contains, :equals]
```

Uncomment the below in the Patient model `patient.rb`:

```ruby

  def self.full_name_filter_contains(value)
    where("full_name LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.full_name_filter_equals(value)
    where(full_name: "#{sanitize_sql_like(value)}")
  end

  def self.email_filter_contains(value)
    where("email LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.email_filter_equals(value)
    where(email: "#{sanitize_sql_like(value)}")
  end

  def self.allergies_filter_contains(value)
    where("allergies LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.allergies_filter_equals(value)
    where(allergies: "#{sanitize_sql_like(value)}")
  end

  def self.medications_filter_contains(value)
    where("medications LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.medications_filter_equals(value)
    where(medications: "#{sanitize_sql_like(value)}")
  end


  def self.ransackable_scopes(_auth_object = nil)
    %i(full_name_filter_contains full_name_filter_equals email_filter_contains email_filter_equals allergies_filter_contains allergies_filter_equals medications_filter_contains medications_filter_equals)
  end
```

Open your Rails console:

```bash
rails console
```

Create a patient:

```ruby
Patient.create(full_name: "Grace Hopper", email: "grace@hopper.example", dob: Date.parse("9 December 1906"))
```

In `psql rails_demo`, verify that the data is encrypted;

```
SELECT __full_name_encrypted, __full_name_match, __full_name_ore FROM patients LIMIT 5;
```

Now back in the Rails console, to find that new record by email address:

```ruby
Patient.where(email: "grace@hopper.example")
```

This will return a result that looks like this:

```ruby
Patient Load (0.5ms)  SELECT "users".* FROM "users" WHERE "users"."email" = ?  [["email", "grace@hopper.example"]]
=>
[#<User:0x0000000119cd47d0
  id: 1,
  full_name: "Grace Hopper",
  email: "grace@hopper.example",
  created_at: Wed, 15 Feb 2023 22:37:08.134554000 UTC +00:00,
  updated_at: Wed, 15 Feb 2022 22:37:08.134554000 UTC +00:00]
```

To order users alphabetically by name, do:

```ruby
Patient.order(:full_name)
```

### Test querying records via UI

Start your Rails server:

```bash
rails s
```

Go to the [patients dashboard](http://localhost:3000/admin/patients).

![Patient Dashboard](./public/patient-dashboard.png)

Create a patient:

- Click on new patient
- Complete patient details
- Click on `Create Patient`

Use the filters on the side to perform queries.

![Patient Filters](./public/filters.png)

### Dropping plaintext columns

Once you are sure that the app is working correctly, update the column mode to `encrypted` mode in the `dataset.yml` file.

```yaml
mode: encrypted
```

This tells the CipherStash driver to only read and write from the encrypted columns.

Push this configration to CipherStash:

```bash
stash datasets config upload --file dataset.yml --client-id $CS_CLIENT_ID --client-key $CS_CLIENT_KEY
```

In this mode all data is encrypted and plaintext columns are completely ignored.

Once you have verified that the app is working correctly, you can create a migration that drops the original columns.

```bash
rails generate migration DropPlaintextColumnsFromPatientsTable
```

And add the following code:

```ruby
class DropPlaintextColumnsFromPatientsTable < ActiveRecord::Migration[7.0]
  def change
    remove_column :patients, :full_name
    remove_column :patients, :email
    remove_column :patients, :dob
    remove_column :patients, :weight
    remove_column :patients, :allergies
    remove_column :patients, :medications
  end
end
```

> **Warning**
>
> **Once you remove the plaintext columns, anything that hasn't been encrypted will be lost.**
>
> Before you drop plaintext columns in a real-world application, it is very important that you:
>
> - Create a backup of all your data, in case you need to restore
> - Ensure all your data is encrypted, by running [the data migration rake task](#encrypt-the-sensitive-data)

Once you're sure that you're ready to drop the plaintext columns, run the migration:

Run:

```bash
rails db:migrate
```

In order for the `encrypted` mode to work after the plaintext columns have been dropped, the types of the CipherStash encrypted columns must be specified in the model.

Uncomment this in your Patient model in `app/models/patient.rb`:

```ruby
  # Note that the types of CipherStash-protected columns must be specified here in
  # order to drop the original plaintext columns and for "encrypted" mode to work.
  attribute :full_name, :string
  attribute :email, :string
  attribute :dob, :date
  attribute :weight, :float
  attribute :allergies, :string
  attribute :medications, :string
  # The rails demo uses ActiveAdmin, which uses Ransack for the filters.
  # For the dob and weight filters to continue to work, the below types need to be added to the model.
  ransacker :dob, type: :date
  ransacker :weight, type: :numeric
```

Start up the Rails server:

```bash
rails s
```

Go to the [patients dashboard](http://localhost:3000/admin/patients).

### Viewing logs of encryptions and decryptions

The CipherStash driver creates a local log of encryptions and decryptions for a given workspace in `~/.cipherstash/<your workspace id>`.

To see a real time log of cryptography operations, run:

```bash
tail -F ~/.cipherstash/*/decryptions.log
```

The above guide is also published in our [getting started guide](https://docs.cipherstash.com/tutorials/rails-getting-started/index.html).
