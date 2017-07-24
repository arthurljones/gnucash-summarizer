#!/usr/bin/env ruby

require_relative 'monkey_patches'
require 'awesome_print'
require 'gnucash'
require 'spreadsheet_architect'
require 'active_support/all'

class ReportGenerator
  def initialize(file, options)
    puts "Reading book..."
    @book = Gnucash.open(file)
    @accounts = Hash.recursive
    @book.accounts.each do |account|
      add_account(account)
    end
    @options = options

    expenses = @book.accounts.select{ |account| account.full_name.start_with?("Expenses") }
    summary = summary_by_month(expenses)
    all_months = summary.values.map(&:keys).flatten.uniq
    rows = []
    summary.each do |account, months|
      rows << [account] + all_months.map{ |month| months[month] || 0.0 }
    end
    puts("Writing spreadsheet")
    data = SpreadsheetArchitect.to_ods(data: rows, headers: ["Account"] + all_months)
    File.open("monthly.ods", "w") { |f| f.write(data) }
  end

  def write_summary
    output = results
      .to_a
      .sort
      .map{ |v| v.join(',') }
      .join("\n")

    File.open("#{file}.csv", "w") { |file| file.write(output) }
  end

  def summary_by_month(accounts)
    results = {}
    puts "Reading accounts..."

    accounts.each do |account|
      #attr_names = %i(type id placeholder full_name transactions)
      totals = account.transactions
        .group_by { |t| [t.date.year, t.date.month] }
        .map do |(year, month), transactions| 
          value = transactions
            .map(&:value)
            .map(&:val)
            .reduce(&:+) || 0
          if value == 0 && @options[:omit_zero]
            nil
          elsif year < 2017
            nil
          else
            value = value / 100.0
            [Date.civil(year, month, 1).strftime("%Y-%m"), value]
          end
        end.compact.to_h

      results[account.full_name] = totals if totals.any?
    end
    results
  end

  def add_account(account)
    name = account.full_name
    *parent_path, account_name = name.split(":")
    @accounts.get(parent_path)[account_name] = account
  end
end

gen = ReportGenerator.new("/Users/aj/budget/accounts.gnucash", omit_zero: true)
