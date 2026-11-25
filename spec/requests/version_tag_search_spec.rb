# frozen_string_literal: true

RSpec.describe "DiscourseVersionTagPriority tag search and endpoints" do
  fab!(:user)
  fab!(:admin)
  fab!(:category)
  fab!(:feature_tag) { Fabricate(:tag, name: "feature-a", public_topic_count: 10) }
  fab!(:old_version_tag) do
    Fabricate(:tag, name: "v1.0", public_topic_count: 20, created_at: 2.days.ago)
  end
  fab!(:new_version_tag) do
    Fabricate(:tag, name: "v2.0", public_topic_count: 1, created_at: 1.hour.ago)
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.discourse_version_tag_priority_enabled = true
    SiteSetting.discourse_version_tag_priority_symbol = "v"
  end

  describe "GET /tags/filter/search" do
    it "excludes version-prefixed tags when plugin is enabled" do
      sign_in(user)

      get "/tags/filter/search.json"

      expect(response.status).to eq(200)
      names = response.parsed_body["results"].map { |tag| tag["name"] }
      expect(names).to contain_exactly(feature_tag.name)
    end

    it "includes all tags when plugin is disabled" do
      SiteSetting.discourse_version_tag_priority_enabled = false
      sign_in(user)

      get "/tags/filter/search.json"

      expect(response.status).to eq(200)
      names = response.parsed_body["results"].map { |tag| tag["name"] }
      expect(names).to contain_exactly(feature_tag.name, old_version_tag.name, new_version_tag.name)
    end
  end

  describe "GET /version_tags/filter/search" do
    it "returns only version-prefixed tags ordered by created_at desc when query is blank" do
      sign_in(user)

      get "/version_tags/filter/search.json"

      expect(response.status).to eq(200)
      names = response.parsed_body["results"].map { |tag| tag["name"] }
      expect(names).to eq([new_version_tag.name, old_version_tag.name])
    end

    it "excludes already selected tag ids and filters by query" do
      sign_in(user)

      get "/version_tags/filter/search.json",
          params: {
            q: "v1.0",
            selected_tag_ids: [new_version_tag.id],
          }

      expect(response.status).to eq(200)
      names = response.parsed_body["results"].map { |tag| tag["name"] }
      expect(names).to eq([old_version_tag.name])
    end

    it "handles existing forbidden or unselected exact-match queries without raising" do
      restricted_tag = Fabricate(:tag, name: "v3.0")
      other_category = Fabricate(:category, tags: [restricted_tag])
      sign_in(user)

      get "/version_tags/filter/search.json",
          params: {
            q: restricted_tag.name,
            categoryId: category.id,
            filterForInput: true,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["forbidden"]).to eq(restricted_tag.name)
      expect(other_category.id).not_to eq(category.id)
    end
  end

  describe "PUT /version_tags/change_topic/:topic_id" do
    fab!(:topic) { Fabricate(:topic, category: category, user: user) }
    fab!(:first_post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

    it "updates topic and first post attributes for staff" do
      sign_in(admin)
      new_time = 3.days.ago.change(usec: 0)

      put "/version_tags/change_topic/#{topic.id}.json",
          params: {
            created_at: new_time.iso8601,
            updated_at: new_time.iso8601,
            user_id: admin.id,
          }

      expect(response.status).to eq(200)
      expect(topic.reload.user_id).to eq(admin.id)
      expect(first_post.reload.user_id).to eq(admin.id)
    end
  end
end
