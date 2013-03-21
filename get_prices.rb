#!/usr/bin/env ruby

# encoding: UTF-8
require 'mechanize'
require 'pry'

stores = {
  flipkart: {
    search_url: "http://www.flipkart.com/search/a/all?query=%s",
    item_css_path: ".fk-product-thumb",
    title_css_path: "a.fk-anchor-link",
    price_css_path: ".fk-price .price",
    max_items: 5,
  },
  junglee: {
    search_url: "http://www.junglee.com/mn/search/junglee?field-keywords=%s",
    item_css_path: ".result.product",
    title_css_path: ".data a.title",
    price_css_path: ".data .price",
  },
  ebay: {
    search_url: "http://search.ebay.in/%s",
    item_css_path: "#ResultSetItems *[itemprop=offers]",
    title_css_path: "a.vip",
    price_css_path: "*[itemprop=price]",
  },
  infibeam: {
    search_url: "http://www.infibeam.com/search?q=%s",
    item_css_path: "#search_result li",
    title_css_path: ".title",
    price_css_path: ".price .price",
  },
}

def fetch_and_display_prices_from(store_name, store_metadata, search_term)
  search_url = store_metadata[:search_url]
  search_url = search_url.gsub("%s", search_term)
  puts "\n#{store_name}: #{search_url}"

  agent = Mechanize.new
  page = agent.get(search_url)
  search_for_item_and_price(page, store_metadata).each do |title, price|
    puts sprintf("  %-100s    %10s", title, price)
  end
end

def search_for_item_and_price(page, max_items: 3, **store_metadata)
  items = page.search(store_metadata[:item_css_path])
  items.take(max_items).map do |item|
    title = item.search(store_metadata[:title_css_path]).text.rstrip.lstrip
    price = item.search(store_metadata[:price_css_path]).text.rstrip.lstrip
    [title, price]
  end
end

search_term = ARGV.join("+")
search_term ||= "huggies"
puts "search for: #{search_term}"
stores.each_pair do |store, store_metadata|
  next if store_metadata.empty?
  begin
    fetch_and_display_prices_from(store, store_metadata, search_term)
  rescue => ex
    puts "  Could not fetch: #{ex.class.name}: #{ex.message}"
  end
end
