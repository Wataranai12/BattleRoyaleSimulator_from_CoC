# frozen_string_literal: true

DefaultCondition.destroy_all
AttackMethod.destroy_all
Skill.destroy_all
Characteristic.destroy_all
Character.destroy_all
Battle.destroy_all
BattleParticipant.destroy_all
BattleLog.destroy_all
Condition.destroy_all
# enum定義（モデルに合わせること）
# Skill category: other: 0, dodge: 1, attack: 2, martialarts: 3, grapple: 4
# AttackMethod condition_type: grappling: 0, grappled: 1, stunned: 2, poisoned: 3, shocked: 4

samples = [
  {
    name: '夜家 真来',
    max_hp: 12,
    db: '+1d4',
    stats: { str: 11, con: 12, pow: 11, dex: 15, app: 10, siz: 12, int: 14, edu: 15 },
    skills: [
      { name: '回避', success: 85, category: 'dodge' },
      { name: '投擲', success: 75, category: 'attack' }
    ],
    attacks: [
      {
        show_name: '石を投げる',
        weapon_name: '石',
        base_damage: '1d4',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '投擲'
      }
    ]
  },
  {
    name: 'マーシャル 敦子',
    max_hp: 16,
    db: '+1d4',
    stats: { str: 16, con: 15, pow: 10, dex: 8, app: 9, siz: 16, int: 9, edu: 12 },
    skills: [
      { name: '回避', success: 30, category: 'dodge' },
      { name: 'こぶし', success: 80, category: 'attack' },
      { name: 'キック', success: 75, category: 'attack' },
      { name: 'マーシャルアーツ', success: 40, category: 'martialarts' }
    ],
    attacks: [
      {
        show_name: 'こぶし',
        weapon_name: 'こぶし',
        base_damage: '1d3',
        can_apply_db: true,
        can_apply_ma: true,
        skill_name: 'こぶし'
      },
      {
        show_name: 'キック',
        weapon_name: 'キック',
        base_damage: '1d6',
        can_apply_db: true,
        can_apply_ma: true,
        skill_name: 'キック'
      }
    ]
  },
  {
    name: '超毒 嘆代',
    max_hp: 10,
    db: '0',
    stats: { str: 9, con: 9, pow: 13, dex: 18, app: 9, siz: 11, int: 16, edu: 15 },
    skills: [
      { name: '回避', success: 50, category: 'dodge' },
      { name: '投擲', success: 80, category: 'attack' },
      { name: '応急手当', success: 70, category: 'other' }
    ],
    attacks: [
      {
        show_name: '蛇毒瓶',
        weapon_name: '瓶',
        base_damage: '1d4',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '投擲',
        inflicts_condition: { condition_type: :poisoned, duration: 1, effect_value: 10 }
      }
    ]
  },
  {
    name: '徳井 研樹',
    max_hp: 13,
    db: '0',
    stats: { str: 9, con: 10, pow: 13, dex: 11, app: 14, siz: 15, int: 16, edu: 15 },
    skills: [
      { name: '回避', success: 30, category: 'dodge' },
      { name: '拳銃', success: 80, category: 'attack' },
      { name: '組み付き', success: 40, category: 'grapple' }
    ],
    attacks: [
      {
        show_name: '38口径リボルバー',
        weapon_name: '拳銃',
        base_damage: '1d10',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '拳銃'
      },
      {
        show_name: '組み付き',
        weapon_name: '組み付き',
        base_damage: '0',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '組み付き',
        inflicts_condition: { condition_type: :grappling, duration: 1, effect_value: nil }
      }
    ]
  }
]

# ─────────────────────────────────────────────
# 登録処理
# ─────────────────────────────────────────────
samples.each do |data|
  char = Character.create!(
    name: data[:name],
    is_sample: true,
    damage_bonus: data[:db],
    max_hp: data[:max_hp],
    original_txt: "Sample data: #{data[:name]}"
  )

  # 能力値の登録
  data[:stats].each do |name, value|
    char.characteristics.create!(name: name.to_s, value: value)
  end

  # 技能の登録（スキル名 → スキルオブジェクトのマップを作成）
  skill_map = {}
  data[:skills].each do |skill_data|
    skill = char.skills.create!(
      name: skill_data[:name],
      success: skill_data[:success],
      category: skill_data[:category]
    )
    skill_map[skill.name] = skill
  end

  # 攻撃手段の登録
  next unless data[:attacks]

  data[:attacks].each do |atk|
    # 状態異常データを取り出す（存在する場合）
    condition_data = atk[:inflicts_condition]

    # 対応するスキルを取得
    skill = skill_map[atk[:skill_name]]
    unless skill
      puts "Warning: Skill '#{atk[:skill_name]}' not found for #{char.name}"
      next
    end

    # AttackMethod を作成
    attack_method = char.attack_methods.create!(
      skill: skill,
      show_name: atk[:show_name],
      weapon_name: atk[:weapon_name],
      base_damage: atk[:base_damage],
      can_apply_db: atk[:can_apply_db],
      can_apply_ma: atk[:can_apply_ma]
    )

    # 状態異常付与設定がある場合は DefaultCondition を作成
    next unless condition_data

    attack_method.create_default_condition!(
      condition_type: condition_data[:condition_type],
      duration: condition_data[:duration],
      effect_value: condition_data[:effect_value]
    )
  end

  puts "Created sample character: #{char.name}"
end

puts "\nSample characters created successfully!"
puts "Total: #{Character.where(is_sample: true).count} characters"
