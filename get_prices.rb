#!/usr/bin/env ruby

# encoding: UTF-8
require 'mechanize'
require 'celluloid'
require 'money'
require 'pry'

Money.default_currency = Money::Currency.new("INR")
Money.assume_from_symbol = true

class StoreConfig
  CONFIG = {
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
  }.freeze

  def self.stores
    CONFIG.keys
  end

  def self.metadata_for(store)
    CONFIG[store.to_sym]
  end
end

class Scraper
  include Celluloid

  def scrape(store, search_term)
    search_url_template = StoreConfig.metadata_for(store)[:search_url]
    search_url = search_url_template.gsub("%s", search_term)
    puts "#{store}: #{search_url}"

    begin
      [ store, Mechanize.new.get(search_url) ]
    rescue => ex
      puts "  !!! Could not fetch: #{ex.class.name}: #{ex.message}"
    end
  end
end

class Parser
  def initialize(store)
    @store = store
  end

  def items(search_results_page, max_items: 3)
    max_items = StoreConfig.metadata_for(@store)[:max_items] || max_items
    item_css_path = StoreConfig.metadata_for(@store)[:item_css_path]
    search_results_page.search(item_css_path).take(max_items)
  end

  def title(item)
    parse_attribute(item, :title)
  end

  def price(item)
    price_text = parse_attribute(item, :price)
    Money.parse(price_text.gsub(/Rs.\s+/, "INR "))
  end

  private
  def parse_attribute(item, attribute)
    css_path_config_key = "#{attribute}_css_path".to_sym
    css_path = StoreConfig.metadata_for(@store)[css_path_config_key]
    item.search(css_path).text.rstrip.lstrip
  end
end

SearchResult = Struct.new(:store, :title, :price)

class Aggregator
  def run(search_term)
    puts "search for: #{search_term}"
    results = []

    scraper_pool = Scraper.pool(size: 6)
    futures = StoreConfig.stores.map do |store|
      scraper_pool.future(:scrape, store, search_term)
    end
    search_results_by_store = futures.map(&:value)

    search_results_by_store.each do |store, search_results_page|
      next if search_results_page.nil?

      parser = Parser.new(store)
      results += parser.items(search_results_page).inject([]) do |collection, item|
        collection << SearchResult.new(
          store, parser.title(item), parser.price(item)
        )
      end
    end
    report(results)
  end

  def report(results)
    format = "%-10s  %-90s  %-11s"
    puts "\nAggregated reults:"
    puts sprintf(format, :store, :title, :price)
    puts sprintf(format, '='*10, '='*90, '='*11)
    format = "%-10s  %-90s  %11s"
    results.flatten.sort_by(&:price).each do |result|
      puts sprintf(format, result.store, result.title, result.price.format)
    end
  end
end

search_term = ARGV.join("+")
Aggregator.new.run(search_term || "huggies")
