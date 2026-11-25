import { Input } from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import ConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDatePicker from "discourse/ui-kit/d-date-picker";

export default <template>
  <div class="buttons">
    <span><strong>From Category Id:</strong></span>
    <Input @value={{@controller.fromCategoryId}} />
  </div>
  <div class="buttons">
    <span><strong>To Category Id:</strong></span>
    <Input @value={{@controller.toCategoryId}} />
  </div>
  <div class="buttons">
    <span><strong>New Author Id (optional for change topic's date):</strong></span>
    <Input @value={{@controller.newAuthorId}} />
  </div>
  <div class="buttons">
    <DButton
      @label="version_tag_settings.move_all_topic"
      @action={{@controller.moveAllTopic}}
      @icon="copy"
      @id="MoveAllTopic"
    />
  </div>
  <div class="buttons">
    <DButton
      @label="version_tag_settings.change_old_activity"
      @action={{@controller.changeOldActivity}}
      @icon="copy"
      @id="changeOldActivity"
    />
  </div>
  <div class="buttons">
    <DButton
      @label="version_tag_settings.show_topics"
      @action={{@controller.showTopics}}
      @icon="eye"
      @id="show-topics"
    />
  </div>

  {{#if @controller.tentacleVisible}}
    <ConditionalLoadingSpinner @condition={{@controller.isLoadingListTopic}}>
      <table class="table">
        <thead>
          <tr>
            <th>Id</th>
            <th>Title</th>
            <th>Set Datetime</th>
          </tr>
        </thead>

        <tbody>
          {{#each @controller.listTopics as |topic|}}
            <tr>
              <td>{{topic.id}}</td>
              <td>
                <a
                  href={{concat "/t/" topic.id}}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{topic.title}}
                </a>
              </td>
              <td>
                <DDatePicker
                  @value={{topic.created_at}}
                  @onSelect={{fn
                    @controller.onChangeDate
                    (hash topicId=topic.id)
                  }}
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </ConditionalLoadingSpinner>
  {{/if}}
</template>
