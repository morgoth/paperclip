require "spec_helper"
require "paperclip/process_job"

RSpec.describe Paperclip::ProcessJob do
  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger = nil

    original_path = "tmp/public/system/dummies/avatars/000/000/001/original/5k.png"
    @thumb_path = "tmp/public/system/dummies/avatars/000/000/001/thumb/5k.png"

    [original_path, @thumb_path].each do |path|
      File.delete(path) if File.exist?(path)
      FileUtils.mkdir_p(File.dirname(path))
    end

    FileUtils.cp(File.new(fixture_file("5k.png"), "rb"), original_path)
    rebuild_model styles: { thumb: "100x100" },
                  only_process: [:none],
                  process_in_background: [:thumb]
  end

  after do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  it "processes styles marked for background processing" do
    dummy = Dummy.create!(avatar_file_name: "5k.png")

    assert_file_not_exists(@thumb_path)
    Paperclip::ProcessJob.perform_now(dummy, "avatar")
    assert_file_exists(@thumb_path)
  end

  it "updates avatar_processing_in_background to false when finished" do
    ActiveRecord::Base.connection.add_column :dummies, :avatar_processing_in_background, :boolean
    rebuild_class styles: { thumb: "100x100" },
                  only_process: [:none],
                  process_in_background: [:thumb]

    dummy = Dummy.create!(avatar_file_name: "5k.png", avatar_processing_in_background: true)
    Paperclip::ProcessJob.perform_now(dummy, "avatar")

    assert_equal false, dummy.reload.avatar_processing_in_background
  end
end
