#encoding=utf-8
require "pick_ja_date/version"

require 'rubygems'
require 'bundler'
Bundler.setup
require 'active_support/time'

class PickJaDate
  attr_accessor :input, :str, :time 

  KANJI_NUMBER = '一二三四五六七八九十'
  DAYS_OF_WEEK = %w{日 月 火 水 木 金 土}
  TODAY        = ['今日']
  TOMORROW     = ['明日', 'あした']
  DAT          = ['明後日', 'あさって'] # day after tomorrow

  def self.extract(str)
    p = self.new(str)
    p.parse
    [p.time, p.str] 
  end

  def self.date(str)
    p = self.new(str)
    p.parse
    p.time
  end

  def initialize(input)
    @input = input
    @now = Time.now
    @time = Time.now
    @str = input
  end

  def parse
    set_day
    set_time
  end

  def set_day
    num2 = '([0-9]{1,2})'

    match?(/再来月/){|x| 
      remove_time_word x[0]
      @time = (@time + 2.month)
    }

    match?(/来月/){|x| 
      remove_time_word x[0]
      @time = (@time + 1.month)
    }

    match?(%r{(([0-9]{2,4})[年/-])?#{num2}[月/-]#{num2}日?})do |x|
      all, y_with_suffix, y, m, d = x
      remove_time_word all
      y = @now.year unless y
      @time = @time.change(year: y.to_i, month: m.to_i, day: d.to_i)
      @time += 1.year if @time < @now
      return 
    end

    match?(/月末/){|x| 
      remove_time_word x[0]
      @time = @time.change(day: @now.end_of_month.day)
      return 
    }

    match?(/月初|[1一]日/){|x| 
      remove_time_word x[0]
      @time = (@time + 1.month).change(day: 1)
      return 
    }

    match?(%r{(次の)?(#{DAYS_OF_WEEK.join("|")})曜}) do |x|
      remove, dummy, dow_str = x
      remove_time_word remove
      @time += next_dow_days(dow_str).day
      return 
    end 

    match?(/#{(TODAY + TOMORROW + DAT).join('|')}/) do |x|
      case x.first
      when *TODAY;    add = 0
      when *TOMORROW; add = 1
      when *DAT;      add = 2
      end
      remove_time_word x.first
      @time += add.day
      return 
    end

    # N 日後
    units = '(分|時間|日|週間?|ヶ?月)'
    [
      /([0-9#{KANJI_NUMBER}]{1,2})#{units}後/,
      /あと([0-9]{1,2})#{units}/,
    ].each do |regex|
      match?(regex)do |x|
        str, num, unit = x
        add_unit_time kanji_to_number(num), unit
        remove_time_word str
      end
    end

    match?(%r{#{num2}日}){|x|
      remove_time_word x.first
      @time = @time.change(day: x[1])
    }
  end

  def set_time
    num = '([0-9]{1,2})'
    space = '[ 　]?'
    match?(/#{num}([:：])#{num}/){|x| set_time_result x[0], x[1], x[2]; return}
    match?(/#{num+space}時半/){|x|    set_time_result x[0], x[1], 30;   return}
    match?(/#{num+space}時/){|x|      set_time_result x[0], x[1], 0}
    match?(/#{num+space}分/){|x|      set_time_result x[0], @time.hour, x[1]}
  end

  def match?(regex)
    if @str =~ regex
      yield $~.to_a
    else
      nil
    end
  end

  def format(time)
    time.strftime '%Y/%m/%d %H:%M'
  end

  def set_time_result(remove, hour, min)
    remove_time_word remove
    hour = hour.to_i
    if hour > 24
      @time += (hour.div(24)).day 
      hour = hour % 24
    end
    @time = @time.change(hour: hour, min: min)
  end

  def remove_time_word(key)
    @str.sub!(%r{#{key}[のにで]?}, '')
    @str.sub!(%r{^[ 　]|[ 　]$}, '')
  end

  def next_dow_days(str)
    now = @now.wday
    target = DAYS_OF_WEEK.index(str).to_i
    target += 7 if target <= now
    (target - now)
  end

  def add_unit_time(num, unit)
    num = num.to_i
    case unit
    when '分';         @time += num.minute
    when '時間';       @time += num.hour
    when '日';         @time += num.day
    when '週間', '週'; @time += num.week
    when 'ヶ月', '月'; @time += num.month 
    end
  end

  def kanji_to_number(kanji)
    if i = KANJI_NUMBER.chars.index(kanji) 
      i + 1
    else
      kanji
    end
  end
end
