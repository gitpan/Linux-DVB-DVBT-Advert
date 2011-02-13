package Makeutils ;

=head1 NAME

Makeutils - MakeMaker utilities 

=head1 SYNOPSIS

	use Makeutils ;
  

=head1 DESCRIPTION

Module provides a set of useful utility routines for creating Maefiles and config.h files. 


=cut


#============================================================================================
# USES
#============================================================================================
use strict ;
use ExtUtils::MakeMaker ;
use Env ;
use Config;
use Cwd 'cwd';
use File::Basename ;
use File::Path ;


#============================================================================================
# EXPORTER
#============================================================================================
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw/
	init
	add_install_progs
	add_defines
	get_makeopts
	add_objects
	add_clibs
	c_try
	c_try_keywords
	c_inline
	have_builtin_expect
	have_lrintf
	c_always_inline
	c_restrict
	c_has_header
	c_has_function
	c_struct_timeval
	check_new_version
	have_h
	have_d
	havent_d
	have_h
	have_func
	arch_name
	get_config
/ ;


#============================================================================================
# GLOBALS
#============================================================================================
our $VERSION = '0.03' ;
our $DEBUG = 0 ;

our %ModuleInfo ;

#============================================================================================

#============================================================================================

##-------------------------------------------------------------------------------------------
sub init 
{
	my ($modname) = @_ ;
	
	my $name = $modname ;
	unless ($name)
	{
	    $name = basename(cwd());
	    $name =~ s|[\-_][\d\.\-]+\z||; 
	}
	
	# eg Linux::DVB::DVBT::TS
	my $mod = $name ;
	$mod =~ s%\-%::%g ;
	
	# eg Linux/DVB/DVBT/TS
	my $modpath = $name ;
	$modpath =~ s%\-%/%g ;
	
	# eg TS
	my $root = $name ;
	$root =~ s%.*\-([^-]+)$%$1% ;

	my $version = ExtUtils::MM->parse_version("lib/$modpath.pm");
	
	%ModuleInfo = (
		# eg Linux-DVB-DVBT-TS
		'name'		=> $name,
		
		# eg Linux::DVB::DVBT::TS
		'mod'		=> $mod,
		
		# eg Linux/DVB/DVBT/TS
		'modpath'	=> $modpath,
		
		# eg TS
		'root'		=> $root,
		
		'version'	=> $version,
		
		'programs'	=> [],
		
		'mod_defines'	=> "",
		'make_defines'	=> "",
		
		# included c-libraries
		'clibs'			=> {},
		'includes'		=> "",
		
		# String "list" of objects
		'objects'		=> "$root.o ",
		
		# additional objects
		'obj_list' 		=> [],
		
		'config'		=> {},
		
	) ;
	
	return \%ModuleInfo ;
}

##-------------------------------------------------------------------------------------------
sub add_install_progs
{
	my ($basedir, $progs_aref) = @_ ;

	if ( (ref($progs_aref) eq 'ARRAY') && @$progs_aref)
	{	
		if ( 
			grep $_ eq '-n', @main::ARGV
			or grep /^LIB=/, @main::ARGV and not grep /^INSTALLSCRIPT=/, @main::ARGV 
		) 
		{
			@main::ARGV = grep $_ ne '-n', @main::ARGV;
			warn "Skipping installation of scripts...\n";
			
			while (@$progs_aref) 
			{
				pop @$progs_aref ;	
			}
		} 
		else 
		{
			warn <<EOW;

This Perl module comes with several scripts which I would try to install in
directory $Config{installscript}.

To skip install, rerun with option -n given to Makefile.PL.

EOW
		}
	}
	
	$progs_aref ||= [] ;
	$ModuleInfo{'programs'} = [ map "$basedir/$_", @$progs_aref ] ;
	
	return @$progs_aref ;
}

##-------------------------------------------------------------------------------------------
sub add_defines
{
	my ($defines_href) = @_ ;

	if ( (ref($defines_href) eq 'HASH') && keys %$defines_href)
	{	
		foreach my $key (keys %$defines_href)
		{
			if (defined($defines_href->{$key}) && length($defines_href->{$key}))
			{
				$ModuleInfo{'mod_defines'} .= "-D$key=$defines_href->{$key} " ;
				$ModuleInfo{'make_defines'} .= "$key=$defines_href->{$key} " ;
			}
			else
			{
				$ModuleInfo{'mod_defines'} .= "-D$key " ;
				$ModuleInfo{'make_defines'} .= "$key=1 " ;
			}
		}
	}
}

