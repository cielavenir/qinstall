#!/usr/bin/env ruby
#QInstall: Sun/Univa Grid Engine qsub Helper
#(C) T. Yamada under 2-clause BSDL.

#0.01.110927 qinstall_binary
#0.02.1110xx qinstall_script (fixed passing shebang option)
#0.03.130627 Rewritten in Ruby. qinstall_stdin (fixed S/UGE daemon's PATH handling)
#0.04.180802 Unquote <>|. Added Python edition.
#0.10.180802 qinstall can be required.

# also determine which to use bashrc or cshrc
SHELL='/bin/bash'

def mywhich(name)
	return name if File.exists?(name) #relative/absolute
	ENV['PATH'].split(':').each{|path|
		exe=path+'/'+name
		return exe if File.exists?(exe)
	}
	nil
end

class Hash
	def tostring(delim=',') # ',' for UGE, '&' for query, ';' for cookie
		self.map{|k,v|k.to_s+'='+v.to_s}*delim
	end
end

class String
	def mychomp() self.sub(/\n$/,'').sub(/\r$/,'') end
	def mychomp!() self.replace(self.mychomp) end
end

class Array
	def joinargv
		return '' if self.empty?
		return self.map(&:to_s).map{|e|%w(< > |).include?(e) ? e : "'"+e+"'"}.join(' ')
	end
end

def qinstall(argv,mode='qinstall_stdin')
	i=0
	n_specified=false
	while i<argv.size
		break if argv[i][0]!=?-
		if argv[i]=='-pe'
			i+=3
		else
			n_specified=true if argv[i]=='-N'
			i+=2
		end
	end
	file=mywhich(argv[i])
	raise "File not found" if !file
	raise "#{file} not executable" unless File::Stat.new(file).executable?
	raise "#{file} not readable" unless f=File.open(file,'rb')
	shebang=f.gets
	f.close

	if mode.start_with?('qinstall_binary')||mode.start_with?('qinstall_script')
		loader=''
		if shebang[0,2]=='#!'
			shebang=shebang.mychomp[2..-1].split
			exe=shebang.shift
			exe=mywhich(shebang.shift) if exe.end_with?('/env')
			if mode.start_with?('qinstall_binary')
				loader=%Q(-N "#{File.basename(file)}" ) if !n_specified
				loader+=%Q(-b y "#{exe}" #{shebang*' '})
			else
				loader="-S #{exe}"
			end
		else
			loader='-b y'
		end
		arg=
			%Q(qsub -cwd )+
			%Q(-v "#{ENV.to_hash.tostring}" )+
			%Q(#{argv[0,i].joinargv} #{loader} #{argv[i..-1].joinargv})
		#puts arg
		system(arg)
	else
		loader=''
		shell=SHELL
		file_is_sh=false
		if shebang[0,2]=='#!'
			shebang=shebang.mychomp[2..-1].split
			exe=shebang.shift
			exe=mywhich(shebang.shift) if exe.end_with?('/env')
			file_is_sh=exe.end_with?('sh')&&exe.end_with?('csh')==SHELL.end_with?('csh')
			shell=exe if file_is_sh #We can directly execute file using exe.
		end
		if !file_is_sh&&file=~/\..?sh$/ #extension is sh
			file_is_sh=file.end_with?('.csh')==SHELL.end_with?('csh') #file seems to be sh. We can directly execute file using SHELL.
		end
		loader=%Q(-N "#{File.basename(file)}" ) if !n_specified
		loader+="-S #{shell}"
		if file_is_sh
			system("qsub -cwd #{argv[0,i].joinargv} #{loader} #{argv[i..-1].joinargv}")
		else
			#file is not sh, so we need to wrap it with pseudo shell script.
			IO.popen(['qsub','-cwd',argv[0,i].joinargv,loader],'w'){|io|
				io.puts(argv[i..-1].joinargv)
				io.close_write
			}
		end
	end
end

if __FILE__==$0
	if ARGV.empty?
		STDERR.puts "Usage: qinstall [qsub_options...] exe [args...]"
		STDERR.puts "useful options:"
		STDERR.puts "-l complex -q queue"
		STDERR.puts "-l s_vmem=NG -l mem_req=N (NGB memory will be used)"
		STDERR.puts "-i stdin -o stdout -e stderr"
		STDERR.puts "note: in args, <>| must be QUOTED."

		exit 1
	end
	qinstall(ARGV,File.basename($0))
end
