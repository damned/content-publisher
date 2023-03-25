class ContentEditorApiController < ActionController::Base

  def new
    @edition = Edition.find_current(document: '7629ab4c-5ee4-4a73-b09e-04f724ccb08e:en')
    content_editor_data = {
      item: { type_name: 'bob' },
      form_html: render_to_string(partial: 'content/edit')
    }
    render json: content_editor_data
  end

  def include_forgery_protection?
    false
  end

  helper_method :include_forgery_protection?
end
