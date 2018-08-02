#!/usr/bin/env python
#QInstall: Sun/Univa Grid Engine qsub Helper
#(C) T. Yamada under 2-clause BSDL.

import os,re
import subprocess

# also determine which to use bashrc or cshrc
SHELL='/bin/bash'

def mywhich(name):
	if os.path.exists(name):
		#relative/absolute
		return name
	for path in os.environ['PATH'].split(':'):
		exe=path+'/'+name
		if os.path.exists(exe): return exe

def mychomp(s):
	if s[-1]=='\n': s=s[0:-1]
	if s[-1]=='\r': s=s[0:-1]
	return s

def joinargv(a):
	if not a: return ''
	return ' '.join(e if e in ['<','>','|'] else "'"+e+"'" for e in a)

def qinstall(argv):
	i=0
	n_specified=False
	while i<len(argv):
		if argv[i][0]!='-':
			break
		if argv[i]=='-pe':
			i+=3
		else:
			if argv[i]=='-N': n_specified=True
			i+=2
	file=mywhich(argv[i])
	if not file: raise Exception("File not found")
	if not os.access(file,os.X_OK): raise Exception("%s not executable"%file)
	try:
		with open(file,'rb') as f:
			shebang=f.readline()
	except IOError:
		raise Exception("%s not readable"%file)

	loader=''
	shell=SHELL
	file_is_sh=False
	if shebang[:2]=='#!':
		shebang=mychomp(shebang)[2:].split()
		exe=shebang.pop(0)
		if exe.endswith('/env'): exe=mywhich(shebang.pop(0))
		file_is_sh=exe.endswith('sh') and exe.endswith('csh')==SHELL.endswith('csh')
		if file_is_sh: shell=exe #We can directly execute file using exe.
	if not file_is_sh and re.match('\..?sh$',file): #extension is sh
		file_is_sh=file.endswith('.csh')==SHELL.endswith('csh') #file seems to be sh. We can directly execute file using SHELL.
	if not n_specified: loader='-N %s'%os.path.basename(file)
	loader+="-S %s"%shell
	if file_is_sh:
		os.system("qsub -cwd %s %s %s"%(joinargv(argv[:i]),loader,joinargv(argv[i:])))
	else:
		#file is not sh, so we need to wrap it with pseudo shell script.
		proc = subprocess.Popen(['qsub','-cwd',joinargv(argv[:i]),loader],stdin=subprocess.PIPE)
		proc.communicate(joinargv(argv[i:])+"\n")
		proc.stdin.close()

if __name__=='__main__':
	import sys
	if len(sys.argv)<2:
		sys.stderr.write("Usage: qinstall [qsub_options...] exe [args...]\n")
		sys.stderr.write("useful options:\n")
		sys.stderr.write("-l complex -q queue\n")
		sys.stderr.write("-l s_vmem=NG -l mem_req=N (NGB memory will be used)\n")
		sys.stderr.write("-i stdin -o stdout -e stderr\n")
		sys.stderr.write("note: in args, <>| must be QUOTED.\n")

		sys.exit(1)
	qinstall(sys.argv[1:])

