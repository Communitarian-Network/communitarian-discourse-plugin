# frozen_string_literal: true

class AddResolutionColumnToTopic < ActiveRecord::Migration[6.0]
  def up
    add_column :topics, :is_resolution, :boolean, default: false

    resolution_topic_ids = TopicCustomField.where(name: :is_resolution, value: "t").select(:topic_id)
    Topic.where(id: resolution_topic_ids).update_all(is_resolution: true)
  end

  def down
    remove_column :topics, :is_resolution
  end
end
