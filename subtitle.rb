module Rasstimer
	class Subtime
		attr_reader :miliseconds
		def initialize(str)
			m = str.match(/^(\d+?):(\d+?):(\d+?)\.(\d+?)$/);

			if not m 
				fail "Unknown time string format: '#{str}'"
			end

			@miliseconds  = 0
			@miliseconds += m[1].to_i * 3600000
			@miliseconds += m[2].to_i * 60000
			@miliseconds += m[3].to_i * 1000
			@miliseconds += m[4].to_i * 10
		end

		def adjust!(msec)
			if @miliseconds + msec < 0
				fail "Cant set timing lower than zero, original was: #{@miliseconds}"
			end
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

		def -(lhs)
			 @miliseconds - lhs.miliseconds
		end
		
		def to_seconds
			msec = @miliseconds
			s = msec / 1000
			msec -= s * 1000
			s.to_s.rjust(2, '0')
			ms = (msec / 10).to_s.rjust(2, '0')
			"#{s}.#{ms}"
		end
	end
	
	class Dialogue
		def initialize(format, line)
			@data = {};
			@format = format

			parts = line.sub(/^Dialogue:\s+/, '').split(/,/)
			parts.each_with_index { |e, i| @data[@format[i]] = e.strip }

			if parts.length > @format.length
				@data[:Text] += ',' + parts[@format.length..(parts.length - 1)].join(',')
			end

			@data[:Start] = Subtime.new(@data[:Start])
			@data[:End]   = Subtime.new(@data[:End])
		end

		def to_s
			"Dialogue: " + @format.map { |k| @data[k] }.join(',')
		end

		def shift!(msec)
			@data[:Start].adjust!(msec)
			@data[:End].adjust!(msec)
		end

		def showtime
			@data[:End] - @data[:Start]
		end

		def info
			"#{@data[:Start].to_seconds}\t#{showtime}\t#{@data[:Text]}"
		end
		
		def [](k)
			@data[k]
		end
		def []=(k, v)
			@data[k] = v
		end
	end

	class Format
		def initialize(line)
			@data = []
			line.sub(/^Format:\s+/, '').split(/\s*,\s*/).each { |e| @data.push(e.strip.to_sym) }
		end

		def to_s
			'Format: ' + @data.map { |e| e.to_s }.join(', ')
		end

		def method_missing(*args, &b)
			@data.__send__(*args, &b)
		end
	end


	class Subtitle 

		attr_reader :dialogues
		attr_reader :content

		def initialize(file)
			@content   = []
			@dialogues = []
			
			unless file.respond_to? :readlines
				begin 
					file = File.open(file, 'r')
				rescue
					fail "cant open '#{file}' to read"
				end
			end

			in_events = false
			format    = nil

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

			if start.to_i < 0
				fail "Selected dialogues start index cant be negative"
			end

			if stop.to_i > (@dialogues.length - 1)
				fail "Selected dialogues index cant be larger than dialogues count, given: #{stop}, dialogues count: #{@dialogues.length}"
			end
			
			for i in @dialogues[start]...@dialogues[stop]
				@content[i].shift!(msec)
			end
		end

		def save(file_name)
			self_opened = false
			file = file_name if file_name.respond_to? :<<

			unless file_name.respond_to? :<<
				begin 
					file = File.open(file_name, 'w')
					self_opened = true
				rescue
					fail "cant open '#{file_name}' to write"
				end
			end

			@content.each do |line| 
				file << line.to_s 
				file << "\n" unless line.to_s.end_with? "\n"
			end

			file.close if self_opened
			return file
		end

		def info
			{ 
				:dialogues_count => @dialogues.count,
				:dialogues       => @content.values_at(*@dialogues)
			}
		end
	end
end
