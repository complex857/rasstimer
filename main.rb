#!/usr/bin/ruby

require 'getoptlong'
require File.dirname(__FILE__)+'/subtitle.rb'

in_path  = ''
out_path = ''
shift    = {}

opts = GetoptLong.new(
	['--help',  '-h', GetoptLong::NO_ARGUMENT ],
	['--in',    '-i', GetoptLong::REQUIRED_ARGUMENT ],
	['--out',   '-o', GetoptLong::OPTIONAL_ARGUMENT ],
	['--shift', '-s', GetoptLong::REQUIRED_ARGUMENT ],
	['--info',  '-n', GetoptLong::REQUIRED_ARGUMENT ],
	['--fields', '-f', GetoptLong::OPTIONAL_ARGUMENT ],
)

def usage
	puts "usage: "
	puts "\t#{__FILE__} -i <in_path> -o <out_path> -s <delay>,<start>:<stop>"
	puts "\t#{__FILE__} --info <in_path> [--fields <field0[,field1,...]>]"
end

job = :shift
fields = []

opts.each do |option, value|
	case option
		when '--in'
			in_path = value
		when '--out'
			out_path = value
		when '--shift'
			if m = value.match(/^(-?\d+),(\d+):?(-?\d)?/)
				shift = { :start => m[2].to_i, :end => (m.size == 3 ? m[3].to_i : -1), :msec => m[1].to_i }
			else
				usage
				exit
			end
		when '--help'
			usage
			exit
		when '--info'
			job = :info
			in_path = value
		when '--fields'
			fields = value.split(',').map(&:chomp)
	end
end

case job
	when :shift
		if in_path == '' 
			usage
			exit
		end

		out_path = STDOUT if out_path == ''

		sub = Rasstimer::Subtitle.new(in_path);
		sub.shift_dialogues!(shift[:start], shift[:end], shift[:msec])
		sub.save(out_path)
	when :info
		sub = Rasstimer::Subtitle.new(in_path)
		fields = [:Start, :End, :Text] unless fields.size > 0
		info = sub.info
		puts "#{info[:dialogues_count]} dialogue line"
		sub.info[:dialogues].each_with_index do |e, i|
			puts "#{i}: #{fields.map { |f| e[f.to_s.capitalize.to_sym] }.join(', ')}"
		end
end
