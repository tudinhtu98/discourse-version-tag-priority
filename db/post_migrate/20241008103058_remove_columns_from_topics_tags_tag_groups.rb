# frozen_string_literal: true
class RemoveColumnsFromTopicsTagsTagGroups < ActiveRecord::Migration[7.1]
  def change
    remove_column :topics, :is_private, :boolean
    remove_column :tags, :type_tag, :string
    remove_column :tag_groups, :type, :string
  end
end
