module Rasstimer
	class Subtime
		def initialize(str)
			m = str.match(/^(\d+?):(\d+?):(\d+?)\.(\d+?)$/);

			if not m 
				raise "Unknown time string format: '#{str}'"
			end

			@miliseconds  = 0
			@miliseconds += m[1].to_i * 3600000
			@miliseconds += m[2].to_i * 60000
			@miliseconds += m[3].to_i * 1000
			@miliseconds += m[4].to_i * 10
		end

		def adjust!(msec)
			if @miliseconds + msec < 0
				raise "Cant set timing lower than zero, original was: #{@miliseconds}"
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
	end
	
	class Dialogue < Hash
		def initialize(format, line)
			@format = format

			parts = line.sub(/^Dialogue:\s+/, '').split(/,/)
			parts.each_with_index { |e, i| self[@format[i]] = e.strip }

			if parts.length > @format.length
				self[:Text] += ',' + parts[@format.length..(parts.length - 1)].join(',')
			end

			self[:Start] = Subtime.new(self[:Start])
			self[:End]   = Subtime.new(self[:End])
		end

		def to_s
			"Dialogue: " + @format.map { |k| self[k] }.join(',')
		end

		def shift!(msec)
			self[:Start].adjust!(msec)
			self[:End].adjust!(msec)
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


	class Subtitle 
		def initialize(file)
			@content   = []
			@dialogues = []
			
			unless file.respond_to? :readlines
				begin 
					file = File.open(file, 'r')
				rescue
					raise "cant open '#{file}' to read"
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
			p stop

			if start.to_i < 0
				raise "Selected dialogues start index cant be negative"
			end

			if stop.to_i > (@dialogues.length - 1)
				raise "Selected dialogues index cant be larger than dialogues count, given: #{stop}, dialogues count: #{@dialogues.length}"
			end
			
			for i in @dialogues[start]...@dialogues[stop]
				@content[i].shift!(msec)
			end
		end

		def save(file_name)
			self_opened = false
			file = file_name if file_name.respond_to? :puts

			unless file_name.respond_to? :puts
				begin 
					file = File.open(file_name, 'w')
					self_opened = true
				rescue
					raise "cant open '#{file_name}' to write"
				end
			end

			@content.each do |line| 
				file << line.to_s
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
