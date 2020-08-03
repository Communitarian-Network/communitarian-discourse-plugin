# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.1
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

enabled_site_setting :communitarian_enabled

add_admin_route "admin.resolutions.settings_page", "resolutions"

PLUGIN_NAME ||= 'Communitarian'
