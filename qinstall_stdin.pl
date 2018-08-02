#!/usr/bin/env perl
#QInstall: Sun/Univa Grid Engine qsub Helper
#(C) T. Yamada under 2-clause BSDL.

use strict;
use warnings;
use File::Basename;

# also determine which to use bashrc or cshrc
my $_shell="/bin/bash";

sub mywhich{
	my $name=shift;
	if(-f $name){return $name;} #relative/absolute
	my @PATH=split(/:/,$ENV{"PATH"});
	foreach(@PATH){
		my $x;
		if(-f ($x=$_."/".$name)){
			return $x;
		}
	}
	return undef;
}

sub mychomp{
	my $str=shift;
	$str =~ s/\n$//;
	$str =~ s/\r$//;
	return $str;
}

sub joinargv{
	if(!scalar(@_)){return "";}
	return join(' ',map {my $arg=$_; (grep {$_ eq $arg} qw(< > |)) ? $arg : "'".$arg."'"} @_);
}

sub qinstall{
	my @argv=@_;
	my $i=0;
	my $n_specified=0;
	for(;$i<scalar(@argv);){
		if(substr($argv[$i],0,1) ne "-"){last;}
		if($ARGV[$i] eq "-pe"){
			$i+=3;
		}else{
			$n_specified=1 if($argv[$i] eq "-N");
			$i+=2;
		}
	}
	my @option=splice(@argv,0,$i);
	$argv[0]=mywhich($argv[0]);
	$argv[0] || die "file not found";
	my $file=$argv[0];
	-x $file || die $file." not executable";
	open(my $fh,"<",$file) || die "cannot open file ".$file;
	my $line=<$fh>;
	close($fh);
	my $loader="";
	my $file_is_sh=0;
	my $shell=$_shell;
	if(substr($line,0,2) eq "#!"){
		$line=mychomp($line);
		my @exe=split(" ",substr($line,2));
		my $exe=shift(@exe);
		if($exe=~/\/env$/){$exe=mywhich(shift(@exe));}
		$file_is_sh = $exe=~/sh$/&&!($exe=~/csh$/)==!($_shell=~/csh$/);
		$shell=$exe if $file_is_sh;
	}
	if(!$file_is_sh&&$file=~/\..?sh$/){
		$file_is_sh = !($file=~/\.csh$/)==!($_shell=~/csh$/);
	}
	$loader="-N \"".basename($file)."\" " if(!$n_specified);
	$loader.="-S ".$shell;
	if($file_is_sh){
		system("qsub -cwd ".joinargv(@option)." ".$loader." ".joinargv(@argv));
	}else{
		open(my $io,"| qsub -cwd ".joinargv(@option)." ".$loader);
		print $io joinargv(@argv)."\n";
		close($io);
	}
}

if(__FILE__ eq $0){
	$ARGV[0] || die "qinstall args";
	qinstall(@ARGV);
}
1;
