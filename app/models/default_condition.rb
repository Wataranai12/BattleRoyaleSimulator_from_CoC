# frozen_string_literal: true

class DefaultCondition < ApplicationRecord
  belongs_to :attack_method

  enum condition_type: {
    grappling: 0,
    grappled: 1,
    stunned: 2,
    poisoned: 3,
    shocked: 4
  }
end
