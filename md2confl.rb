#!/usr/bin/env ruby
# encoding: utf-8

require 'confluence-soap'
require 'markdown2confluence'
require 'optparse'

options = {}
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: md2confl.rb [options...] -s <SPACE_NAME> -i <PAGE_ID>\nassumes defaults that can be set in options parsing..."

  options[:pageId] = nil
  opts.on('-i', '--pageId PAGE_ID', 'REQUIRED. The Confluence page id to upload the converted markdown to.') do |pageId|
    options[:pageId] = pageId
  end

  options[:spaceName] = nil
  opts.on('-s', '--space SPACE_NAME', 'UNUSED. The Confluence space name in which the page resides.') do |space|
    options[:spaceName] = space
  end

  # set default for Markdown file name and path
  options[:markdownFile] = 'README.md'
  opts.on( '-f', '--markdownFile FILE', "Path to the Markdown file to convert and upload. Defaults to '#{options[:markdownFile]}'") do |file|
    options[:markdownFile] = file
  end

  # set default for Confluence server
  options[:server] = 'http://confluence.example.com'
  opts.on( '-c', '--server CONFLUENCE_SERVER', "The Confluence server to upload to. Defaults to '#{options[:server]}'") do |server|
   options[:server] = server
  end

  options[:user] = nil
  opts.on('-u', '--user USER', 'The Confluence user. Can also be specified by the \'CONFLUENCE_USER\' environment variable.') do |pageId|
    options[:user] = pageId
  end

  options[:password] = nil
  opts.on('-p', '--password PASSWORD', 'The Confluence user\'s password. Can also be specified by the \'CONFLUENCE_PASSWORD\' environment variable.') do |pageId|
    options[:password] = pageId
  end

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Output more information') do
    options[:verbose] = true
  end

  options[:edit] = nil
  opts.on('-e', '--edit URL', 'URL of the source document') do |edit|
    options[:edit] = edit
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!

# page_id is a required argument
raise OptionParser::MissingArgument, '-p PAGE_ID is a required argument' if options[:pageId].nil?

user = ENV['CONFLUENCE_USER'] || options[:user] || ''
password = ENV['CONFLUENCE_PASSWORD'] || options[:password] || ''

opts = options[:verbose] ? {} : {log: false}
cs = ConfluenceSoap.new("#{options[:server]}/rpc/soap-axis/confluenceservice-v2?wsdl", user, password, opts)

uploader_page = cs.get_page(options[:pageId])

if uploader_page.nil?
  puts "exiting... could not find pageId: #{options[:pageId]}"
  exit
end

begin
  text = File.read(options[:markdownFile])

  # pdericson
  text.gsub!(/</, 'aeloo9jieV6ahbiesusheteeseuroonu')

  @convertedText = "#{Kramdown::Document.new(text, :input => 'GFM').to_confluence}"
rescue Exception => ex
  warn "There was an error running the converter: \n#{ex}"
end

#@convertedText = "#{@convertedText}\n\n(rendered at #{Time.now.getutc} by md2confl)"

if not options[:edit].nil?
  @convertedText = "{info}The rest of this page is authored [here|#{options[:edit]}].  You can add content above and it will not be overwritten.{info}\n\n#{@convertedText}"
end

# pdericson This is to avoid \<br... in the rendered output.
@convertedText.gsub!(/\\(?=\n)/, '')

# pdericson
@convertedText.gsub!(/aeloo9jieV6ahbiesusheteeseuroonu/, '<')

match = uploader_page.content.match(/(.*?)<ac:structured-macro ac:name="info" ac:schema-version="1" ac:macro-id=".*?"><ac:rich-text-body><p>The rest of this page is authored/m)
if match
  uploader_page.content = match[1] + cs.convert_wiki_to_storage_format(@convertedText)
else
  uploader_page.content = cs.convert_wiki_to_storage_format(@convertedText)
end
options = {minorEdit: true, versionComment: 'updated by md2confl'}
cs.update_page(uploader_page)
