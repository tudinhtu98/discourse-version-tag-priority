# frozen_string_literal: true

module DiscourseVersionTagPriorityModule
  class VersionTagsController < ApplicationController
    before_action :ensure_staff, only: [:change_topic, :move_all_topic]

    def change_topic
      topic_id = params[:topic_id]
      data = params.permit(:created_at, :updated_at, :user_id)
  
      # Find topic by topic_id
      topic = Topic.find_by(id: topic_id)
      return render json: { error: 'Topic not found' }, status: :not_found unless topic
      
      # Find user by user_id
      if data[:user_id]
        user = User.find_by(id: data[:user_id])
        return render json: { error: 'User not found' }, status: :not_found unless user
      end

      # Update data for topic
      topic.assign_attributes(
        created_at: data[:created_at] || topic.created_at,
        updated_at: data[:updated_at] || topic.updated_at,
        user_id: data[:user_id] || topic.user_id
      )
  
      if topic.save
        # Find related posts and update
        Post.where(topic_id: topic_id, post_number: 1).update_all(
          created_at: data[:created_at] || Time.now,
          updated_at: data[:updated_at] || Time.now,
          user_id: data[:user_id] || topic.user_id
        )
        render json: { message: 'Topic and first related post updated successfully' }, status: :ok
      else
        render json: { error: topic.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def move_all_topic
      from_category_id = params[:from_category_id]
      to_category_id = params[:to_category_id]
  
      # Required params from_category_id, to_category_id
      return render json: { error: 'from_category_id or to_category_id is missing' }, status: :bad_request if from_category_id.blank? || to_category_id.blank?
  
      # Check exist category
      from_category = Category.find_by(id: from_category_id)
      to_category = Category.find_by(id: to_category_id)
      return render json: { error: 'One or both categories not found' }, status: :not_found unless from_category && to_category
  
      # Move all topics from from_category_id to to_category_id
      topics = Topic.where(category_id: from_category_id)
      if topics.update_all(category_id: to_category_id)
        render json: { message: "#{topics.count} topics moved successfully from category #{from_category_id} to #{to_category_id}" }, status: :ok
      else
        render json: { error: 'Failed to move topics' }, status: :unprocessable_entity
      end
    end
  end
end
