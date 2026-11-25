import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsVersionTagController extends Controller {
  @service dialog;

  @tracked tentacleVisible = false;
  @tracked fromCategoryId = 4;
  @tracked toCategoryId = 0;
  @tracked newAuthorId;
  @tracked isLoadingListTopic = false;
  @tracked listTopics = [];

  @action
  async moveAllTopic() {
    try {
      await ajax(`/version_tags/move_all_topic`, {
        type: "POST",
        data: {
          from_category_id: this.fromCategoryId,
          to_category_id: this.toCategoryId,
        },
      });
      this.dialog.alert("Move all topic successfully");
      this.loadListTopicFromCategoryId(this.fromCategoryId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  showTopics() {
    this.tentacleVisible = true;
    this.loadListTopicFromCategoryId(this.fromCategoryId);
  }

  @action
  changeOldActivity() {
    this.callChangeOldActivity(this.fromCategoryId);
  }

  @action
  async onChangeDate(props, date) {
    const convertDate = this.convertDateWithTime(date);
    const data = { created_at: convertDate, updated_at: convertDate };
    if (this.newAuthorId) {
      data.user_id = this.newAuthorId;
    }
    try {
      await ajax(`/version_tags/change_topic/${props.topicId}`, {
        type: "PUT",
        data,
      });
      this.dialog.alert(`Change date success for topic ${props.topicId}`);
    } catch (error) {
      popupAjaxError(error);
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

  async callChangeOldActivity(categoryId) {
    try {
      await ajax(`/version_tags/change_old_activity`, {
        type: "POST",
        data: {
          category_id: categoryId,
        },
      });
      this.dialog.alert(
        `Change old activity of all topic from category ${categoryId} successfully`
      );
    } catch (error) {
      popupAjaxError(error);
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
