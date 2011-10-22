require 'rubygems'
require File.realpath File.join(File.dirname(__FILE__), "subtitle.rb")

require 'minitest/autorun'
require 'wrong'
require 'wrong/adapters/minitest'
include Wrong::Assert
include Rasstimer


class TestSubtime < MiniTest::Unit::TestCase
	def setup
		@input = '0:00:51.65'
		@time = Subtime.new(@input)
		@time_in_milisecs = 51650
	end

	def test_create_with_proper_timestring
		assert { @time.miliseconds ==  @time_in_milisecs }
	end

	def test_create_from_fixnum
		assert { @time.miliseconds == @time_in_milisecs }
	end

	def test_create_raise_exception_for_invalid_string
		assert{ rescuing{ Subtime.new('wrongly formated string')}.message =~ /^Unknown time string format/ }
	end

	def test_to_s_return_the_same_as_input
		assert { @time.to_s == @input }
	end
	
	def test_adjust_adds_given_number_to_miliseconds
		@time.adjust! 1000
		assert { @time.miliseconds == @time_in_milisecs + 1000 }
		assert { @time.to_s == '0:00:52.65' }
	end

	def test_adjust_raise_error_on_shift_resulting_negative_timestamp
		assert{ rescuing{ @time.adjust! -100_000 }.message =~ /^Cant set timing lower than zero/ }
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

class SubtitleTest < MiniTest::Unit::TestCase
	def setup
		@test_file = 'test.ass'
		@dialogue_line_nos = (11..13).to_a

		@plus_1_sec_timeings = [
			'0:00:49.07','0:00:52.65',
			'0:00:56.84','0:01:01.25',
			'0:01:15.40','0:01:17.15',
		]

		@sub = Subtitle.new @test_file
	end

	def test_loads_a_subitle_file_correctly
		assert { @sub.dialogues == @dialogue_line_nos }
		
		@dialogue_line_nos.each do |i| 
			assert { @sub.content[i].is_a? Dialogue }
		end

		info = @sub.info
		assert { info[:dialogues_count] = 3 }
	end

	def test_shift_dialogues_shift_selected_dialogues
		@sub.shift_dialogues! 0, 2, 1000

		time_i = 0
		assert { @plus_1_sec_timeings == @sub.dialogues.map { |i| [@sub.content[i][:Start].to_s, @sub.content[i][:End].to_s] }.flatten }

		# rewind	
		@sub.shift_dialogues! 0, 2, -1000

		# now use -1 as end index, should make end == dialogues.size - 1
		@sub.shift_dialogues! 0, -1, 1000
		assert { @plus_1_sec_timeings == @sub.dialogues.map { |i| [@sub.content[i][:Start].to_s, @sub.content[i][:End].to_s] }.flatten }
	end

	def test_shift_refuse_invalid_indexes
		assert{ rescuing{ @sub.shift_dialogues! -1,  2, 1000 }.message =~ /^Selected dialogues start index cant be negative/i }
		assert{ rescuing{ @sub.shift_dialogues!  3,  2, 1000 }.message =~ /^Stop index cant be smaller than start index!/i }
		assert{ rescuing{ @sub.shift_dialogues!  0,  9, 1000 }.message =~ /^Selected dialogues index cant be larger than dialogues count/i }
	end

	def test_save_should_output_the_same_as_input_without_shifting
		out = []
		@sub.save(out)

		assert { out == IO.readlines(@test_file) }
	end
end
