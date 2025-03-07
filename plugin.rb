# frozen_string_literal: true

# name: discourse-version-tag-priority
# about: prioritize version tags
# meta_topic_id: TODO
# version: 1.0.0
# authors: tudinhtu98
# url: https://github.com/tudinhtu98/discourse-version-tag-priority
# required_version: 2.7.0

enabled_site_setting :discourse_version_tag_priority_enabled

register_asset 'stylesheets/common.scss'

module ::DiscourseVersionTagPriorityModule
  PLUGIN_NAME = "discourse-version-tag-priority"
end

require_relative "lib/discourse_version_tag_priority_module/engine"

add_admin_route 'version_tag_settings.title', 'version-tag'

Discourse::Application.routes.append do
  get '/admin/plugins/version-tag' => 'admin/plugins#index', constraints: StaffConstraint.new
end

after_initialize do
  # Code which should run after Rails has finished booting
  [
    '../app/controllers/tags_controller.rb',
    '../lib/discourse_version_tagging.rb',
  ].each { |path| load File.expand_path(path, __FILE__) }
end
