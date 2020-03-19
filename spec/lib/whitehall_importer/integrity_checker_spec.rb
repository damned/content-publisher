RSpec.describe WhitehallImporter::IntegrityChecker do
  let(:document_type) do
    build(
      :document_type,
      :with_lead_image,
      contents: [
        DocumentType::TitleAndBasePathField.new,
        DocumentType::SummaryField.new,
        DocumentType::BodyField.new,
      ],
      tags: [
        DocumentType::PrimaryPublishingOrganisationField.new,
        DocumentType::OrganisationsField.new,
      ],
    )
  end

  describe "#valid?" do
    let(:state) { :published }
    let(:edition) do
      build(:edition, state,
            state: state,
            document_type: document_type,
            published_at: "2020-03-11 12:00 UTC",
            document: create(:document, first_published_at: "2020-03-11 12:00 UTC"),
            tags: {
              primary_publishing_organisation: [SecureRandom.uuid],
              organisations: [SecureRandom.uuid],
            })
    end
    let(:publishing_api_item) do
      default_publishing_api_item(edition,
                                  public_updated_at: "2020-03-11T12:00:00Z",
                                  state_history: { "1" => "published" },
                                  details: {
                                    body: GovspeakDocument.new(edition.contents["body"], edition).payload_html,
                                    first_public_at: "2020-03-11T12:00:00.000+00:00",
                                  },
                                  links: {
                                    primary_publishing_organisation: edition.tags["primary_publishing_organisation"].to_a,
                                    organisations: edition.tags["organisations"].to_a + edition.tags["primary_publishing_organisation"].to_a,
                                  })
    end
    let(:integrity_check) { described_class.new(edition) }

    it "returns true if there aren't any problems for edition without image or attachment" do
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.valid?).to be true
    end

    it "returns true if the Publishing API image caption is nil but the imported image caption is an empty string" do
      image_revision = create(:image_revision, caption: "")
      edition.revision.image_revisions = [image_revision]
      edition.revision.lead_image_revision = image_revision

      publishing_api_item[:details][:image] = {
        caption: nil,
      }
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.valid?).to be true
    end

    it "returns true if the Publishing API image is a placeholder and the imported edition has no image" do
      publishing_api_item[:details][:image] = {
        alt_text: "placeholder",
      }
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.valid?).to be true
    end

    it "returns true if first_published_at times match" do
      publishing_api_item[:details][:first_public_at] = "2020-03-11T12:00:00.000+00:00"
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.valid?).to be true
    end

    it "returns true if public_updated_at times match" do
      publishing_api_item[:public_updated_at] = "2020-03-11T12:00:00Z"
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.valid?).to be true
    end

    it "compares against organisations in linkset links if there no edition links" do
      publishing_api_item[:links] = {}
      stub_publishing_api_has_item(publishing_api_item)

      stub_publishing_api_has_links(
        content_id: edition.content_id,
        links: {
          primary_publishing_organisation: edition.tags["primary_publishing_organisation"].to_a,
          organisations: edition.tags["organisations"].to_a + edition.tags["primary_publishing_organisation"].to_a,
        },
      )

      expect(integrity_check.valid?).to be true
    end

    context "when checking an edition that isn't live" do
      let(:state) { :scheduled }

      it "returns true even if the public_updated_at times don't match" do
        publishing_api_item[:public_updated_at] = "2019-02-11T09:30:00Z"
        stub_publishing_api_has_item(publishing_api_item)

        expect(integrity_check.valid?).to be true
      end
    end

    context "with an attachment not yet on asset mananger" do
      let(:file_attachment_revision) { create(:file_attachment_revision) }
      let(:edition) do
        build(:edition,
              document: create(:document, first_published_at: "2020-03-11 12:00:00 +0000"),
              document_type: document_type,
              file_attachment_revisions: [file_attachment_revision],
              contents: {
                body: "[InlineAttachment:#{file_attachment_revision.filename}]",
              })
      end

      let(:publishing_api_item) do
        default_publishing_api_item(edition,
                                    details: {
                                      body: GovspeakDocument.new(edition.contents["body"], edition).payload_html,
                                      first_public_at: "2020-03-11T12:00:00.000+00:00",
                                    })
      end

      it "returns true if there aren't any problems" do
        stub_publishing_api_has_links(content_id: edition.content_id)
        stub_publishing_api_has_item(publishing_api_item)

        expect(integrity_check.valid?).to be true
      end
    end
  end

  describe "#problems" do
    let(:edition) do
      build(:edition, :published,
            document_type: document_type,
            image_revisions: [build(:image_revision)],
            document: create(:document, first_published_at: "2020-03-11 18:32:38 UTC"),
            tags: { "organisations" => [] })
    end
    let(:publishing_api_item) do
      {
        content_id: edition.content_id,
        base_path: "base-path",
        title: "title",
        description: "description",
        document_type: "news_story",
        schema_name: "news_article",
        state_history: { "1" => "published" },
        details: {
          body: "body text",
          image: {
            alt_text: "alt text",
            caption: "caption",
          },
        },
        links: {
          primary_publishing_organisation: [SecureRandom.uuid],
          organisations: [SecureRandom.uuid],
        },
      }
    end
    let(:integrity_check) { described_class.new(edition) }

    def problem_message(message, expected, actual)
      "#{message}, expected: #{expected.inspect}, actual: #{actual.inspect}"
    end

    before do
      stub_publishing_api_has_links(content_id: edition.content_id)
      stub_publishing_api_has_item(publishing_api_item)
    end

    it "returns a problem when first_published_at times don't match" do
      publishing_api_item[:details][:first_public_at] = "2020-03-11T12:00:00.000+00:00"
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.problems).to include(
        problem_message("our first_published_at doesn't match first_public_at",
                        publishing_api_item[:details][:first_public_at],
                        edition.document.first_published_at.as_json),
      )
    end

    it "returns a problem when public_updated_at times don't match" do
      publishing_api_item[:public_updated_at] = "2020-03-11T12:00:00Z"
      stub_publishing_api_has_item(publishing_api_item)

      expect(integrity_check.problems).to include(
        problem_message("public_updated_at doesn't match",
                        publishing_api_item[:public_updated_at],
                        edition.public_first_published_at.as_json),
      )
    end

    it "returns a problem when the base paths don't match" do
      expect(integrity_check.problems).to include(
        problem_message("base_path doesn't match", publishing_api_item[:base_path], edition.base_path),
      )
    end

    it "returns a problem when the titles don't match" do
      expect(integrity_check.problems).to include(
        problem_message("title doesn't match", publishing_api_item[:title], edition.title),
      )
    end

    it "returns a problem when the descriptions don't match" do
      expect(integrity_check.problems).to include(
        problem_message("description doesn't match", publishing_api_item[:description], edition.summary),
      )
    end

    it "returns a problem when the document types don't match" do
      expect(integrity_check.problems).to include(
        problem_message("document_type doesn't match",
                        publishing_api_item[:document_type],
                        edition.document_type.id),
      )
    end

    it "returns a problem when the schema names don't match" do
      edition_schema_name = edition.document_type.publishing_metadata.schema_name
      expect(integrity_check.problems).to include(
        problem_message("schema_name doesn't match", publishing_api_item[:schema_name], edition_schema_name),
      )
    end

    it "returns a problem when the body text doesn't match" do
      expect(integrity_check.problems).to include("body text doesn't match")
    end

    it "returns a problem when the image alt_text doesn't match" do
      edition_image = edition.image_revisions.first
      publishing_api_image = publishing_api_item[:details][:image]

      expect(integrity_check.problems).to include(
        problem_message("image alt_text doesn't match",
                        publishing_api_image[:alt_text],
                        edition_image.alt_text),
      )
    end

    it "returns a problem when the image caption doesn't match" do
      edition_image = edition.image_revisions.first
      publishing_api_image = publishing_api_item[:details][:image]

      expect(integrity_check.problems).to include(
        problem_message("image caption doesn't match",
                        publishing_api_image[:caption],
                        edition_image.caption),
      )
    end

    it "returns a problem when the primary_publishing_organisation doesn't match" do
      expect(integrity_check.problems).to include(
        problem_message("primary_publishing_organisation doesn't match",
                        publishing_api_item[:links][:primary_publishing_organisation],
                        edition.tags["primary_publishing_organisation"]),
      )
    end

    it "returns a problem when the organisations don't match" do
      expected = publishing_api_item[:links][:organisations].inspect
      actual = edition.tags["organisations"].inspect
      message = "organisations don't match, expected: #{expected}, actual: #{actual}"

      expect(integrity_check.problems).to include(message)
    end
  end

  describe ".time_matches?" do
    let(:time) { Time.zone.now }

    it "returns true when times match" do
      expect(described_class.time_matches?(time.rfc3339, time.rfc3339)).to eq true
    end

    it "returns true when times are sufficiently similar" do
      expect(described_class.time_matches?((time + 4).rfc3339, time.rfc3339)).to eq true
    end

    it "returns false when times are not sufficiently similar" do
      expect(described_class.time_matches?((time + 30).rfc3339, time.rfc3339)).to eq false
    end

    it "returns false when times are invalid" do
      expect(described_class.time_matches?("Not a time", nil)).to eq false
    end
  end

  def default_publishing_api_item(edition, override_hash = {})
    {
      content_id: edition.content_id,
      base_path: edition.base_path,
      title: edition.title,
      description: edition.summary,
      document_type: edition.document_type.id,
      schema_name: edition.document_type.publishing_metadata.schema_name,
      details: {
        body: "",
      },
    }.deep_merge!(override_hash)
  end
end
