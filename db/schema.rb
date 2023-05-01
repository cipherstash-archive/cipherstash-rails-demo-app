# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_03_23_021021) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "patients", force: :cascade do |t|
    t.string "full_name"
    t.string "email"
    t.date "dob"
    t.float "weight"
    t.string "allergies"
    t.string "medications"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["__allergies_match"], name: "index_patients_on___allergies_match", using: :gin
    t.index ["__allergies_ore"], name: "index_patients_on___allergies_ore"
    t.index ["__dob_ore"], name: "index_patients_on___dob_ore"
    t.index ["__email_match"], name: "index_patients_on___email_match", using: :gin
    t.index ["__email_ore"], name: "index_patients_on___email_ore"
    t.index ["__full_name_match"], name: "index_patients_on___full_name_match", using: :gin
    t.index ["__full_name_ore"], name: "index_patients_on___full_name_ore"
    t.index ["__medications_match"], name: "index_patients_on___medications_match", using: :gin
    t.index ["__medications_ore"], name: "index_patients_on___medications_ore"
    t.index ["__weight_ore"], name: "index_patients_on___weight_ore"
  end

end
