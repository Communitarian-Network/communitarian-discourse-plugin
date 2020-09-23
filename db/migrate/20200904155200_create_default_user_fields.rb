# frozen_string_literal: true

class CreateDefaultUserFields < ActiveRecord::Migration[6.0]
  def up
    UserField.create!(
      id: 123_001,
      name: "Billing Address",
      field_type: "text",
      editable: false,
      description: "Billing Address",
      required: false,
      show_on_profile: true,
      show_on_user_card: true,
      position: 1
    )

    UserField.create!(
      id: 123_002,
      name: "Zipcode",
      field_type: "text",
      editable: false,
      description: "Zipcode",
      required: false,
      show_on_profile: false,
      show_on_user_card: false,
      position: 1
    )
  end

  def down
    UserField.where(id: [123_001]).destroy_all
  end
end
