#!/usr/bin/env ruby

require_relative 'monkey_patches'
require 'awesome_print'
require 'gnucash'

class ReportGenerator
  def initialize(file)
    puts "Reading book..."
    book = Gnucash.open(file)
    @accounts = Hash.recursive

    date_range = Date.new(2017, 04, 01)..Date.new(2017, 04, 30)
    results = {}
    puts "Reading accounts..."
    book.accounts.each do |account|
      add_account(account)

      attr_names = %i(type id placeholder full_name transactions)
      attrs = attr_names.map { |attr| [attr, account.send(attr)] }.to_h
      total = attrs[:transactions]
        .select { |t| date_range.include?(t.date) }
        .map(&:value)
        .map(&:val)
        .reduce(&:+)

      results[attrs[:full_name]] = total || 0
    end
    File.open("april.csv", "w") { |file| file.write(results.to_a.sort.map{|v| v.join(',')}.join("\n")) }
  end

  def add_account(account)
    name = account.full_name
    *parent_path, account_name = name.split(":")
    parent = @accounts.get(parent_path)[account_name] = account
  end
end

gen = ReportGenerator.new("/Users/aj/budget/accounts.gnucash")
