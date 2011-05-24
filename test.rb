require 'rubygems'
require File.realpath File.join(File.dirname(__FILE__), "subtitle.rb")

require 'minitest/autorun'
require 'wrong'
require 'wrong/adapters/minitest'
include Wrong::Assert
include Rasstimer


class SubtimeTest < MiniTest::Unit::TestCase
	def test_create_with_proper_timestring
		time = 	Subtime.new('0:00:51.65')
		assert { time.miliseconds ==  51650 }
	end

	def test_create_from_fixnum
		time = 	Subtime.new(51650)
		assert { time.miliseconds == 51650 }
	end

	def test_create_raise_exception_for_invalid_string
		assert{ rescuing{ Subtime.new('wrongly formated string')}.message =~ /^Unknown time string format/ }
	end

	def test_to_s_return_the_same_as_input
		input ='0:00:51.65' 
		time = 	Subtime.new(input)
		assert { time.to_s == input }
	end
	
	def test_adjust_adds_given_number_to_miliseconds
		input = '0:00:51.65' 
		time = 	Subtime.new(input)
		time.adjust! 1000
		assert { time.miliseconds == 52650 }
		assert { time.to_s == '0:00:52.65' }
	end
end

class TestFormat < MiniTest::Unit::TestCase
	def setup
		@validformatstring = 'Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text'
	end
	def test_create_from_valid_string
		format = Format.new(@validformatstring)
		assert { format.count == 10 }
		assert { format ==  %w{Marked Start End Style Name MarginL MarginR MarginV Effect Text}.map(&:to_sym)}
	end

	def test_to_s_returns_the_same_as_input
		format = Format.new(@validformatstring)
		assert { format.to_s == @validformatstring }
	end
end

class TestDialogue < MiniTest::Unit::TestCase
	def setup
		@format = Format.new('Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text')
		@validline = 'Dialogue: Marked=0,0:01:14.40,0:01:16.15,Default,NTP,0000,0000,0000,!Effect,He just had a strange, look to him...'
	end

	def test_creates_from_valid_string
		d = Dialogue.new @format, @validline
		{
			Marked:   'Marked=0',
			Start:    '0:01:14.40',
			End:      '0:01:16.15',
			Style:    'Default',
			Name:     'NTP',
			MarginL:  '0000',
			MarginR:  '0000',
			MarginV:  '0000',
			Effect:   '!Effect',
			Text:     'He just had a strange, look to him...',
		}.each do |key, value| 
			assert { d[key].to_s == value }
		end
	end

	def test_to_s_returns_the_same_as_the_input
		d = Dialogue.new @format, @validline
		assert { d.to_s == @validline }
	end

	def test_creates_subtime_from_start_and_end_timestamps
		d = Dialogue.new @format, @validline
		assert { d[:Start].is_a? Subtime }
		assert { d[:End].is_a? Subtime }
	end

	def test_shiftbang_adjustes_the_start_and_end_time_with_the_same_value
		d = Dialogue.new @format, @validline
		old_start, old_end = d[:Start].miliseconds, d[:End].miliseconds 
		d.shift! 1000
		assert { d[:Start].miliseconds - old_start == d[:End].miliseconds - old_end }
	end
end
