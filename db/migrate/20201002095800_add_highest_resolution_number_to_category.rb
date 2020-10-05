# frozen_string_literal: true

class AddHighestResolutionNumberToCategory < ActiveRecord::Migration[6.0]
  def up
    add_column :categories, :highest_resolution_number, :integer, default: 1
  end

  def down
    remove_column :categories, :highest_resolution_number
  end
end
