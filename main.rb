#!/usr/bin/ruby

require 'getoptlong'

class Subtitle 
	class Subtime
		def initialize(str)
			m = str.match(/^(\d+?):(\d+?):(\d+?)\.(\d+?)$/);

			@miliseconds  = 0
			@miliseconds += m[1].to_i * 3600000
			@miliseconds += m[2].to_i * 60000
			@miliseconds += m[3].to_i * 1000
			@miliseconds += m[4].to_i * 10
		end

		def adjust!(msec)
			@miliseconds += msec
		end

		def to_s
			msec = @miliseconds
			
			h = msec / 3600000
			msec -= h * 3600000
			h = h.to_s

			m = msec / 60000
			msec -= m * 60000
			m = (m).to_s.rjust(2, '0')

			s = msec / 1000
			msec -= s * 1000
			s = s.to_s.rjust(2, '0')

			ms = (msec / 10).to_s.rjust(2, '0')

			"#{h}:#{m}:#{s}.#{ms}"
		end
	end

	class Dialogue 
		def initialize(format, line)
			@format     = format
			@data       = {}

			parts = line.sub(/^Dialogue:\s+/, '').split(/,/)
			parts.each_with_index { |e, i| @data[@format[i]] = e.strip }

			if parts.length > @format.length
				@data[:Text] += ',' + parts[@format.length..(parts.length - 1)].join(',')
			end

			@data[:Start] = Subtime.new(@data[:Start])
			@data[:End]   = Subtime.new(@data[:End])
		end

		def to_s
			@format.map { |k| @data[k] }.join(',').map { |line| 'Dialogue: ' + line }
		end

		def method_missing(name, *args, &block)
			if @data.key? name
				@data[key]
			else
				super
			end
		end

		def shift!(msec)
			@data[:Start].adjust!(msec)
			@data[:End].adjust!(msec)
		end
	end

	class Format < Array

		def initialize(line)
			super()
			line.sub(/^Format:\s+/, '').split(/\s*,\s*/).each { |e| push(e.strip.to_sym) }
		end

		def to_s
			'Format: ' + map { |e| e.to_s }.join(', ')
		end
	end

	def initialize(file)
		@content   = []
		@dialogues = []
		
		if (!file.respond_to? :readlines)
			file = File.open(file, 'r')
		end

		format    = []
		in_events = false

		file.each_line do |line|
			save_line = line

			if /^\[Events\]/ =~ line
				in_events = true
			end

			if in_events and /^Format:\s+.+$/ =~ line
				save_line = format = Format.new(line)
			end

			if in_events and /^Dialogue:\s.+$/ =~ line
				save_line = Dialogue.new(format, line)
				@dialogues.push(@content.length)
			end

			@content.push(save_line)
		end
	end

	def shift_dialogues!(start, stop, msec)
		stop = (@dialogues.length - 1) if stop == -1
		
		for i in @dialogues[start]...@dialogues[stop]
			@content[i].shift!(msec)
		end
	end

	def save(file_name)
		file = File.new(file_name, 'w')

		@content.each do |line| 
			file.puts(line.to_s)
		end

		file.close
	end
end


in_path  = ''
out_path = ''
shift    = {}

opts = GetoptLong.new(
	[ '--help',  '-h',  GetoptLong::NO_ARGUMENT ],
	[ '--in',    '-i',  GetoptLong::REQUIRED_ARGUMENT ],
	[ '--out',   '-o',  GetoptLong::REQUIRED_ARGUMENT ],
	[ '--shift', '-s',  GetoptLong::REQUIRED_ARGUMENT ]
)

opts.each do |option, value|
	case option
	when '--in'
		in_path = value
	when '--out'
		out_path = value
	when '--shift'
		if m = value.match(/^(-?\d+),(\d+):(-?\d)/)
			shift = { :start => m[2].to_i, :end => m[3].to_i, :msec => m[1].to_i }
		else
			puts "usage: <delay>,start:stop"
			exit
		end
	when '--help'
		puts "usage: #{__FILE__} -i <in_path> -o <out_path> -s <delay>,<start>:<stop>"
		exit
	end
end

sub = Subtitle.new(in_path);
sub.shift_dialogues!(shift[:start], shift[:end], shift[:msec])
sub.save(out_path)
