import { setting } from "discourse/lib/computed";
import I18n from "discourse-i18n";
import MiniTagChooserComponent from "select-kit/components/mini-tag-chooser";

const CUSTOME_TAG_TYPE = "version";

export default MiniTagChooserComponent.extend({
  maxTagsPerTopic: setting("max_version_tags_per_topic"),

  search(filter) {
    const data = {
      q: filter || "",
      limit: this.maxTagSearchResults,
      categoryId: this.selectKit.options.categoryId,
    };

    if (this.value) {
      data.selected_tags = this.value.slice(0, 100);
    }

    if (!this.selectKit.options.everyTag) {
      data.filterForInput = true;
    }

    return this.searchTags(
      `/${CUSTOME_TAG_TYPE}_tags/filter/search`,
      data,
      this._transformJson
    );
  },

  modifyNoSelection() {
    if (this.selectKit.options.minimum > 0) {
      return this.defaultItem(
        null,
        I18n.t(`${CUSTOME_TAG_TYPE}_tagging.choose_for_topic_required`, {
          count: this.selectKit.options.minimum,
        })
      );
    } else {
      return this.defaultItem(
        null,
        I18n.t(`${CUSTOME_TAG_TYPE}_tagging.choose_for_topic`)
      );
    }
  },
});
