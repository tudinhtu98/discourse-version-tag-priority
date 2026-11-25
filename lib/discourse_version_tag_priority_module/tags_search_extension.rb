# frozen_string_literal: true

module DiscourseVersionTagPriorityModule
  module TagsSearchExtension
    private

    def visible_tags(guardian)
      tags = super
      prefix = version_tag_prefix
      return tags if prefix.blank?

      tags.where("NOT starts_with(tags.name, ?)", prefix)
    end

    def search_tags(params:, category:, guardian:)
      prefix = version_tag_prefix
      return super if prefix.blank?

      filter_options = params.filter_options.merge(category: category, exclude_prefix: prefix)

      if (recent_tag_ids = recent_priority_tag_ids(params:, guardian:))
        filter_options[:order_recent_tag_ids] = recent_tag_ids
      end

      tags_with_counts, filter_result_context =
        DiscourseVersionTagging.filter_allowed_tags(guardian, **filter_options, with_context: true)

      tags_with_counts = Tag.with_localizations(tags_with_counts)

      context[:tags] = TagsController.tag_counts_json(tags_with_counts, guardian)
      context[:required_tag_group] = filter_result_context[:required_tag_group]
      context[:forbidden] = nil
      context[:forbidden_message] = nil
    end

    def version_tag_prefix
      return nil unless SiteSetting.discourse_version_tag_priority_enabled

      SiteSetting.discourse_version_tag_priority_symbol.presence
    end
  end
end
