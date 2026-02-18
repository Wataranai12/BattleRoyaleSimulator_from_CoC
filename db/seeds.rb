# frozen_string_literal: true

# 依存関係の深い（子供の）データから順番に削除する
DefaultCondition.destroy_all
AttackMethod.destroy_all
Skill.destroy_all
Characteristic.destroy_all
Character.where(is_sample: true).destroy_all

# enum定義（モデルに合わせること）
# category: other: 0, dodge: 1, attack: 2, martialarts: 3, grapple: 4
# condition_type: grappling: 0, grappled: 1, stunned: 2, poisoned: 3, shocked: 4

samples = [
  {
    name: '夜家 真来',
    max_hp: 12,
    db: '+1d4',
    stats: { str: 11, con: 12, pow: 11, dex: 15, app: 10, siz: 12, int: 14, edu: 15 },
    skills: [
      { name: '回避', success: 85, category: :dodge },
      { name: '投擲', success: 75, category: :attack }
    ],
    attacks: [
      {
        show_name: '石を投げる',
        weapon_name: '石',
        base_damage: '1d4',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '投擲'
        # 状態異常なし
      }
    ]
  },
  {
    name: 'マーシャル 敦子',
    max_hp: 16,
    db: '+1d4',
    stats: { str: 16, con: 15, pow: 10, dex: 8, app: 9, siz: 16, int: 9, edu: 12 },
    skills: [
      { name: '回避', success: 30, category: :dodge },
      { name: 'こぶし', success: 80, category: :attack },        # ✅ こぶしはattack
      { name: 'キック', success: 75, category: :attack },        # ✅ キックはattack
      { name: 'マーシャルアーツ', success: 40, category: :martialarts } # ✅ スペルミス修正
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
      { name: '回避', success: 65, category: :dodge },
      { name: '投擲', success: 80, category: :attack },
      { name: '応急手当', success: 70, category: :other }
    ],
    attacks: [
      {
        show_name: '蛇毒瓶',
        weapon_name: '瓶',
        base_damage: '1d4',
        can_apply_db: false,
        can_apply_ma: false,
        skill_name: '投擲',
        # ✅ 攻撃ヒット時に付与する状態異常を分離して管理
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
      { name: '回避', success: 30, category: :dodge },
      { name: '拳銃', success: 80, category: :attack },
      { name: '組み付き', success: 40, category: :grapple }
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
        base_damage: '0',                # ✅ 組み付きはダメージなし（拘束が目的）
        can_apply_db: false,             # ✅ 組み付き自体にDBは不要
        can_apply_ma: false,
        skill_name: '組み付き',
        # ✅ 命中時に grappling 状態を相手に付与
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
    is_sample: true, # ✅ user_id: nil ではなくフラグで管理
    damage_bonus: data[:db],
    max_hp: data[:max_hp],
    original_txt: "Sample data: #{data[:name]}"
  )

  # 能力値の登録
  data[:stats].each do |name, value|
    char.characteristics.create!(name: name, value: value)
  end

  # 技能の登録（スキルIDをマップで保持）
  skill_map = {}
  data[:skills].each do |skill_data|
    skill = char.skills.create!(skill_data)
    skill_map[skill.name] = skill.id
  end

  # 攻撃手段の登録
  next unless data[:attacks]

  data[:attacks].each do |atk|
    # ✅ inflicts_condition をattack_methodsデータから除外して取り出す
    condition_data = atk.delete(:inflicts_condition)

    attack_method = char.attack_methods.create!(
      skill_id: skill_map[atk[:skill_name]],
      show_name: atk[:show_name],
      weapon_name: atk[:weapon_name],
      base_damage: atk[:base_damage],
      can_apply_db: atk[:can_apply_db],
      can_apply_ma: atk[:can_apply_ma]
    )

    # ✅ 状態異常付与がある場合は Attack_method に紐づけて登録
    # （将来的に "この攻撃が命中したら condition を生成する" ための設定）
    next unless condition_data

    attack_method.create_default_condition!(condition_data)
    DefaultCondition.create!(
      attack_method: attack_method,
      condition_type: condition_data[:condition_type],
      duration: condition_data[:duration],
      effect_value: condition_data[:effect_value]
    )
  end
end
