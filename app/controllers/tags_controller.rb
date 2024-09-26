# frozen_string_literal: true

class TagsController
    def search
        filter_params = {
          for_input: params[:filterForInput],
          selected_tags: params[:selected_tags],
          exclude_synonyms: params[:excludeSynonyms],
          exclude_has_synonyms: params[:excludeHasSynonyms],
        }
    
        if limit = fetch_limit_from_params(default: nil, max: SiteSetting.max_tag_search_results)
          filter_params[:limit] = limit
        end
    
        filter_params[:category] = Category.find_by_id(params[:categoryId]) if params[:categoryId]
    
        if !params[:q].blank?
          clean_name = DiscourseTagging.clean_tag(params[:q])
          filter_params[:term] = clean_name
          filter_params[:order_search_results] = true
        else
          # Order by popularity with specific condition when q is empty
          version_tag_prefix = SiteSetting.discourse_version_tag_priority_symbol
        #   filter_params[:order_popularity] = true
          filter_params[:term] = "#{version_tag_prefix}"
          filter_params[:order_search_results] = true
        end
    
        tags_with_counts, filter_result_context =
          DiscourseTagging.filter_allowed_tags(guardian, **filter_params, with_context: true)
        
        tags = self.class.tag_counts_json(tags_with_counts, guardian)
        puts "tags_with_counts: #{tags_with_counts}"
    
        json_response = { results: tags }
    
        if clean_name && !tags.find { |h| h[:id].downcase == clean_name.downcase } &&
             tag = Tag.where_name(clean_name).first
          # filter_allowed_tags determined that the tag entered is not allowed
          json_response[:forbidden] = params[:q]
    
          if filter_params[:exclude_synonyms] && tag.synonym?
            json_response[:forbidden_message] = I18n.t(
              "tags.forbidden.synonym",
              tag_name: tag.target_tag.name,
            )
          elsif filter_params[:exclude_has_synonyms] && tag.synonyms.exists?
            json_response[:forbidden_message] = I18n.t(
              "tags.forbidden.has_synonyms",
              tag_name: tag.name,
            )
          else
            category_names = tag.categories.where(id: guardian.allowed_category_ids).pluck(:name)
            category_names +=
              Category
                .joins(tag_groups: :tags)
                .where(id: guardian.allowed_category_ids, "tags.id": tag.id)
                .pluck(:name)
    
            if category_names.present?
              category_names.uniq!
              json_response[:forbidden_message] = I18n.t(
                "tags.forbidden.restricted_to",
                count: category_names.count,
                tag_name: tag.name,
                category_names: category_names.join(", "),
              )
            else
              json_response[:forbidden_message] = I18n.t(
                "tags.forbidden.in_this_category",
                tag_name: tag.name,
              )
            end
          end
        end
    
        if required_tag_group = filter_result_context[:required_tag_group]
          json_response[:required_tag_group] = required_tag_group
        end
    
        render json: json_response
    end
end