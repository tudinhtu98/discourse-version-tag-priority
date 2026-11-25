import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";

function getTagName(tag) {
  return typeof tag === "string" ? tag : tag?.name;
}

function mergeUniqueTags(regularTags, versionTags) {
  const merged = [];
  const seen = new Set();

  for (const tag of [...(regularTags || []), ...(versionTags || [])]) {
    const name = getTagName(tag)?.toLowerCase();
    if (!name || seen.has(name)) {
      continue;
    }
    seen.add(name);
    merged.push(tag);
  }

  return merged;
}

export default {
  name: "add-type-topic-chooser-composer",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "model:composer",
        (Superclass) =>
          class extends Superclass {
            @tracked version_tags = [];

            get _versionTagPrefix() {
              return this.siteSettings.discourse_version_tag_priority_symbol;
            }

            get _isVersionTagPriorityEnabled() {
              return (
                this.siteSettings.discourse_version_tag_priority_enabled &&
                Boolean(this._versionTagPrefix)
              );
            }

            @computed("tags", "tags.[]", "version_tags", "version_tags.[]")
            get combinedTags() {
              if (!this._isVersionTagPriorityEnabled) {
                return this.tags || [];
              }
              return mergeUniqueTags(this.tags, this.version_tags);
            }

            @computed("topic.tags", "topic.tags.[]")
            get filteredNotVersionTags() {
              const topicTags = this.topic?.tags || [];
              if (!this._isVersionTagPriorityEnabled) {
                return topicTags;
              }
              const prefix = this._versionTagPrefix;
              return topicTags.filter(
                (tag) => !getTagName(tag)?.startsWith(prefix)
              );
            }

            @computed("topic.tags", "topic.tags.[]")
            get filteredVersionTags() {
              if (!this._isVersionTagPriorityEnabled) {
                return [];
              }
              const prefix = this._versionTagPrefix;
              return (this.topic?.tags || []).filter((tag) =>
                getTagName(tag)?.startsWith(prefix)
              );
            }

            _splitVersionTags() {
              if (!this._isVersionTagPriorityEnabled) {
                return;
              }

              const prefix = this._versionTagPrefix;
              const currentTags = this.tags || [];
              const versionTags = [];
              const regularTags = [];

              for (const tag of currentTags) {
                if (getTagName(tag)?.startsWith(prefix)) {
                  versionTags.push(tag);
                } else {
                  regularTags.push(tag);
                }
              }

              if (versionTags.length > 0) {
                this.set("tags", regularTags);
                this.set(
                  "version_tags",
                  mergeUniqueTags(this.version_tags, versionTags)
                );
              }
            }

            _open(opts) {
              this.set("version_tags", []);
              const promise = super._open(opts);
              if (!Array.isArray(this.version_tags)) {
                this.set("version_tags", []);
              }
              this._splitVersionTags();
              return promise.then((res) => {
                this._splitVersionTags();
                return res;
              });
            }

            clearState() {
              super.clearState(...arguments);
              this.set("version_tags", []);
            }

            @computed(
              "loading",
              "canEditTitle",
              "titleLength",
              "targetRecipients",
              "targetRecipientsArray",
              "replyLength",
              "categoryId",
              "missingReplyCharacters",
              "tags",
              "tags.[]",
              "version_tags",
              "version_tags.[]",
              "topicFirstPost",
              "minimumRequiredTags",
              "user.staff"
            )
            get cantSubmitPost() {
              if (
                !this._isVersionTagPriorityEnabled ||
                !this.site?.can_tag_topics ||
                this.user?.staff ||
                !this.topicFirstPost ||
                !this.minimumRequiredTags ||
                (this.tags || []).length >= this.minimumRequiredTags ||
                this.combinedTags.length < this.minimumRequiredTags
              ) {
                return super.cantSubmitPost;
              }

              if (this.loading) {
                return true;
              }
              if (this.canEditTitle && !this.titleLengthValid) {
                return true;
              }
              if (this.missingReplyCharacters > 0) {
                return true;
              }

              const category = this.category;
              if (category && category.topic_template) {
                if (this.reply.trim() === category.topic_template.trim()) {
                  this.dialog.alert(
                    i18n("composer.error.topic_template_not_modified")
                  );
                  return true;
                }
              }

              if (this.privateMessage) {
                return (
                  this.targetRecipients &&
                  this.targetRecipientsArray.length === 0
                );
              }

              return this.requiredCategoryMissing;
            }

            editPost(opts) {
              if (
                !this._isVersionTagPriorityEnabled ||
                !(this.title && this.post?.post_number === 1)
              ) {
                return super.editPost(opts);
              }

              const prevTags = this.tags;
              this.set("tags", this.combinedTags);

              return super.editPost(opts).catch((error) => {
                this.set("tags", prevTags);
                throw error;
              });
            }
          }
      );

      api.modifyClass(
        "service:composer",
        (Superclass) =>
          class extends Superclass {
            async _setModel(optionalComposerModel, opts) {
              await super._setModel(optionalComposerModel, opts);
              this.model?._splitVersionTags?.();
            }

            @computed(
              "model.category",
              "model.tags",
              "model.tags.[]",
              "model.version_tags",
              "model.version_tags.[]",
              "lastValidatedAt"
            )
            get tagValidation() {
              if (
                this.siteSettings.discourse_version_tag_priority_enabled &&
                this.model?.combinedTags?.length >=
                  this.model?.category?.minimumRequiredTags
              ) {
                return undefined;
              }

              return super.tagValidation;
            }
          }
      );

      Composer.serializeOnCreate("tags", "combinedTags");
      Composer.serializeToDraft("version_tags");
    });
  },
};
