class ChangeDefaultValueForHighestResolutionNumber < ActiveRecord::Migration[6.0]
  def change
    change_column_default :categories, :highest_resolution_number, 0
  end
end
