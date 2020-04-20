class Requirements::Publish::FileAttachmentsChecker < Requirements::Checker
  attr_reader :edition

  def initialize(edition)
    @edition = edition
  end

  def issues
    issues = Requirements::CheckerIssues.new

    unless edition.document_type.attachments.featured?
      return issues
    end

    edition.file_attachment_revisions.each do |attachment|
      if attachment.official_document_type.blank?
        issues.create(:file_attachment_official_document_type,
                      :blank,
                      filename: attachment.filename,
                      attachment_revision: attachment)
      end
    end

    issues
  end
end