##-------------------------------------------------------------------------------------------
sub get_makeopts
{
	## -D = debug 
	my $DEBUG = 0 ;
	if ( 
		grep $_ eq '-D', @main::ARGV
	) 
	{
		$DEBUG = 1 ;
	} 
	
	## -d = debug 
	if ( 
		grep $_ eq '-d', @main::ARGV
	) 
	{
		@main::ARGV = grep $_ ne '-d', @main::ARGV;
		warn "Buidling version with extra debugging enabled...\n";
		add_defines({
			'DEBUG'		=> 1,
		}) ;
	} 
	
}


##-------------------------------------------------------------------------------------------
sub add_objects
{
	my ($basedir, $objs_aref) = @_ ;

	foreach my $obj (@$objs_aref)
	{
		push @{$ModuleInfo{'obj_list'}}, "$basedir/$obj" ;
	}

	## Recreate list of all objects
	_create_objects_list() ;

	## Create list of includes
	_create_includes_list() ;
}
	
##-------------------------------------------------------------------------------------------
#		'dvb_lib'		=> {'mkf' => 'Subdir-min.mk'},
#		'dvb_ts_lib'	=> 1,
#		'libmpeg2'		=> { 
#			'config'		=> {
#				'file'			=> 'include/config.h',
#				'func'			=> \&create_libmpeg2_config_h,
#			},
#		},
#		'mpeg2audio'	=> {
#			'config'		=> {
#				'file'			=> 'config.h',
#				'func'			=> \&create_mpeg2audio_config_h,
#			},
#		},
#
sub add_clibs
{
	my ($basedir, $clibs_href) = @_ ;

	## Include makefiles & get objects
	print "Including makefiles from sub libraries:\n" ;
	foreach my $lib (keys %$clibs_href)
	{
		my $libdir = "$basedir/$lib/" ;
		
		$ModuleInfo{'clibs'}{$lib} = {
			'file'		=> "",
			'objects'	=> [],
			'includes'	=> [ $libdir ],
		} ;
		
		print " * $lib ... " ;
		my $mkf = "$libdir/" ;
		my $specified_mkf = 0 ;
		if ( (ref($clibs_href->{$lib}) eq 'HASH') && (exists($clibs_href->{$lib}{'mkf'})) )
		{
			++$specified_mkf ;
			$mkf .= $clibs_href->{$lib}{'mkf'} ;
		}
		else
		{
			$mkf .= 'Subdir.mk' ;
		}
		
		## read file
		if (-f $mkf)
		{
			open my $fh, "<$mkf" ;
			if ($fh)
			{
				$ModuleInfo{'clibs'}{$lib}{'file'} = do { local $/; <$fh> } ;
				close $fh ;	
				print "ok" ;
			}
			else
			{
				print "Unable to read $mkf : $!\n" ;
				exit(1) if $specified_mkf ;
			}
		}
		else
		{
			print "$mkf not found\n" ;
			exit(1) if $specified_mkf ;
		}
		print "\n" ;
		
		## Process file
		my @lines = split /\n/, $ModuleInfo{'clibs'}{$lib}{'file'} ;
		foreach my $line (@lines)
		{
			chomp $line ;
			$line =~ s/#.*// ;
			$line =~ s/^\s+// ;
			$line =~ s/\s+$// ;
			next unless $line ;
			
			# look for something like:
			#	OBJS-libdvb_ts_lib := \
			#		$(libdvb_ts_lib)/ts_parse.o \
			#		$(libdvb_ts_lib)/ts_skip.o \
			#		$(libdvb_ts_lib)/ts_split.o \
			#		$(libdvb_ts_lib)/ts_cut.o
			#
			# Get just the *.o
			#
			if ($line =~ m/(\S+\.o)/)
			{
				my $obj = $1 ;
				
				# replace $(...) with the dir
				$obj =~ s%\$\([^)]+\)%$basedir/$lib% ;
				push @{$ModuleInfo{'clibs'}{$lib}{'objects'}}, $obj ;
			}
		}
		
		## check for any include subdirs
		for my $incdir (qw/include inc h/)
		{
			if (-d "$libdir$incdir")
			{
				push @{$ModuleInfo{'clibs'}{$lib}{'includes'}}, "$libdir$incdir" ;
			}
		}
	}
	
	## Create config files
	foreach my $lib (keys %$clibs_href)
	{
		if ( (ref($clibs_href->{$lib}) eq 'HASH') && (exists($clibs_href->{$lib}{'config'})) )
		{
			if ( (ref($clibs_href->{$lib}{'config'}{'func'}) eq 'CODE') && (exists($clibs_href->{$lib}{'config'}{'file'})) )
			{
				my $func = $clibs_href->{$lib}{'config'}{'func'} ;
				my $config_h = "$basedir/$lib/$clibs_href->{$lib}{'config'}{'file'}" ;

				print "creating config file... " ;
				&$func($config_h, %{$ModuleInfo{'config'}}) ;
				print "ok\n" ;
			}
		}
	}

	## Recreate list of all objects
	_create_objects_list() ;
	
	## Create list of includes
	_create_includes_list() ;
}
	

