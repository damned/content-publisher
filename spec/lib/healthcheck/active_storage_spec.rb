RSpec.describe Healthcheck::ActiveStorage do
  describe "#status" do
    it "returns OK when connected to the storage service" do
      expect(described_class.new.status).to eq :ok
    end

    it "returns WARNING when the storage connection fails" do
      allow(ActiveStorage::Blob.service).to receive(:exist?)
        .and_raise("connection failed")

      expect(described_class.new.status).to eq :warning
    end
  end
end
