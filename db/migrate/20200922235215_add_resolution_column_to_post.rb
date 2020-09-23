# frozen_string_literal: true

class AddResolutionColumnToPost < ActiveRecord::Migration[6.0]
  def up
    add_column :posts, :is_resolution, :boolean, default: false

    resolution_post_ids = PostCustomField.where(name: :is_resolution, value: "t").select(:post_id)
    Post.where(id: resolution_post_ids).update_all(is_resolution: true)
  end

  def down
    remove_column :posts, :is_resolution
  end
end
