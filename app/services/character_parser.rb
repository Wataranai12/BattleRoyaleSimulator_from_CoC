class CharacterParser
  def initialize(text)
    @text = text
  end

  def parse
    {
      name: extract_name,
      damage_bonus: extract_db,
      characteristics_attributes: extract_characteristics,
      skills_attributes: extract_skills
    }
  end

  private

  # 名前
  def extract_name
    @text.match(/名前:\s*(.+?)(?:\s*\(|$)/)&.[](1)&.strip
  end

  # DB +1D4 を抽出
  def extract_db
    @text.match(/DB\s*([^\n\r]+)/)&.[](1)&.strip
  end

  # 能力値（STR, CON...）を抽出
  def extract_characteristics
    stats = []
    %w(STR CON POW DEX APP SIZ INT EDU).each do |s|
      # 数値が並んでいる行から、2番目の「能力値」の数字を取得
      pattern = /#{s}\s+(\d+)\s+(\d+)/
      if match = @text.match(pattern)
        stats << { name: s.downcase, value: match[2].to_i }
      end
    end
    stats
  end

  # 技能を抽出
  def extract_skills
    skills = []
    # 各行をループし、合計値（数字）が含まれる行を探す
    @text.each_line do |line|
      # 例: 「回避   89   34 ...」という並びから技能名と合計値を抽出
      if match = line.match(/^([^\s　]+)\s+(\d+)\s+(\d+)/)
        name = match[1]
        next if %w(技能名 職業ポイント 興味ポイント).include?(name) # ヘッダー除外
        
        success_rate = match[2].to_i
        category = determine_category(name)
        
        skills << { name: name, success: success_rate, category: category }
      end
    end
    skills
  end

  # 技能名からER図のcategoryを判定
  def determine_category(name)
    case name
    when /回避/ then 'dodge'
    when /キック|こぶし|頭突き|ナイフ|拳銃/ then 'attack'
    when /マーシャルアーツ/ then 'martialarts'
    when /組み付き/ then 'grapple'
    else 'other'
    end
  end
end
