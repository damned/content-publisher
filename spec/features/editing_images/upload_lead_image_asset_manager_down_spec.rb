# frozen_string_literal: true

RSpec.feature "Upload a lead image when Asset Manager is down" do
  scenario "User uploads a lead image and Asset Manager is down" do
    given_there_is_a_document
    when_i_visit_the_lead_images_page
    and_asset_manager_is_down
    and_i_upload_an_image
    then_i_should_see_an_error
    and_the_image_does_not_exist
  end

  def given_there_is_a_document
    document_type_schema = build(:document_type_schema, lead_image: true)
    create(:document, document_type: document_type_schema.id)
  end

  def when_i_visit_the_lead_images_page
    visit document_lead_image_path(Document.last)
  end

  def and_asset_manager_is_down
    asset_manager_upload_failure
  end

  def and_i_upload_an_image
    find('form input[type="file"]').set(file_fixture("960x640.jpg"))
    click_on "Upload"
  end

  def then_i_should_see_an_error
    expect(page).to have_content(I18n.t("document_lead_image.index.flashes.api_error.title"))
  end

  def and_the_image_does_not_exist
    expect(page).to have_content(I18n.t("document_lead_image.index.no_existing_image"))
  end
end
