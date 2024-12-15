import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsVersionController extends Controller {
  @tracked tentacleVisible = false;
  @tracked fromCategoryId = 4;
  @tracked toCategoryId = 0;
  @tracked newAuthorId;
  @tracked isLoadingListTopic = false;
  @tracked listTopics = [];

  @action
  async moveAllTopic() {
    try {
      const res = await ajax(`/version_tags/move_all_topic`, {
        type: "POST",
        data: {
          from_category_id: this.fromCategoryId,
          to_category_id: this.toCategoryId,
        },
      });
      alert(`Move all topic successfully`);
      this.loadListTopicFromCategoryId(this.fromCategoryId);
    } catch (error) {
      alert(`Move all topic fail`);
    }
  }

  @action
  showTopics() {
    this.tentacleVisible = true;
    this.loadListTopicFromCategoryId(this.fromCategoryId);
  }

  @action
  async onChangeDate(props, date) {
    const convertDate = this.convertDateWithTime(date);
    const data = { created_at: convertDate, updated_at: convertDate };
    if (this.newAuthorId) {
      data.user_id = this.newAuthorId;
    }
    try {
      const res = await ajax(`/version_tags/change_topic/${props.topicId}`, {
        type: "PUT",
        data,
      });
      alert(`Change date success for topic ${props.topicId}`);
    } catch (error) {
      alert(`Change date fail for topic ${props.topicId}`);
    }
  }

  async loadListTopicFromCategoryId(categoryId) {
    this.isLoadingListTopic = true;
    try {
      const res = await ajax(`/c/${categoryId}.json`);
      this.listTopics = res.topic_list.topics;
    } finally {
      this.isLoadingListTopic = false;
    }
  }

  convertDateWithTime(dateString) {
    const date = new Date(dateString);
    const now = new Date();

    date.setHours(
      now.getHours(),
      now.getMinutes(),
      now.getSeconds(),
      now.getMilliseconds()
    );

    return date.toISOString();
  }
}
