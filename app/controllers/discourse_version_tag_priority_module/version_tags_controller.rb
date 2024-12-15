# frozen_string_literal: true

module DiscourseVersionTagPriorityModule
  class VersionTagsController < ApplicationController
    before_action :ensure_staff, only: [:change_topic]

    def change_topic
      topic_id = params[:topic_id]
      data = params.permit(:created_at, :updated_at, :user_id)
  
      # Tìm topic theo topic_id
      topic = Topic.find_by(id: topic_id)
      return render json: { error: 'Topic not found' }, status: :not_found unless topic
      
      # Tìm user theo user_id
      if data[:user_id]
        user = User.find_by(id: data[:user_id])
        return render json: { error: 'User not found' }, status: :not_found unless user
      end
      
      # Cập nhật dữ liệu cho topic
      topic.assign_attributes(
        created_at: data[:created_at] || topic.created_at,
        updated_at: data[:updated_at] || topic.updated_at,
        user_id: data[:user_id] || topic.user_id
      )
  
      if topic.save
        # Tìm các posts liên quan và cập nhật
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
  end
end