##-------------------------------------------------------------------------------------------
sub _create_objects_list
{
	## root
	$ModuleInfo{'objects'} = "$ModuleInfo{'root'}.o " ;
	
	## include makefiles
	foreach my $lib (sort keys %{$ModuleInfo{'clibs'}})
	{
		$ModuleInfo{'objects'} .= join(' ', @{$ModuleInfo{'clibs'}{$lib}{'objects'}}) . " " ;
	}
	
	## additional objects
	$ModuleInfo{'objects'} .= join(' ', @{$ModuleInfo{'obj_list'}}) . " " ;
}

##-------------------------------------------------------------------------------------------
sub _create_includes_list
{
	## include makefiles
	$ModuleInfo{'includes'} = "" ;
	foreach my $lib (sort keys %{$ModuleInfo{'clibs'}})
	{
		foreach my $inc ( @{$ModuleInfo{'clibs'}{$lib}{'includes'}} )
		{
			$ModuleInfo{'includes'} .= "-I$inc " ;
		}
	}
	
}

##-------------------------------------------------------------------------------------------
sub c_try
{
	my ($msg, $code, $ok_val, $cflags) = @_ ;
	
if ($DEBUG && $msg)
{
print "\n-------------------------\n" ;
}		

	print "$msg... " if $msg ;

	$cflags ||= "" ;
	my $ok = "" ;
	my $conftest = "conftest.c" ;
	my $conferr = "conftest.err" ;
	my $confobj = "conftest.o" ;
	
	open my $fh, ">$conftest" or die "Error: unable to create test file $conftest : $!";
	print $fh $code ;
	close $fh ;
	
	unlink $confobj ;
	
	my $rc = system("$Config{'cc'} -c $conftest $cflags -o $confobj 2> $conferr") ;
	my $errstr ;
	open my $fh, "<$conferr" ;
	if ($fh)
	{
		$errstr = do { local $/; <$fh> } ;
		close $fh ;	
		$errstr =~ s/^\s+.//gm ;
	}

if ($DEBUG)
{
print "\n- - - - - - - - - - - - -\n" ;
print "- RC: $rc\n" ;
print "- - - - - - - - - - - - -\n" ;
print "- Code:\n" ;
print "- - - - - - - - - - - - -\n" ;
print "$code\n" ;
print "- - - - - - - - - - - - -\n" ;
print "- Compile errors:\n" ;
print "- - - - - - - - - - - - -\n" ;
print "$errstr" ;
}		

	# check for errors
	if ( ($rc==0) && (!$errstr) && (-s $confobj) )
	{
		# stop here because this worked
		$ok = $ok_val ;
	}
	
	unlink $conftest ;
	unlink $conferr ;
	unlink $confobj ;

	if ($msg)
	{
		if ($DEBUG)
		{
			print "- - - - - - - - - - - - -\n" ;
			print "- Return: " ;
		}
		print $ok ? "$ok\n" : "no\n" ;		
	}

if ($DEBUG && $msg)
{
print "-------------------------\n\n" ;
}		


	return $ok ;
}

