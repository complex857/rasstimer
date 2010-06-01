#!/usr/bin/ruby

require 'getoptlong'
require File.dirname(__FILE__)+'/subtitle.rb'

in_path  = ''
out_path = ''
shift    = {}

opts = GetoptLong.new(
	['--help',  '-h', GetoptLong::NO_ARGUMENT ],
	['--in',    '-i', GetoptLong::REQUIRED_ARGUMENT ],
	['--out',   '-o', GetoptLong::REQUIRED_ARGUMENT ],
	['--shift', '-s', GetoptLong::REQUIRED_ARGUMENT ],
	['--info',  '-n', GetoptLong::REQUIRED_ARGUMENT ]
)

def usage
	puts "usage: \n\t#{__FILE__} -i <in_path> -o <out_path> -s <delay>,<start>:<stop>\n\t#{__FILE__} --info <in_path>"
end

job = :shift

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
			usage
			exit
		end
	when '--help'
		usage
		exit
	when '--info'
		job = :info
		in_path = value
	end
end

case job
when :shift
	if in_path == '' || out_path == ''
		usage
		exit
	end

	sub = Rasstimer::Subtitle.new(in_path);
	sub.shift_dialogues!(shift[:start], shift[:end], shift[:msec])
	sub.save(out_path)
when :info
	sub = Rasstimer::Subtitle.new(in_path)
	info = sub.info
	puts "#{info[:dialogues_count]} dialogue line"
	sub.info[:dialogues].each_with_index do |e, i|
		puts "#{i}: #{e[:Text]}"
	end
	exit
end
