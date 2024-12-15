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
  moveAllTopic() {
    console.log("move all");
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
      const res = await ajax(`/t/${props.topicId}.json`, {
        type: "PUT",
        data,
      });
      console.log("res", res);
      alert(`Change date success for topic ${props.topicId}`);
    } catch (error) {
      console.log("error", error);
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
