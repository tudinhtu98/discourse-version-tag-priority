# frozen_string_literal: true

DiscourseVersionTagPriorityModule::Engine.routes.draw do
  # get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseVersionTagPriorityModule::Engine, at: "discourse-version-tag-priority" }
