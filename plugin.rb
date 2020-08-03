# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.1
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

enabled_site_setting :communitarian_enabled

PLUGIN_NAME ||= 'Communitarian'

after_initialize do
  [
    "../app/models/communitarian/post_delay"
  ].each { |path| require File.expand_path(path, __FILE__) }

  NewPostManager.add_handler(10) { |manager| Communitarian::PostDelay.call(manager) }
end
