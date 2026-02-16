# 既存のサンプルデータを削除（再実行できるように）
Character.where(user_id: nil).destroy_all
#0_other/1_attack/2_dodge/3_masialarts/4_grapple
samples = [
  {
    name: "夜家 真来",
    db: "+1d4",
    stats: { str: 11, con: 12, pow: 11, dex: 15, app: 10, siz: 12, int: 14, edu: 15 },
    skills: [
      { name: "回避", success: 85, category: :dodge },
      { name: "投擲", success: 75, category: :attack }
    ],
    attacks: [
      { show_name: "石を投げる", weapon_name: "石", base_damage: "1d4", can_apply_db: false, can_apply_ma: false, skill_name: "投擲" }
    ]
  },
  {
    name: "マーシャル 敦子",
    db: "+1d4",
    stats: { str: 16, con: 15, pow: 10, dex: 8, app: 9, siz: 16, int: 9, edu: 12 },
    skills: [
      { name: "回避", success: 30, category: :dodge },
      { name: "こぶし", success: 80, category: :attack },
      { name: "キック", success: 75, category: :attack },
      { name: "マーシャルアーツ", success: 40, category: :masialarts }
    ],
    attacks: [
      { show_name: "こぶし", weapon_name: "こぶし", base_damage: "1d3", can_apply_db: true, can_apply_ma: true, skill_name: "こぶし" },
      { show_name: "キック", weapon_name: "キック", base_damage: "1d6", can_apply_db: true, can_apply_ma: true, skill_name: "キック" }
    ]
  },
  {
    name: "超毒 嘆代",
    db: "0",
    stats: { str: 9, con: 9, pow: 13, dex: 18, app: 9, siz: 11, int: 16, edu: 15 },
    skills: [
      { name: "回避", success: 65, category: :dodge },
      { name: "投擲", success: 80, category: :attack },
      { name: "応急手当", success: 70, category: :other }
    ],
    attacks: [
      { show_name: "蛇毒瓶", weapon_name: "瓶", base_damage: "1d4", can_apply_db: false, can_apply_ma: false, skill_name: "投擲" 
      condition_type: :poisoned, duration: 1, effect_value: 10}
    ]
  }
  {
    name: "徳井 研樹",
    db: "0",
    stats: { str: 9, con: 10, pow: 13, dex: 11, app: 14, siz: 15, int: 16, edu: 15 },
    skills: [
      { name: "回避", success: 30, category: :dodge },
      { name: "拳銃", success: 80, category: :attack },
      { name: "組み付き", success: 40, category: :grapple }
    ],
    attacks: [
      { show_name: "38口径リボルバー", weapon_name: "拳銃", base_damage: "1d10", can_apply_db: false, can_apply_ma: false, skill_name: "拳銃" }
      { show_name: "組み付き", weapon_name: "組み付き", base_damage: "1d6", can_apply_db: true, can_apply_ma: false, skill_name: "組み付き",condition_type: :grappling, duration: 1, effect_value: nil }
    ]
  }
]

samples.each do |data|
  char = Character.create!(
    name: data[:name],
    user_id: nil,
    damage_bonus: data[:db],
    original_txt: "Sample data: #{data[:name]}"
  )

  # 能力値の登録
  data[:stats].each do |name, value|
    char.characteristics.create!(name: name, value: value)
  end

  # 技能の登録
  skill_map = {}
  data[:skills].each do |skill_data|
    skill = char.skills.create!(skill_data)
    skill_map[skill.name] = skill.id
  end

  # 攻撃手段の登録 (Attack_methods)
  if data[:attacks]
    data[:attacks].each do |atk|
      char.attack_methods.create!(
        skill_id: skill_map[atk[:skill_name]],
        show_name: atk[:show_name],
        weapon_name: atk[:weapon_name],
        base_damage: atk[:base_damage],
        can_apply_db: atk[:can_apply_db],
        can_apply_ma: atk[:can_apply_ma]
      )
    end
  end
end
