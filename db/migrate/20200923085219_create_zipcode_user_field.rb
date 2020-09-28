# frozen_string_literal: true

class CreateZipcodeUserField < ActiveRecord::Migration[6.0]
  def up
    UserField.create!(
      id: 123_002,
      name: "Zipcode",
      field_type: "text",
      editable: false,
      description: "Zipcode",
      required: false,
      show_on_profile: false,
      show_on_user_card: false,
      position: 2
    )
  end

  def down
    UserField.where(id: [123_002]).destroy_all
  end
end
