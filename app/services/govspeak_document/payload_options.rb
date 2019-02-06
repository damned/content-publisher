# frozen_string_literal: true


class GovspeakDocument::PayloadOptions < GovspeakDocument::Options
  attr_reader :text, :edition

  def to_h
    super.merge(images: payload_images)
  end

private

  def payload_images
    edition.revision.image_revisions.map { |image_revision| image_attributes(image_revision) }
  end

  def image_attributes(image_revision)
    {
      url: image_revision.asset_url("960"),
      alt_text: image_revision.alt_text,
      caption: image_revision.caption,
      credit: image_revision.credit,
      id: image_revision.filename,
    }
  end
end