##-------------------------------------------------------------------------------------------
sub c_try_keywords
{
	my ($msg, $code, $keywords_aref, $cflags) = @_ ;
	

if ($DEBUG)
{
print "\n-------------------------\n" ;
}		

	print "$msg... " if $msg ;
	
	my $ok = "" ;
	
	foreach my $ac_kw (@$keywords_aref)
	{
		if ($DEBUG)
		{
			print "\n- - - - - - - - - - - - -\n" ;
			print "- Keyword: $ac_kw" ;
		}

		my $code_str = $code ;
		$code_str =~ s/\$ac_kw/$ac_kw/g ;
		$ok = c_try("", $code_str, $ac_kw, $cflags) ;
		
		if ($ok)
		{
			last ;
		}
	}

	if ($msg)
	{
		if ($DEBUG)
		{
			print "- - - - - - - - - - - - -\n" ;
			print "- Return: " ;
		}
		print $ok ? "$ok\n" : "no\n" ;		
	}

if ($DEBUG)
{
print "-------------------------\n\n" ;
}		

	return $ok ;
}


##-------------------------------------------------------------------------------------------
sub c_inline
{
	my $code = <<'_ACEOF' ;
#ifndef __cplusplus
typedef int foo_t;
static $ac_kw foo_t static_foo () {return 0; }
$ac_kw foo_t foo () {return 0; }
#endif

_ACEOF
	
	my $ac_c_inline = c_try_keywords('checking for inline', $code, [qw/inline __inline__ __inline/]) ;
	return $ac_c_inline ;
}


##-------------------------------------------------------------------------------------------
sub have_builtin_expect
{
	my $code = <<_ACEOF ;
int foo (int a)
{
    a = __builtin_expect (a, 10);
    return a == 10 ? 0 : 1;
}
_ACEOF
	
	my $ok = c_try('checking for builtin expect', $code, 1) ;
	
	return $ok ? "#define HAVE_BUILTIN_EXPECT 1" : "" ;
}

##-------------------------------------------------------------------------------------------
sub have_lrintf
{
	my $code = <<_ACEOF ;
#include <math.h>
int foo (double a)
{
long int b ;

    b = lrintf(a);
    return b == 10 ? 0 : 1;
}
_ACEOF
	
	my $ok = c_try('checking for lrintf', $code, 1) ;
	
	return $ok ? "#define HAVE_LRINTF 1" : "" ;
}

##-------------------------------------------------------------------------------------------
sub c_always_inline
{
	my ($ac_c_inline) = @_ ;
	
	my $ac_c_always_inline = "" ;
	
	if ( ($Config{'cc'} =~ /gcc$/) && ($ac_c_inline eq 'inline') )
	{
		my $code = <<_ACEOF ;

#ifndef __cplusplus
#define inline $ac_c_inline
#endif

int
main ()
{
__attribute__ ((__always_inline__)) void f (void);
            #ifdef __cplusplus
            42 = 42;    // obviously illegal - we want c++ to fail here
            #endif
  ;
  return 0;
}
_ACEOF

		$ac_c_always_inline = c_try('checking for always_inline', $code, '__attribute__ ((__always_inline__))') ;
	}
	
	return $ac_c_always_inline ;
}

##-------------------------------------------------------------------------------------------
sub c_restrict
{
	
	## protect $ac_kw for expansion in c_try_keywords()
	my $code = <<'_ACEOF' ;
int
main ()
{
char * $ac_kw p;
  ;
  return 0;
}

_ACEOF
	
	my $ac_c_restrict = c_try_keywords('checking for restrict', $code, [qw/restrict __restrict__ __restrict/]) ;
	return $ac_c_restrict ;
}

##-------------------------------------------------------------------------------------------
sub c_has_header
{
	my ($header) = @_ ;

	my $code = <<_ACEOF ;
#include <$header>

typedef int foo_t;
static foo_t static_foo () {return 0; }

int
main ()
{
  return static_foo() ;
}
_ACEOF
	
	my $ac_has_header = c_try("checking for $header", $code, $header, '-Wall -Werror') ;
	return $ac_has_header ;
}

