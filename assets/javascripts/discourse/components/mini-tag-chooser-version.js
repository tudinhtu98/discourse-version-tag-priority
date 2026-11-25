import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { i18n } from "discourse-i18n";

const CUSTOM_TAG_TYPE = "version";

export default class MiniTagChooserVersion extends MiniTagChooser {
  @computed(
    "siteSettings.max_tags_per_topic",
    "siteSettings.max_version_tags_per_topic"
  )
  get maxTagsPerTopic() {
    return (
      this.siteSettings.max_version_tags_per_topic ??
      this.siteSettings.max_tags_per_topic
    );
  }

  search(filter) {
    const maximum = this.selectKit.options.maximum;
    if (maximum === 0) {
      this.addError(
        i18n("select_kit.max_content_reached", { count: maximum })
      );
      return [];
    }

    const data = {
      q: filter || "",
      limit: this.maxTagSearchResults,
      categoryId: this.selectKit.options.categoryId,
    };

    if (this.value?.length) {
      const ids = this.value
        .map((v) => (typeof v === "object" ? v.id : v))
        .filter((id) => Number.isInteger(Number(id)) && Number(id) > 0);
      if (ids.length) {
        data.selected_tag_ids = ids.slice(0, 100);
      }
    }

    if (!this.selectKit.options.everyTag) {
      data.filterForInput = true;
    }

    return this.tagUtils.searchTags(
      `/${CUSTOM_TAG_TYPE}_tags/filter/search`,
      data,
      (json) => this._transformJson(json, { skipSort: isEmpty(filter) })
    );
  }

  modifyNoSelection() {
    if (this.selectKit.options.minimum > 0) {
      return this.defaultItem(
        null,
        i18n(`${CUSTOM_TAG_TYPE}_tagging.choose_for_topic_required`, {
          count: this.selectKit.options.minimum,
        })
      );
    } else {
      return this.defaultItem(
        null,
        i18n(`${CUSTOM_TAG_TYPE}_tagging.choose_for_topic`)
      );
    }
  }
}
