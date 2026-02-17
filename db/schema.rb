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

ActiveRecord::Schema[7.1].define(version: 2026_02_17_081157) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attack_methods", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.bigint "skill_id", null: false
    t.string "show_name", null: false
    t.string "weapon_name", null: false
    t.string "base_damage", null: false
    t.boolean "can_apply_db", default: false
    t.boolean "can_apply_ma", default: false
    t.integer "condition_type"
    t.integer "duration"
    t.integer "effect_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_attack_methods_on_character_id"
    t.index ["skill_id"], name: "index_attack_methods_on_skill_id"
  end

  create_table "battle_logs", force: :cascade do |t|
    t.bigint "battle_id", null: false
    t.bigint "character_id"
    t.bigint "target_id"
    t.integer "round", null: false
    t.text "message", null: false
    t.string "action_type", null: false
    t.text "ai_narration"
    t.jsonb "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id"], name: "index_battle_logs_on_battle_id"
    t.index ["character_id"], name: "index_battle_logs_on_character_id"
    t.index ["target_id"], name: "index_battle_logs_on_target_id"
  end

  create_table "battle_participants", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.bigint "battle_id", null: false
    t.bigint "team_id"
    t.integer "current_hp", null: false
    t.boolean "is_active", default: true
    t.boolean "is_join", default: true
    t.integer "kills_count", default: 0
    t.integer "damage_dealt", default: 0
    t.integer "damage_taken", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id"], name: "index_battle_participants_on_battle_id"
    t.index ["character_id"], name: "index_battle_participants_on_character_id"
    t.index ["team_id"], name: "index_battle_participants_on_team_id"
  end

  create_table "battles", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "current_round", default: 0
    t.boolean "is_finished", default: false
    t.integer "battle_mode", default: 0, null: false
    t.bigint "winner_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_battles_on_user_id"
    t.index ["winner_id"], name: "index_battles_on_winner_id"
  end

  create_table "characteristics", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.string "name", null: false
    t.integer "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_characteristics_on_character_id"
  end

  create_table "characters", force: :cascade do |t|
    t.bigint "user_id"
    t.string "name", null: false
    t.string "damage_bonus"
    t.integer "max_hp"
    t.text "original_txt"
    t.boolean "is_sample", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_characters_on_user_id"
  end

  create_table "conditions", force: :cascade do |t|
    t.bigint "battle_participant_id", null: false
    t.integer "origin_participant_id"
    t.string "condition_type"
    t.integer "duration", default: 0
    t.integer "effect_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_participant_id"], name: "index_conditions_on_battle_participant_id"
    t.index ["origin_participant_id"], name: "index_conditions_on_origin_participant_id"
  end

  create_table "default_conditions", force: :cascade do |t|
    t.bigint "attack_method_id", null: false
    t.integer "condition_type"
    t.integer "duration"
    t.integer "effect_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attack_method_id"], name: "index_default_conditions_on_attack_method_id"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.string "name", null: false
    t.integer "category", null: false
    t.integer "success", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_skills_on_character_id"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "battle_id", null: false
    t.string "where_team"
    t.string "color"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id"], name: "index_teams_on_battle_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "crypted_password"
    t.string "salt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "attack_methods", "characters"
  add_foreign_key "attack_methods", "skills"
  add_foreign_key "battle_logs", "battles"
  add_foreign_key "battle_logs", "characters"
  add_foreign_key "battle_logs", "characters", column: "target_id"
  add_foreign_key "battle_participants", "battles"
  add_foreign_key "battle_participants", "characters"
  add_foreign_key "battle_participants", "teams"
  add_foreign_key "battles", "characters", column: "winner_id"
  add_foreign_key "battles", "users"
  add_foreign_key "characteristics", "characters"
  add_foreign_key "characters", "users"
  add_foreign_key "conditions", "battle_participants"
  add_foreign_key "default_conditions", "attack_methods"
  add_foreign_key "skills", "characters"
  add_foreign_key "teams", "battles"
end