##-------------------------------------------------------------------------------------------
sub c_has_function
{
	my ($ac_func) = @_ ;

	my $code = <<_ACEOF ;
/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
#define $ac_func innocuous_$ac_func

/* System header to define __stub macros and hopefully few prototypes,
    which can conflict with char $ac_func (); below.
    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
    <limits.h> exists even on freestanding compilers.  */

#ifdef __STDC__
# include <limits.h>
#else
# include <assert.h>
#endif

#undef $ac_func

/* Override any GCC internal prototype to avoid an error.
   Use char because int might match the return type of a GCC
   builtin and then its argument prototype would still apply.  */
#ifdef __cplusplus
extern "C"
#endif
char $ac_func ();
/* The GNU C library defines this for functions which it implements
    to always fail with ENOSYS.  Some functions are actually named
    something starting with __ and the normal name is an alias.  */
#if defined __stub_$ac_func || defined __stub___$ac_func
choke me
#endif

int
main ()
{
return $ac_func ();
  ;
  return 0;
}
_ACEOF
	
	my $ac_has_function = c_try("checking for $ac_func", $code, $ac_func, '-Wall -Werror', "1") ;
	return $ac_has_function ;
}


##-------------------------------------------------------------------------------------------
sub c_struct_timeval
{
	my $code = <<_ACEOF ;
#include <sys/time.h>
#include <time.h>

typedef struct timeval ac__type_new_;
int
main ()
{
if ((ac__type_new_ *) 0)
  return 0;
if (sizeof (ac__type_new_))
  return 0;
  ;
  return 0;
}
_ACEOF
	
	my $ac_struct_timeval = c_try("checking for struct timeval", $code, 1) ;
	return $ac_struct_timeval ;
}



##-------------------------------------------------------------------------------------------
sub check_new_version
{
#	my $version = ExtUtils::MM_Unix->parse_version("lib/$ModuleInfo{modpath}.pm");

	print "Installing Version: $ModuleInfo{version}\n" ;
	
	## Check for newer version
	eval {
		require LWP::UserAgent;
	} ;
	if (!$@)
	{
		print "Checking for later version...\n" ;
		
		## specify user name so that I can filter out my builds
		my $user = $ENV{USER} || $ENV{USERNAME} || 'nobody' ;

		# CPAN testers
		my $cpan = $ENV{'PERL5_CPAN_IS_RUNNING'}||0 ;
		
		## check for OS-specific versions
		my $os = $^O ;
		my $url = "http://quartz.homelinux.com/CPAN/index.php?ver=$ModuleInfo{version}&mod=$ModuleInfo{name}&user=$user&os=$os&cpan=$cpan" ;
		 
		my $ua = LWP::UserAgent->new;
		$ua->agent("CPAN-$ModuleInfo{name}/$ModuleInfo{version}") ;
		$ua->timeout(10);
		$ua->env_proxy;
		 
		my $response = $ua->get($url);
		if ($response->is_success) 
		{
			my $content = $response->content ;
			if ($content =~ m/Current version : ([\d\.]+)/m)
			{
				print "Latest CPAN version is $1\n" ;
			}
			if ($content =~ m/Newer version/m)
			{
				print "** NOTE: A newer version than this is available. Please downloaded latest version **\n" ;
			}
			else
			{
				print "Got latest version\n" ;
			}
		}
		else
		{
			print "Unable to connect, assuming latest\n" ;
			#print $response->status_line;
		}
	}
	
}

##-------------------------------------------------------------------------------------------
sub have_h
{
	my ($key, $header, $name, $val, $notval) = @_ ;
	
	$val = "1" unless defined($val) ;
	$notval = "" unless defined($notval) ;

	my $def ;
	if ($key && exists($Config{$key}))
	{
		$def = $Config{$key} ;	
	}
	
	if (!$def)
	{
		my $has = c_has_header($header) ;
		if ($has)
		{
			$def = 'define' ;
		}
	}
	if (!$def)
	{
		$def = 'undef' ;
	}
	
	my $str = "#$def $name " . ($def eq 'define' ? $val : $notval) ;
	return $str ;
}



##-------------------------------------------------------------------------------------------
sub have_d
{
	my ($key, $name, $val, $notval) = @_ ;
	
	$val = "1" unless defined($val) ;
	$notval = "" unless defined($notval) ;

	my $def = $Config{$key} || 'undef' ;
	my $str = "#$def $name " . ($def eq 'define' ? $val : $notval) ;
	return $str ;
}

