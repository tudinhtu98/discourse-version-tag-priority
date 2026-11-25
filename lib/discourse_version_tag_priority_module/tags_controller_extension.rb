# frozen_string_literal: true

module DiscourseVersionTagPriorityModule
  module TagsControllerExtension
    def search_version
      raise Discourse::NotFound unless SiteSetting.discourse_version_tag_priority_enabled

      version_tag_prefix = SiteSetting.discourse_version_tag_priority_symbol
      raise Discourse::NotFound if version_tag_prefix.blank?

      filter_params = {
        for_input: params[:filterForInput],
        selected_tags: params[:selected_tags],
        selected_tag_ids: params[:selected_tag_ids],
        exclude_synonyms: params[:excludeSynonyms],
        exclude_has_synonyms: params[:excludeHasSynonyms],
        only_prefix: version_tag_prefix,
      }

      if limit = fetch_limit_from_params(default: nil, max: SiteSetting.max_tag_search_results)
        filter_params[:limit] = limit
      end

      filter_params[:category] = Category.find_by_id(params[:categoryId]) if params[:categoryId]

      if params[:q].present?
        clean_name = DiscourseTagging.clean_tag(params[:q])
        filter_params[:term] = clean_name
        filter_params[:order_search_results] = true
      else
        filter_params[:order_created_at] = true
      end

      tags_with_counts, filter_result_context =
        DiscourseVersionTagging.filter_allowed_tags(guardian, **filter_params, with_context: true)

      tags_with_counts = Tag.with_localizations(tags_with_counts)
      tags = self.class.tag_counts_json(tags_with_counts, guardian)

      json_response = { results: tags }

      if clean_name && !tags.find { |h| h[:name].downcase == clean_name.downcase } &&
           Tag.where_name(clean_name).exists?
        json_response[:forbidden] = params[:q]
      end

      if required_tag_group = filter_result_context[:required_tag_group]
        json_response[:required_tag_group] = required_tag_group
      end

      render json: json_response
    end
  end
end
