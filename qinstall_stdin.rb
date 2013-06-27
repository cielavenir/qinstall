#!/usr/bin/env ruby
#QInstall: Sun/Univa Grid Engine qsub Helper
#(C) T. Yamada under 2-clause BSDL.

#0.01.110927 qinstall_binary
#0.02.1110xx qinstall_script (fixed passing shebang option)
#0.03.130627 Rewritten in Ruby. qinstall_stdin (fixed S/UGE daemon's PATH handling)

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
	def tostring
		self.map{|k,v|k.to_s+'='+v.to_s}*','
	end
end

class String
	def mychomp() self.sub(/\n$/,'').sub(/\r$/,'') end
	def mychomp!() self.replace(self.mychomp) end
end

class Array
	def joinargv
		return '' if self.empty?
		return " \""+self.join("\" \"")+"\" "
	end
end

#main
if ARGV.empty?
	puts "Usage: qinstall [qsub_options...] exe [args...]"
	puts "useful options:"
	puts "-l complex -q queue"
	puts "-l s_vmem=NG -l mem_req=N (NGB memory will be used)"
	puts "-i stdin -o stdout -e stderr"
	
	exit
end
i=0
n_specified=false
while i<ARGV.size
	break if ARGV[i][0..0]!='-'
	if ARGV[i]=='-pe'
		i+=3
	else
		n_specified=true if ARGV[i]=='-N'
		i+=2
	end
end
file=mywhich(ARGV[i])
raise "File not found" if !file
raise "#{file} not executable" unless File::Stat.new(file).executable?
raise "#{file} not readable" unless f=File.open(file,'rb')
shebang=f.gets
f.close

basename=File.basename($0)
if basename.start_with?('qinstall_binary0')||basename.start_with?('qinstall_script')
	loader=''
	if shebang[0,2]=='#!'
		shebang=shebang.mychomp[2..-1].split
		exe=shebang.shift
		exe=mywhich(shebang.shift) if exe.end_with?('/env')
		if basename.start_with?('qinstall_binary')
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
		%Q(#{ARGV[0,i].joinargv} #{loader} #{ARGV[i..-1].joinargv})
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
		file_is_sh=exe.end_with?('csh')==SHELL.end_with?('csh')
		shell=exe if file_is_sh #We can directly execute file using exe.
	end
	if !file_is_sh&&file=~/\..?sh$/ #extension is sh
		file_is_sh=file.end_with?('.csh')==SHELL.end_with?('csh') #file seems to be sh. We can directly execute file using SHELL.
	end
	loader=%Q(-N "#{File.basename(file)}" ) if !n_specified
	loader+="-S #{shell}"
	if file_is_sh
		system("qsub -cwd #{ARGV[0,i].joinargv} #{loader} #{ARGV[i..-1].joinargv}")
	else
		#file is not sh, so we need to wrap it with pseudo shell script.
		IO.popen("qsub -cwd #{ARGV[0,i].joinargv} #{loader}",'w'){|io|
			io.puts(ARGV[i..-1].joinargv)
			io.close_write
		}
	end
end