# frozen_string_literal: true
class RemoveColumnsFromTopicsTagsTagGroups < ActiveRecord::Migration[7.1]
  def change
    remove_column :topics, :is_private, :boolean if column_exists?(:topics, :is_private)
    remove_column :tags, :type_tag, :string if column_exists?(:tags, :type_tag)
    remove_column :tag_groups, :type, :string if column_exists?(:tag_groups, :type)
  end
end
