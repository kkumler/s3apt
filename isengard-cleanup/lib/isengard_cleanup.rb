#!/usr/bin/env ruby

require_relative 's3_client'
require 'optparse'
require 'awesome_print'

def confirm(options = {}, &block)
  return true if options[:force]
  return false unless STDIN.isatty
  block&.call
  while true
    STDERR.print 'Proceed (y/N)? '.blue
    begin
      match = /^(?:[YyNn]|$)/.match(STDIN.readline)
    rescue
      return false
    end
    next unless match
    return match[0].downcase == 'y'
  end
end

def delete_packages(packages, opts, s3)
  delete_count = packages.size - opts[:count].to_i
  if delete_count > 0
    sorted_objects = packages.sort_by { |object| object.last_modified.to_i }
    old_keys = sorted_objects.first(delete_count)
    STDOUT.puts 'Found '.green + packages.size.to_s.cyan + ' packages. '.green +  "#{delete_count}".cyan + ' will de deteled'.green
    STDOUT.puts old_keys.map { |object| object.key } if opts[:verbose]
    if confirm(force: opts[:force])
      if opts[:dryrun]
        STDOUT.puts '[dry-run] Deleted '.green + delete_count.to_s.cyan + ' objects'.green
      else
        response = s3.delete_objects(bucket: opts[:bucket], delete: { objects: old_keys.map { |object| { key: object.key } } })
        STDOUT.puts 'Deleted '.green + response.deleted.size.to_s.cyan + ' objects'.green
      end
    else
      STDOUT.puts 'Skipping deletion of '.yellow + delete_count.to_s.cyan + ' objects'.yellow
    end
  end
end

opts = {
  development_suffix: 'devci',
  prefix: 'trusty',
  release: 'development'
}

OptionParser.new do |options|
  options.banner = 'Usage: isengard_cleanup [options]'
  options.on('--aws-profile profile', 'aws profile') do |profile|
    STDOUT.puts "Using AWS profile ".green + profile.cyan
    Aws.config.update(profile: profile)
  end
  options.on('--development-suffix suffix', 'the development suffix (default: devci)') do |suffix|
    opts[:development_suffix] = suffix
  end
  options.on('-b', '--bucket bucket', 'bucket name') do |bucket|
    opts[:bucket] = bucket || ''
  end
  options.on('-p', '--prefix prefix', 'object name prefix (default: trusty)') do |prefix|
    opts[:prefix] = prefix || ''
  end
  options.on('-c', '--count N', 'how many copies to keep') do |x|
    opts[:count] = x || 1
  end
  options.on('-r', '--release release', 'which release to use [development, production] (default: development)') do |release|
    unless %w(development production).include? release
      STDERR.puts 'Invalid release '.red + release.cyan + '. Valid values are: development and production'.red
      exit 1
    end
    opts[:release] = release
  end
  options.on('--dry-run', 'do not delete files') do
    opts[:dryrun] = true
  end
  options.on('--verbose', 'be verbose') do
    opts[:verbose] = true
  end
  options.on('--force', 'do not ask for confirmation') do
    opts[:force] = true
  end
  options.parse!
end

if opts[:bucket].size < 1 || opts[:prefix].size < 1
  STDERR.puts 'bucket or prefix not valid!'.red
  exit 1
end

s3 = S3Client.new

packages = s3.list_objects_v2(
  bucket: opts[:bucket],
  prefix: opts[:prefix]
).select { |object| object.key =~ /deb$/ }
STDOUT.puts 'Selecting packages for release '.green + opts[:release].cyan
filtered_packages = if opts[:release] == 'development'
  packages.select { |object| object.key =~ /\-devci_/ }
else
  packages.reject { |object| object.key =~ /\-devci_/ }
end

packages_by_service = filtered_packages.reduce(Hash.new { |hash, key| hash[key] = [] }) do |summary, current|
  service = current.key.split('_')[0]
  summary.merge(service => (summary[service] << current))
end
packages_by_service.each do |service, packages|
  STDOUT.puts 'service: '.green + service.cyan
  delete_packages(packages, opts, s3)
  STDOUT.puts
end