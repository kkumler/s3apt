require 'aws-sdk-s3'

class S3Client
  def initialize(options = {})
    @s3_client = Aws::S3::Client.new
  end

  def list_objects_v2(options)
    continuation_token = nil
    contents = []
    loop do
      response = @s3_client.list_objects_v2(options.merge(continuation_token: continuation_token, max_keys: options[:max_keys]))
      if options[:delimiter]
        contents += response.common_prefixes
      else
        contents += response.contents
      end
      continuation_token = response.next_continuation_token
      break if continuation_token.nil?
      next unless options[:max_keys]
      break if response.contents.length < options[:max_keys]
      break if contents.length >= options[:max_keys]
    end
    contents
  end

  def delete_objects(options)
    @s3_client.delete_objects(options)
  end
end