##-------------------------------------------------------------------------------------------
# Define if not available - otherwise don't define
sub havent_d
{
	my ($key, $name, $val) = @_ ;
	
	$val = "" unless defined($val) ;

	my $str ;
	if ($Config{$key} eq 'define')
	{
		$str = "/* #define $name $val */"
	}
	else
	{
		$str = "#define $name $val"
	}
	return $str ;
}




##-------------------------------------------------------------------------------------------
sub have_h
{
	my ($key, $header, $name, $val, $notval) = @_ ;
	
	$val = "1" unless defined($val) ;
	$notval = "" unless defined($notval) ;

	my $def ;
#	if ($key && exists($Config{$key}))
#	{
#		$def = $Config{$key} ;	
#	}
	
	if (!$def)
	{
		my $has = c_has_header($header) ;
		if ($has)
		{
			$def = 'define' ;
		}
	}
	if (!$def)
	{
		$def = 'undef' ;
	}
	
	my $str = "#$def $name " . ($def eq 'define' ? $val : $notval) ;
	return $str ;
}

##-------------------------------------------------------------------------------------------
sub have_func
{
	my ($key, $func, $name, $val, $notval) = @_ ;
	
	$val = "1" unless defined($val) ;
	$notval = "" unless defined($notval) ;

	my $def ;
#	if ($key && exists($Config{$key}))
#	{
#		$def = $Config{$key} ;	
#	}
	
	if (!$def)
	{
		my $has = c_has_function($func) ;
		if ($has)
		{
			$def = 'define' ;
		}
	}
	if (!$def)
	{
		$def = 'undef' ;
	}
	
	my $str = "#$def $name " . ($def eq 'define' ? $val : $notval) ;
	return $str ;
}



##-------------------------------------------------------------------------------------------
sub arch_name
{
	my $arch = "ARCH_X86" ;

	my $arch_name = $Config{'archname'} ;
	
	if ($arch_name =~ /i.86\-.*|k.\-.*|x86_64\-.*|x86\-.*|amd64\-.*|x86/i)
	{
		$arch = "ARCH_X86" ;
	}
	elsif ($arch_name =~ /ppc\-.*|powerpc\-.*/i)
	{
		$arch = "ARCH_PPC" ;
		
		# altivec?
	}
	elsif ($arch_name =~ /sparc\-*|sparc64\-.*/i)
	{
		$arch = "ARCH_SPARC" ;
	}
	elsif ($arch_name =~ /alpha.*/i)
	{
		$arch = "ARCH_ALPHA" ;
	}
	elsif ($arch_name =~ /arm.*/i)
	{
		$arch = "ARCH_ARM" ;
	}

	return $arch ;
}

