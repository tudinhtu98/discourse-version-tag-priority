import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import MiniTagChooserVersion from "../../components/mini-tag-chooser-version";

export default class AddVersionTagChooser extends Component {
  @service siteSettings;

  get shouldRender() {
    return (
      this.siteSettings.discourse_version_tag_priority_enabled &&
      this.args.canEditTags
    );
  }

  @action
  onChange(tags) {
    this.args.model.set("version_tags", tags);
  }

  <template>
    {{#if this.shouldRender}}
      <div class="tags-input full-width-version-tags">
        <MiniTagChooserVersion
          @value={{@model.version_tags}}
          @onChange={{this.onChange}}
          @options={{hash
            categoryId=@model.categoryId
            disabled=@disabled
          }}
        />
      </div>
    {{/if}}
  </template>
}
