import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Version Tag Priority", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });
  needs.settings({
    tagging_enabled: true,
    allow_uncategorized_topics: true,
    tags_sort_alphabetically: true,
    discourse_version_tag_priority_enabled: true,
    discourse_version_tag_priority_symbol: "v",
  });

  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", () => {
      return helper.response({
        results: [{ id: 1, text: "bug", name: "bug", slug: "bug", count: 5 }],
      });
    });

    server.get("/version_tags/filter/search", () => {
      return helper.response({
        results: [
          { id: 3, text: "v2.0", name: "v2.0", slug: "v2-0", count: 1 },
          { id: 2, text: "v1.0", name: "v1.0", slug: "v1-0", count: 10 },
        ],
      });
    });

    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });

  test("renders version tag chooser, preserves server order, and combines tags on create", async function (assert) {
    let createdPayload;
    pretender.post("/posts", (request) => {
      createdPayload = request.requestBody;
      return [
        200,
        { "Content-Type": "application/json" },
        JSON.stringify({
          post: {
            id: 999,
            topic_id: 280,
            topic_slug: "internationalization-localization",
            post_number: 1,
          },
        }),
      ];
    });

    await visit("/");
    await click("#create-topic");

    assert
      .dom(".full-width-version-tags .mini-tag-chooser")
      .exists("version tag chooser renders in composer");

    const regularTags = selectKit(
      ".tags-input:not(.full-width-version-tags) .mini-tag-chooser"
    );
    await regularTags.expand();
    await regularTags.selectRowByValue(1);

    const versionTags = selectKit(".full-width-version-tags .mini-tag-chooser");
    await versionTags.expand();

    assert.strictEqual(
      versionTags.rowByIndex(0).value(),
      "3",
      "keeps server created_at order even when tags_sort_alphabetically is enabled"
    );

    await versionTags.selectRowByValue(3);

    await fillIn("#reply-title", "Testing version tag priority");
    await fillIn(".d-editor-input", "Body content for testing version tags");
    await click("#reply-control button.create");

    assert.true(
      createdPayload.includes("bug"),
      "submits regular tags when creating a topic"
    );
    assert.true(
      createdPayload.includes("v2.0"),
      "submits version tags when creating a topic"
    );
  });

  test("splits regular and version tags when editing a topic first post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const topicController = this.owner.lookup("controller:topic");
    topicController.model.set("tags", [
      { id: 1, name: "bug", slug: "bug" },
      { id: 3, name: "v2.0", slug: "v2-0" },
    ]);

    await click(".topic-post .show-more-actions");
    await click(".topic-post .edit");

    const regularTags = selectKit(
      ".tags-input:not(.full-width-version-tags) .mini-tag-chooser"
    );
    const versionTags = selectKit(".full-width-version-tags .mini-tag-chooser");

    assert.strictEqual(
      regularTags.header().value(),
      "1",
      "regular tag chooser only receives non-version tags"
    );
    assert.strictEqual(
      versionTags.header().value(),
      "3",
      "version tag chooser receives version tags"
    );
  });

  test("satisfies minimum_required_tags when only a version tag is selected", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    pretender.post("/posts", () => {
      return response({
        post: {
          id: 999,
          topic_id: 280,
          topic_slug: "internationalization-localization",
          post_number: 1,
        },
      });
    });

    await visit("/");
    await click("#create-topic");

    Category.findById(2).set("minimum_required_tags", 1);

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn("#reply-title", "Topic with only a version tag");
    await fillIn(".d-editor-input", "Content for version tagged topic");

    const versionTags = selectKit(".full-width-version-tags .mini-tag-chooser");
    await versionTags.expand();
    await versionTags.selectRowByValue(3);

    await click("#reply-control button.create");
    assert.notStrictEqual(
      currentURL(),
      "/",
      "allows submitting topic when minimum_required_tags is satisfied by version tag"
    );
  });

  test("renders admin version-tag route and loads category topics", async function (assert) {
    pretender.get("/admin/plugins.json", () => {
      return response({
        plugins: [
          {
            id: "discourse-version-tag-priority",
            name: "discourse-version-tag-priority",
            enabled: true,
            has_settings: true,
            admin_route: {
              location: "version-tag",
              label: "version_tag_settings.title",
              full_location: "adminPlugins.version-tag",
              use_new_show_route: false,
            },
          },
        ],
      });
    });

    pretender.get("/c/4.json", () => {
      return response({
        topic_list: {
          topics: [
            {
              id: 123,
              title: "Release v2.0",
              created_at: "2025-01-15T10:00:00.000Z",
            },
          ],
        },
      });
    });

    await visit("/admin/plugins/version-tag");

    assert.dom("#MoveAllTopic").exists("renders MoveAllTopic button");
    assert.dom("#changeOldActivity").exists("renders changeOldActivity button");
    assert.dom("#show-topics").exists("renders show-topics button");

    await click("#show-topics");

    assert.dom("table.table tbody tr").exists("renders loaded topics row");
    assert
      .dom("table.table tbody td .date-picker")
      .exists("renders DDatePicker input for topic date");
  });
});