##-------------------------------------------------------------------------------------------
sub get_config
{
	my %current_config ;
	
	# Arch
	$current_config{'ARCH'} = arch_name() ;
	
	# Alignment
	$current_config{'ALIGN_BYTES'} = $Config{'alignbytes'} * 8 ;
	
	# Have ...
	$current_config{'HAVE_FTIME'} = have_func('d_ftime', 'ftime', 'HAVE_FTIME') ;
	$current_config{'HAVE_GETTIMEOFDAY'} = have_func('d_gettimeod', 'gettimeofday', 'HAVE_GETTIMEOFDAY') ;

	$current_config{'HAVE_INTTYPES_H'} = have_h('i_inttypes', 'inttypes.h', 'HAVE_INTTYPES_H') ;
	$current_config{'HAVE_IO_H'} = have_h('', 'io.h', 'HAVE_IO_H') ;
	$current_config{'HAVE_MEMORY_H'} = have_h('i_memory', 'memory.h', 'HAVE_MEMORY_H') ;
	$current_config{'HAVE_STDINT_H'} = have_h('', 'stdint.h', 'HAVE_STDINT_H') ;
	$current_config{'HAVE_STDLIB_H'} = have_h('i_stdlib', 'stdlib.h', 'HAVE_STDLIB_H') ;
	$current_config{'HAVE_STRINGS_H'} = have_h('', 'strings.h', 'HAVE_STRINGS_H') ; 
	$current_config{'HAVE_STRING_H'} = have_h('i_string', 'string.h', 'HAVE_STRING_H') ;
	$current_config{'HAVE_SYS_STAT_H'} = have_h('i_sysstat', 'sys/stat.h', 'HAVE_SYS_STAT_H') ;
	$current_config{'HAVE_SYS_TIMEB_H'} = have_h('', 'sys/timeb.h', 'HAVE_SYS_TIMEB_H') ; 
	$current_config{'HAVE_SYS_TIME_H'} = have_h('i_systime', 'sys/time.h', 'HAVE_SYS_TIME_H') ;
	$current_config{'HAVE_SYS_TYPES_H'} = have_h('i_systypes', 'sys/types.h', 'HAVE_SYS_TYPES_H') ;
	$current_config{'HAVE_TIME_H'} = have_h('i_time', 'time.h', 'HAVE_TIME_H') ;
	$current_config{'HAVE_UNISTD_H'} = have_h('i_unistd', 'unistd.h', 'HAVE_UNISTD_H') ;
	$current_config{'HAVE_GETOPT_H'} = have_h('', 'getopt.h', 'HAVE_GETOPT_H') ;
	
	
	# TODO: convert to live checks....
	$current_config{'USE_LARGEFILES'} = have_d('uselargefiles', '_LARGE_FILES') ;
	$current_config{'const'} = havent_d('d_const', 'const') ;
	$current_config{'size_t'} = $Config{'sizetype'} eq 'size_t' ? "" : "#define size_t unsigned int" ;
	$current_config{'volatile'} = havent_d('d_volatile', 'CONST') ;
	
	
	
	# Endian 
	my $ENDIAN = "
#undef WORDS_BIGENDIAN
#undef SHORT_BIGENDIAN
#undef WORDS_LITTLEENDIAN
#undef SHORT_LITTLEENDIAN
" ;
	if ($Config{'byteorder'} =~ /^1/)
	{
		# little
		if ($Config{'byteorder'} eq '12345678')
		{
			# words
			$ENDIAN = "
#undef WORDS_BIGENDIAN
#undef SHORT_BIGENDIAN
#define WORDS_LITTLEENDIAN	1
#undef SHORT_LITTLEENDIAN
" ;
		}
		else
		{
			$ENDIAN = "
#undef WORDS_BIGENDIAN
#undef SHORT_BIGENDIAN
#undef WORDS_LITTLEENDIAN
#define SHORT_LITTLEENDIAN	1
" ;
		}
	}
	else
	{
		# big
		if ($Config{'byteorder'} eq '87654321')
		{
			# words
			$ENDIAN = "
#define WORDS_BIGENDIAN	1
#undef SHORT_BIGENDIAN
#undef WORDS_LITTLEENDIAN
#undef SHORT_LITTLEENDIAN
" ;
		}
		else
		{
			$ENDIAN = "
#undef WORDS_BIGENDIAN
#define SHORT_BIGENDIAN	1
#undef WORDS_LITTLEENDIAN
#undef SHORT_LITTLEENDIAN
" ;
		}
	}
	$current_config{'ENDIAN'} = $ENDIAN ;
	
	# inline ?
	my $ac_c_inline = c_inline() ;
	my $ac_c_always_inline = c_always_inline($ac_c_inline) ;
	my $inline = $ac_c_always_inline || $ac_c_inline || "" ;
	if ($inline eq 'inline')
	{
		$current_config{'inline'} = "" ;
	}
	else
	{
		$current_config{'inline'} = "#define inline $inline" ;
	}
	
	# restrict ?
	$current_config{'restrict'} = c_restrict() ;
	

	# timeval
	my $ac_struct_timeval = c_struct_timeval() ;
	$current_config{'HAVE_STRUCT_TIMEVAL'} = $ac_struct_timeval ? "#define HAVE_STRUCT_TIMEVAL 1" : "#undef HAVE_STRUCT_TIMEVAL" ;
	
	# signal_t
	$current_config{'RETSIGTYPE'} = $Config{'signal_t'} ? "#define RETSIGTYPE $Config{'signal_t'}" : "#define RETSIGTYPE void" ;

	# Builtin...
	$current_config{'HAVE_BUILTIN_EXPECT'} = have_builtin_expect() ; 
	$current_config{'HAVE_LRINTF'} = have_lrintf() ;

	## save
	$ModuleInfo{'config'} = \%current_config ;

	return %current_config ;
}



# ============================================================================================
# END OF PACKAGE


1;

__END__

