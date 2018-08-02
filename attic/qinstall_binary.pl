#!/usr/bin/env perl
#QInstall: Sun/Univa Grid Engine qsub Helper
#(C) T. Yamada under 2-clause BSDL.

use strict;
use warnings;
use File::Basename;

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

sub hash_to_string{
	my @ret=();
	my %hash=@_;
	foreach my $key(keys %hash){push(@ret,$key."=".$hash{$key});}
	return join(",",@ret);
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
		if($argv[$i] eq "-pe"){
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
	if(substr($line,0,2) eq "#!"){
		$line=mychomp($line);
		my @exe=split(" ",substr($line,2));
		my $exe=shift(@exe);
		if($exe=~/\/env$/){$exe=mywhich(shift(@exe));}
		$loader="-N \"".basename($file)."\" " if(!$n_specified);
		$loader.="-b y \"".$exe."\" ".join(" ",@exe);
	}else{
		$loader="-b y";
	}
	my $arg = 
		"qsub -cwd ".#-v ".
		#"\"".hash_to_string(%ENV)."\" ".
		joinargv(@option).
		" ".$loader." ".
		joinargv(@argv);

	#print $arg."\n";
	system($arg);
}

if(__FILE__ eq $0){
	$ARGV[0] || die "qinstall args";
	qinstall(@ARGV);
}
1;
