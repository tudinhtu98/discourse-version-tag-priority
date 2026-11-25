# frozen_string_literal: true

module DiscourseVersionTagging
  TAG_GROUP_RESTRICTIONS_SQL = <<~SQL
    tag_group_restrictions AS (
      SELECT t.id as tag_id, tgm.id as tgm_id, tg.id as tag_group_id, tg.parent_tag_id as parent_tag_id,
        tg.one_per_topic as one_per_topic
      FROM tags t
      LEFT OUTER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      LEFT OUTER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
    )
  SQL

  CATEGORY_RESTRICTIONS_SQL = <<~SQL
    category_restrictions AS (
      SELECT t.id as tag_id, ct.id as ct_id, ct.category_id as category_id, NULL AS category_tag_group_id
      FROM tags t
      INNER JOIN category_tags ct ON t.id = ct.tag_id /*and_name_like*/

      UNION

      SELECT t.id as tag_id, ctg.id as ctg_id, ctg.category_id as category_id, ctg.tag_group_id AS category_tag_group_id
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN category_tag_groups ctg ON tgm.tag_group_id = ctg.tag_group_id
    )
  SQL

  PERMITTED_TAGS_SQL = <<~SQL
    permitted_tag_groups AS (
      SELECT tg.id as tag_group_id, tgp.group_id as group_id, tgp.permission_type as permission_type
      FROM tags t
      INNER JOIN tag_group_memberships tgm ON tgm.tag_id = t.id /*and_name_like*/
      INNER JOIN tag_groups tg ON tg.id = tgm.tag_group_id
      INNER JOIN tag_group_permissions tgp
      ON tg.id = tgp.tag_group_id /*and_group_ids*/
      AND tgp.permission_type = #{TagGroupPermission.permission_types[:full]}
    )
  SQL

  # Extends DiscourseTagging.filter_allowed_tags with prefix filtering and created_at sorting
  # for version tags while preserving v2026.7.6 tag selection, slug, localization, and visibility rules.
  def self.filter_allowed_tags(guardian, opts = {})
    selected_tag_ids =
      if opts[:selected_tag_ids].present?
        opts[:selected_tag_ids].map(&:to_i)
      elsif opts[:selected_tags].present?
        Tag.where_name(opts[:selected_tags]).pluck(:id)
      else
        []
      end

    category = opts[:category]
    category_has_tag_groups = category && category.tag_groups.count > 0
    category_has_restricted_tags = category_has_tag_groups || (category && category.tags.count > 0)

    filter_for_non_admin = !guardian.nil? && !guardian.is_admin?
    builder_params = {}
    builder_params[:selected_tag_ids] = selected_tag_ids unless selected_tag_ids.empty?

    if opts[:order_recent_tag_ids].present?
      builder_params[:order_recent_tag_ids] = opts[:order_recent_tag_ids]
    end

    sql = +"WITH #{TAG_GROUP_RESTRICTIONS_SQL}, #{CATEGORY_RESTRICTIONS_SQL}"
    if (opts[:for_input] || opts[:for_topic]) && filter_for_non_admin
      sql << ", #{PERMITTED_TAGS_SQL} "
      builder_params[:group_ids] = DiscourseTagging.permitted_group_ids(guardian)
      sql.gsub!("/*and_group_ids*/", "AND group_id IN (:group_ids)")
    end

    outer_join = category.nil? || category.allow_global_tags || !category_has_restricted_tags
    topic_count_column = Tag.topic_count_column(guardian)

    distinct_clause =
      if opts[:order_created_at]
        ""
      elsif opts[:order_recent_tag_ids].present?
        "DISTINCT ON (array_position(ARRAY[:order_recent_tag_ids]::int[], t.id), #{topic_count_column}, name)"
      elsif opts[:order_popularity]
        "DISTINCT ON (#{topic_count_column}, name)"
      elsif opts[:order_search_results] && opts[:term].present?
        "DISTINCT ON (lower(name) = lower(:cleaned_term), #{topic_count_column}, name)"
      else
        ""
      end

    sql << <<~SQL
      SELECT #{distinct_clause} t.id, t.name, t.slug, t.#{topic_count_column}, t.pm_topic_count, t.description,
        tgr.tgm_id as tgm_id, tgr.tag_group_id as tag_group_id, tgr.parent_tag_id as parent_tag_id,
        tgr.one_per_topic as one_per_topic, t.target_tag_id
      FROM tags t
      INNER JOIN tag_group_restrictions tgr ON tgr.tag_id = t.id
      #{outer_join ? "LEFT OUTER" : "INNER"}
        JOIN category_restrictions cr ON t.id = cr.tag_id AND (tgr.tag_group_id = cr.category_tag_group_id OR cr.category_tag_group_id IS NULL)
      /*where*/
      /*order_by*/
      /*limit*/
    SQL

    builder = DB.build(sql)

    if !opts[:for_topic] && builder_params[:selected_tag_ids]
      builder.where("id NOT IN (:selected_tag_ids)")
    end

    if opts[:only_tag_names]
      builder.where("LOWER(name) IN (:only_tag_names)")
      builder_params[:only_tag_names] = opts[:only_tag_names].map(&:downcase)
    end

    if opts[:only_prefix].present?
      builder_params[:only_prefix] = opts[:only_prefix]
      builder.where("starts_with(t.name, :only_prefix)")
    end

    if opts[:exclude_prefix].present?
      builder_params[:exclude_prefix] = opts[:exclude_prefix]
      builder.where("NOT starts_with(t.name, :exclude_prefix)")
    end

    if opts[:for_input]
      builder.where(
        (
          if builder_params[:selected_tag_ids]
            "tgm_id IS NULL OR parent_tag_id IS NULL OR parent_tag_id IN (:selected_tag_ids)"
          else
            "tgm_id IS NULL OR parent_tag_id IS NULL"
          end
        ),
      )
    end

    if category && category_has_restricted_tags
      builder.where(
        category.allow_global_tags ? "category_id = ? OR category_id IS NULL" : "category_id = ?",
        category.id,
      )
    elsif category || opts[:for_input] || opts[:for_topic]
      builder.where("category_id IS NULL")
    end

    if filter_for_non_admin && (opts[:for_input] || opts[:for_topic])
      builder.where(
        "tag_group_id IS NULL OR tag_group_id IN (SELECT tag_group_id FROM permitted_tag_groups)",
      )
    end

    term = opts[:term]
    if term.present?
      builder_params[:cleaned_term] = term

      if opts[:term_type] == DiscourseTagging.term_types[:starts_with]
        name_match_sql = "starts_with(LOWER(t.name), LOWER(:cleaned_term))"
      else
        name_match_sql = "position(LOWER(:cleaned_term) IN LOWER(t.name)) <> 0"
      end

      localized_tag_ids =
        DiscourseTagging.tag_ids_matching_localizations(term, term_type: opts[:term_type])
      if localized_tag_ids.present?
        builder_params[:localized_tag_ids] = localized_tag_ids
        name_match_sql = "(#{name_match_sql} OR t.id IN (:localized_tag_ids))"
      end

      builder.where(name_match_sql)
      sql.gsub!("/*and_name_like*/", "AND #{name_match_sql}")
    else
      sql.gsub!("/*and_name_like*/", "")
    end

    required_tag_ids = nil
    required_category_tag_group = nil
    if opts[:for_input] && category&.category_required_tag_groups.present? &&
         (filter_for_non_admin || term.blank?)
      category.category_required_tag_groups.each do |crtg|
        group_tags = crtg.tag_group.tags.pluck(:id)
        next if (group_tags & selected_tag_ids).size >= crtg.min_count
        if filter_for_non_admin || group_tags.size >= opts[:limit].to_i
          required_category_tag_group = crtg
          required_tag_ids = group_tags
          builder.where("id IN (?)", required_tag_ids)
        end
        break
      end
    end

    if filter_for_non_admin
      builder.where("t.id IN (#{DiscourseTagging.visible_tags(guardian).select(:id).to_sql})")
    end

    if builder_params[:selected_tag_ids] && (opts[:for_input] || opts[:for_topic])
      one_tag_per_group_sql = +<<~SQL
        SELECT DISTINCT(tg.id)
          FROM tag_groups tg
        INNER JOIN tag_group_memberships tgm ON tg.id = tgm.tag_group_id AND tgm.tag_id IN (?)
         WHERE tg.one_per_topic
      SQL

      query_params = [builder_params[:selected_tag_ids]]

      if category_has_tag_groups
        one_tag_per_group_sql << if category.allow_global_tags
          "AND (tg.id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id = ?) OR tg.id NOT IN (SELECT tag_group_id FROM category_tag_groups))"
        else
          "AND tg.id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id = ?)"
        end
        query_params << category.id
      end

      one_tag_per_group_ids = DB.query(one_tag_per_group_sql, *query_params).map(&:id)

      if one_tag_per_group_ids.present?
        builder.where(
          "t.id NOT IN (SELECT DISTINCT tag_id FROM tag_group_restrictions WHERE tag_group_id IN (?)) OR id IN (:selected_tag_ids)",
          one_tag_per_group_ids,
        )
      end
    end

    builder.where("target_tag_id IS NULL") if opts[:exclude_synonyms]

    if opts[:exclude_has_synonyms]
      builder.where("id NOT IN (SELECT target_tag_id FROM tags WHERE target_tag_id IS NOT NULL)")
    end

    builder.where("name NOT IN (?)", opts[:excluded_tag_names]) if opts[:excluded_tag_names]&.any?

    if opts[:limit]
      if required_tag_ids && term.blank?
        builder.limit(required_tag_ids.size)
      else
        builder.limit(opts[:limit])
      end
    end

    if opts[:order_created_at]
      builder.order_by("t.created_at DESC")
    elsif opts[:order_recent_tag_ids].present?
      builder.order_by("array_position(ARRAY[:order_recent_tag_ids]::int[], t.id) ASC NULLS LAST")
      builder.order_by("#{topic_count_column} DESC, name")
    elsif opts[:order_popularity]
      builder.order_by("#{topic_count_column} DESC, name")
    elsif opts[:order_search_results] && term.present?
      builder.order_by("lower(name) = lower(:cleaned_term) DESC, #{topic_count_column} DESC, name")
    end

    result = builder.query(builder_params).uniq { |t| t.id }

    if opts[:with_context]
      context = {}
      if required_category_tag_group &&
           (
             !filter_for_non_admin ||
               TagGroup.visible(guardian).exists?(id: required_category_tag_group.tag_group_id)
           )
        context[:required_tag_group] = {
          name: required_category_tag_group.tag_group.name,
          min_count: required_category_tag_group.min_count,
        }
      end
      [result, context]
    else
      result
    end
  end
end
