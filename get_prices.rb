#!/usr/bin/env ruby

# encoding: UTF-8
require 'mechanize'
require 'pry'

stores = {
  ebay: {},
  infibeam: {},
  flipkart: {
    search_url: "http://www.flipkart.com/search/a/all?query=%s",
    item_css_path: ".fk-product-thumb",
    price_css_path: ".fk-price .price",
    title_css_path: "a.fk-anchor-link",
  },
  junglee: {}
}

def fetch_and_display_prices_from(store_name, store_metadata, search_term)
  search_url = store_metadata[:search_url]
  search_url = search_url.gsub("%s", search_term)
  puts "Looking up #{store_name}: #{search_url}"


  agent = Mechanize.new
  page = agent.get(search_url)
  search_for_item_and_price(page, store_metadata)
end

def search_for_item_and_price(page, store_metadata)
  items = page.search(store_metadata[:item_css_path])
  items.each do |item|
    title = item.search(store_metadata[:title_css_path]).text.rstrip.lstrip
    price = item.search(store_metadata[:price_css_path]).text.rstrip.lstrip
    pp [title, price]
  end
end


search_term = ARGV[0] || "huggies"
stores.each_pair do |store, store_metadata|
  next if store_metadata.empty?
  fetch_and_display_prices_from(store, store_metadata, search_term)
end
