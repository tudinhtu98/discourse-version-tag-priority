import { computed } from "@ember/object";
import { throwAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer, { EDIT_SHARED_DRAFT } from "discourse/models/composer";
import Topic from "discourse/models/topic";
import I18n from "discourse-i18n";

const PLUGIN_ID = "discourse-version-tag-priority";
const SAVING = "saving",
  OPEN = "open",
  _update_serializer = {
    raw: "reply",
    topic_id: "topic.id",
    raw_old: "rawOld",
    tags: "combinedTags",
  },
  _edit_topic_serializer = {
    title: "topic.title",
    categoryId: "topic.category.id",
    featuredLink: "topic.featured_link",
  };
export default {
  name: "add-type-topic-chooser-composer",
  initialize() {
    withPluginApi("1.3.0", (api) => {
      api.modifyClass("model:composer", {
        pluginId: PLUGIN_ID,
        is_private: false,
        version_tags: [],

        combinedTags: computed("tags", "version_tags", function () {
          return this.get("tags").concat(this.get("version_tags"));
        }),

        filteredNotVersionTags: computed("topic.tags", function () {
          const versionTagPrefix =
            this.siteSettings.discourse_version_tag_priority_symbol;
          return this.get("topic.tags").filter((tag) => {
            return !tag.startsWith(versionTagPrefix);
          });
        }),

        filteredVersionTags: computed("topic.tags", function () {
          const versionTagPrefix =
            this.siteSettings.discourse_version_tag_priority_symbol;
          return this.get("topic.tags").filter((tag) => {
            return tag.startsWith(versionTagPrefix);
          });
        }),

        cantSubmitPost: computed(
          "loading",
          "canEditTitle",
          "titleLength",
          "targetRecipients",
          "targetRecipientsArray",
          "replyLength",
          "categoryId",
          "missingReplyCharacters",
          "tags",
          "topicFirstPost",
          "minimumRequiredTags",
          "user.staff",
          "version_tags",
          function () {
            // can't submit while loading
            if (this.loading) {
              return true;
            }

            // title is required when
            //  - creating a new topic/private message
            //  - editing the 1st post
            if (this.canEditTitle && !this.titleLengthValid) {
              return true;
            }

            // reply is always required
            if (this.missingReplyCharacters > 0) {
              return true;
            }

            if (
              this.site.can_tag_topics &&
              !this.isStaffUser &&
              this.topicFirstPost &&
              this.minimumRequiredTags
            ) {
              const tagsArray = this.tags || [];
              if (tagsArray.length < this.minimumRequiredTags) {
                return true;
              }
            }

            if (this.topicFirstPost) {
              // user should modify topic template
              const category = this.category;
              if (category && category.topic_template) {
                if (this.reply.trim() === category.topic_template.trim()) {
                  this.dialog.alert(
                    I18n.t("composer.error.topic_template_not_modified")
                  );
                  return true;
                }
              }
            }

            if (this.privateMessage) {
              // need at least one user when sending a PM
              return (
                this.targetRecipients && this.targetRecipientsArray.length === 0
              );
            } else {
              // has a category? (when needed)
              return this.requiredCategoryMissing;
            }
          }
        ),

        editPost(opts) {
          const post = this.post;
          const oldCooked = post.cooked;
          let promise = Promise.resolve();

          // Update the topic if we're editing the first post
          if (this.title && post.post_number === 1) {
            const topic = this.topic;

            if (topic.details.can_edit) {
              const topicProps = this.getProperties(
                Object.keys(_edit_topic_serializer)
              );

              // Override here: add tags = combinedTags to topicProps
              this.serialize(_update_serializer, topicProps);

              // frontend should have featuredLink but backend needs featured_link
              if (topicProps.featuredLink) {
                topicProps.featured_link = topicProps.featuredLink;
                delete topicProps.featuredLink;
              }

              // If we're editing a shared draft, keep the original category
              if (this.action === EDIT_SHARED_DRAFT) {
                const destinationCategoryId = topicProps.categoryId;
                promise = promise.then(() =>
                  topic.updateDestinationCategory(destinationCategoryId)
                );
                topicProps.categoryId = topic.get("category.id");
              }
              promise = promise.then(() => Topic.update(topic, topicProps));
            } else if (topic.details.can_edit_tags) {
              promise = promise.then(() => topic.updateTags(this.tags));
            }
          }

          const props = {
            edit_reason: opts.editReason,
            image_sizes: opts.imageSizes,
            cooked: this.getCookedHtml(),
          };

          this.serialize(_update_serializer, props);
          this.set("composeState", SAVING);

          const rollback = throwAjaxError((error) => {
            post.setProperties("cooked", oldCooked);
            this.set("composeState", OPEN);
            if (error.jqXHR && error.jqXHR.status === 409) {
              this.set("editConflict", true);
            }
          });

          post.setProperties({ cooked: props.cooked, staged: true });
          this.appEvents.trigger("post-stream:refresh", { id: post.id });

          return promise
            .then(() => {
              return post.save(props).then((result) => {
                this.clearState();
                return result;
              });
            })
            .catch(rollback)
            .finally(() => {
              post.set("staged", false);
              this.appEvents.trigger("post-stream:refresh", { id: post.id });
            });
        },
      });

      // Add field version_tags in ajax body with value of this.version_tags when create topic
      Composer.serializeOnCreate("tags", "combinedTags");

      // Add field when open composer
      Composer.serializeToTopic("tags", "filteredNotVersionTags");
      Composer.serializeToTopic("version_tags", "filteredVersionTags");
    });
  },
};
