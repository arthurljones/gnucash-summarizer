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
    all_months = summary.values.map(&:keys).flatten.uniq.sort
    rows = []
    summary.each do |account, months|
      monthly_sums = all_months.map{ |month| months[month] || 0.0 }
      # Chop off the current month for the purpose of averages
      prev_months = monthly_sums.slice(0..-2)
      if prev_months.any?
        monthly_average = (prev_months.reduce(&:+) / prev_months.size).round(2)
      else
        monthly_average = monthly_sums.first
      end
      ytd = monthly_sums.reduce(&:+) 
      rows << [account] + monthly_sums + [monthly_average, ytd]
    end
    # Sort by the monthly average, descending
    #rows.sort_by!(&:last).reverse!
    puts("Writing spreadsheet")
    data = SpreadsheetArchitect.to_ods(data: rows, headers: ["Account"] + all_months + ["Monthly Avg", "YTD"])
    File.open("monthly.ods", "w") { |f| f.write(data) }
  end

  def summary_by_month(accounts)
    results = {}
    puts "Reading accounts..."

    accounts.each do |account|
      #attr_names = %i(type id placeholder full_name transactions)
      by_month = account.transactions.group_by { |t| [t.date.year, t.date.month] }
      totals = by_month.map do |(year, month), transactions| 
        value = transactions
          .map(&:value)
          .map(&:val)
          .reduce(&:+) || 0
        if value == 0 && @options[:omit_zero]
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

gen = ReportGenerator.new("/Users/aj/budget/accounts-2019.gnucash", omit_zero: true)
