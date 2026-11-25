# frozen_string_literal: true

module DiscourseVersionTagPriorityModule
  class VersionTagsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_staff, only: %i[change_topic move_all_topic change_old_activity]

    def change_topic
      topic_id = params[:topic_id]
      data = params.permit(:created_at, :updated_at, :user_id)

      topic = Topic.find_by(id: topic_id)
      return render json: { error: "Topic not found" }, status: :not_found unless topic

      if data[:user_id]
        user = User.find_by(id: data[:user_id])
        return render json: { error: "User not found" }, status: :not_found unless user
      end

      topic.assign_attributes(
        created_at: data[:created_at] || topic.created_at,
        updated_at: data[:updated_at] || topic.updated_at,
        user_id: data[:user_id] || topic.user_id,
      )

      if topic.save
        Post.where(topic_id: topic_id, post_number: 1).update_all(
          created_at: data[:created_at] || Time.current,
          updated_at: data[:updated_at] || Time.current,
          user_id: data[:user_id] || topic.user_id,
        )
        render json: { message: "Topic and first related post updated successfully" }, status: :ok
      else
        render json: { error: topic.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def move_all_topic
      from_category_id = params[:from_category_id]
      to_category_id = params[:to_category_id]

      if from_category_id.blank? || to_category_id.blank?
        return(
          render json: {
                   error: "from_category_id or to_category_id is missing",
                 },
                 status: :bad_request
        )
      end

      from_category = Category.find_by(id: from_category_id)
      to_category = Category.find_by(id: to_category_id)
      unless from_category && to_category
        return render json: { error: "One or both categories not found" }, status: :not_found
      end

      moved_count =
        Topic.where(category_id: from_category_id).update_all(category_id: to_category_id)
      render json: {
               message:
                 "#{moved_count} topics moved successfully from category #{from_category_id} to #{to_category_id}",
             },
             status: :ok
    end

    def change_old_activity
      category_id = params[:category_id]

      if category_id.blank?
        return render json: { error: "category_id is required" }, status: :bad_request
      end

      category = Category.find_by(id: category_id)
      return render json: { error: "Category not found" }, status: :not_found unless category

      topics = Topic.where(category_id: category_id).where("updated_at < ?", Date.new(2024, 2, 21))

      topics.each { |topic| topic.update(bumped_at: topic.updated_at) }

      render json: {
               message: "#{topics.size} topics updated successfully in category #{category_id}",
             },
             status: :ok
    end
  end
end
