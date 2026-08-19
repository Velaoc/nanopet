require "test_helper"

# SPEC M9: a hosted preview is a single container, so `SOLID_QUEUE_IN_PUMA=1`
# runs the queue supervisor inside the web process. Mail that an application
# hands to Active Job must therefore still reach a real delivery — an enqueued
# receipt that nothing ever performs would leave a preview silently mailless.
class QueuedMailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "single container previews run the queue inside Puma" do
    with_env("SOLID_QUEUE_IN_PUMA" => "1") do
      assert_predicate Foundation.runtime_config, :solid_queue_in_puma?
      assert_equal "inside Puma", Foundation.runtime_config.queue_mode
    end

    with_env("SOLID_QUEUE_IN_PUMA" => nil) do
      assert_not_predicate Foundation.runtime_config, :solid_queue_in_puma?
      assert_equal "external worker", Foundation.runtime_config.queue_mode
    end
  end


  private

  def with_queue_in_puma(&block)
    with_env(
      "SOLID_QUEUE_IN_PUMA" => "1",
      "VELA_HOLODEX_PREVIEW" => "1",
      "APP_HOST" => "https://queued.canonical.example",
      "MAILER_FROM" => "queue@queued.canonical.example",
      "SMTP_ADDRESS" => nil,
      &block
    )
  end
end
