# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

enabled_site_setting :communitarian_enabled

register_asset "stylesheets/common/resolution-form.scss"

PLUGIN_NAME ||= "communitarian"

load File.expand_path("lib/communitarian/engine.rb", __dir__)

after_initialize do
  Topic.register_custom_field_type("is_resolution", :boolean)

  # using Discourse "Topic Created" event to trigger a save.
  # `opts[]` is how you pass the data back from the frontend into Rails
  on(:topic_created) do |topic, opts, user|
    if opts[:is_resolution] != nil
      topic.custom_fields["is_resolution"] = opts[:is_resolution]
      topic.save_custom_fields(true)
    end
  end
end
