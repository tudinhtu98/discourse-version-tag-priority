# frozen_string_literal: true

DiscourseVersionTagPriorityModule::Engine.routes.draw do
  put '/version_tags/change_topic/:topic_id' => 'version_tags#change_topic'
  post '/version_tags/move_all_topic' => 'version_tags#move_all_topic'
  post '/version_tags/change_old_activity' => 'version_tags#change_old_activity'
end

Discourse::Application.routes.draw { mount ::DiscourseVersionTagPriorityModule::Engine, at: "" }

Discourse::Application.routes.append do
  get '/version_tags/filter/search' => 'tags#search_version'
end