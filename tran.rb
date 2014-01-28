#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'json'
require 'pp'

SRC_LANG = 'auto'
TO_LANG  = 'uk'
URL      = 'http://translate.google.com/translate_a/t'

def retrieve(params)
  uri = URI.parse(URL)
  uri.query = URI.encode_www_form(params)
  http = Net::HTTP.new(uri.host)
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Accept-Charset'] = 'utf-8'
  request['User-Agent'] = 'Mozilla/5.0'
  response = http.request(request)
  return response
end

def get_result(data)
  output = ''

  parse_item = lambda do |item, depth|
    if item.is_a? Array
      item.each do |nested_item|
        if nested_item.is_a? Array
          parse_item.call(nested_item, depth + 1)
        elsif nested_item.is_a? String
          if nested_item.length != 0
            output += "\t" * depth if depth > 0
            output += nested_item + "\n"
          end
        end
      end
    elsif item.is_a? String
      if item.length != 0
        output += "\t" * depth if depth > 0
        output += item + "\n"
      end
    end
  end

  parse_item.call(data, -1)
  # output = output.encode('UTF-8',:invalid=>:replace, :replace=>"?")
  return output
end

def main
  params = { :client => 't', :sl => SRC_LANG, :tl => TO_LANG }
  params[:text] = ARGV[0]
  data = JSON.parse(retrieve(params).body.gsub(/,{2,}/, ',').gsub(/\[,/,'[').gsub(/,\]/,']'))
  puts "Translation: %s > %s\n\n" % [ SRC_LANG, TO_LANG ]
  puts get_result(data)
end

main()
