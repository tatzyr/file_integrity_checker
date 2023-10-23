#!/usr/bin/env ruby

require "digest"
require "json"
require "optparse"

detailed_help = <<~HELP
  This script offers two distinct modes: hashing and cleanup.

  Hashing mode: Files in a given directory are processed by calculating their MD5 hash and size.
  The results are saved into a specified output file in JSON Lines format.
  If the file size has not changed from a previous processing, the hash calculation is skipped to save time.

  Cleanup mode: Clean the output file, removing any entries of files that have been deleted,
  or keeping only the latest entry for files that appear multiple times.

  -d, --directory DIRECTORY       Specify the directory to process. (Hashing mode only)
  -o, --output FILE               Specify the output file.
  -m, --mode MODE                 Specify the mode: "hashing" or "cleanup".
  -h, --help                      Print this help.

  Example usage:

  ruby file_integrity_checker.rb -d /path/to/your/directory -o /path/to/your/output.txt -m hashing
  ruby file_integrity_checker.rb -o /path/to/your/output.txt -m cleanup
HELP

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{File.basename($PROGRAM_NAME)} [options]"

  opts.on("-h", "--help", "Print this help") do
    puts detailed_help
    exit
  end

  opts.on("-d", "--directory DIRECTORY", "Specify the directory to process") do |v|
    options[:directory] = v
  end

  opts.on("-o", "--output FILE", "Specify the output file") do |v|
    options[:output] = v
  end

  opts.on("-m", "--mode MODE", 'Specify the mode: "hashing" or "cleanup"') do |v|
    options[:mode] = v.downcase
  end
end.parse!

unless ["hashing", "cleanup"].include?(options[:mode])
  puts "The mode must be specified as either 'hashing' or 'cleanup'."
  puts detailed_help
  exit 1
end

if options[:output].nil?
  puts "The output file must be specified."
  puts detailed_help
  exit 1
end

if options[:mode] == "hashing" && options[:directory].nil?
  puts "In hashing mode, the directory must be specified."
  puts detailed_help
  exit 1
end

def cleanup_output(output_file)
  latest_files = {}

  File.foreach(output_file) do |line|
    data = JSON.parse(line)
    if File.exist?(data["file"])
      if latest_files.key?(data["file"])
        puts "Duplicate entry resolved for #{data["file"]}"
      end
      latest_files[data["file"]] = {"md5" => data["md5"], "size" => data["size"]}
    else
      puts "Entry removed for deleted file #{data["file"]}"
    end
  end

  File.open(output_file, "w") do |f|
    latest_files.each do |file_path, file_data|
      f.puts({"file" => file_path, "md5" => file_data["md5"], "size" => file_data["size"]}.to_json)
    end
  end
end

def calculate_hash_and_size(directory, output_file)
  existing_files = {}

  if File.exist?(output_file)
    File.foreach(output_file) do |line|
      data = JSON.parse(line)
      existing_files[data["file"]] = {"md5" => data["md5"], "size" => data["size"]}
    end
  end

  Dir.glob("#{directory}/**/*").each do |file|
    if File.file?(file)
      size = File.size(file)
      if !existing_files.key?(file) || existing_files[file]["size"] != size
        puts "Processing #{file}..."
        File.open(output_file, "a") do |f|
          md5 = Digest::MD5.file(file).hexdigest
          f.puts({"file" => file, "md5" => md5, "size" => size}.to_json)
        end
      end
    end
  end
end

if options[:mode] == "hashing"
  calculate_hash_and_size(options[:directory], options[:output])
elsif options[:mode] == "cleanup"
  cleanup_output(options[:output])
end
