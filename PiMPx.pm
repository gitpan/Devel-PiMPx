#!/usr/bin/perl
package Devel::PiMPx;

use 5.006;
use strict;
use vars qw($VERSION $me %vars %cmds);
$VERSION = '0.7.0';

# ### 
# the valid pre-processor commands.
# unless ifdef, ifndef and undef which are done when parsing.
%cmds = (
    "include"   => "_include",
    "require"   => "_include",
    "define"    => "_define",
    "print"     => "_print",
    "inc"       => "_inc",
    "dec"       => "_dec",
    "exit"      => "_exit",
    "die"       => "_die",
    "addinc"    => "_addinc",
);

%vars = ();

sub new
{
	my($pkg, %argv) = @_;
	$pkg = ref $pkg || $pkg;
	my $self = {};
	bless $self, $pkg;
	
	$self->debug( delete $argv{debug} );
	$self->no_lineno( delete $argv{no_lineno} );
	$me = delete $argv{programname} || 'pimpx';
	$self;
}

sub debug
{
	my($self, $debug) = @_;
	if(defined $debug) {
		$self->{__DEBUG} = $debug
			if($debug || $debug == 0);
	}
	return $self->{__DEBUG};
}

sub no_lineno
{
	my($self, $no_lineno) = @_;
	if(defined $no_lineno) {
		$self->{__NO_LINENO} = $no_lineno
			if($no_lineno || $no_lineno == 0);
	}
	return $self->{__NO_LINENO};
}	

sub parse
{
	$_[0]->preprocess(@_);
}

# ### int preprocess(char file, bool include)
# preprocess given file. if include is true, sheebang will be removed
# from the file.
#
sub preprocess
{
	my ($self, $file, $bool_include) = @_;
	# ###
	# get the lines from the file.
	# must have own function for this, because when going
	# recursive we will override the filehandle.
	#
	my $lines = $self->_get_lines($file);

	my $lineno		= 0;	# current line number.
	my $iflevel		= 0; 	# current if block number.
	my $iftype		= 0;	# current if type (IFDEF or IFNDEF)
	my $onewastrue	= 0;	# first #if sentence status
	my $backquote	= 0;	# last/current character was/is a backquote
	my @ifdata		= (); 	# each block number has it's own element.
							# if the element is true the lines will be printed
							# and the preproc commands executed.

	sub IFDEF  { 1 };	# ### is in a ifdef clause
	sub IFNDEF { 2 };	# ### is in a ifndef clause

	defined $bool_include or $bool_include = 0;

	foreach(@$lines)
	{
		$lineno++; chomp;

		# ### remove sheebang if this is an included file.
		if($bool_include == 1 && $lineno == 1) {
			next if (substr($_, 0, 2) eq '#!');
		};
	
		# ### join lines when a backquote is found.
		if($backquote) {
			chomp(my $p = $lines->[$lineno - 1]); # previous line
			$p = substr($p, 0, length($p)-1);
			$_ = $lines->[$lineno] = $p . $_;
			$backquote = 0; 
			++$lineno;
		}
		my $line = $_;
		my $llen = length $line;
		# ### if this is a preprocessor command...
		if((index($line, '#%') != -1) && /^\s*\#\%\s*(.+?)(\s+|$)/)
		{
			if(substr($line, $llen-1, $llen) eq "\\")
			{
				# join two lines.
				$lineno++, $backquote++, next;
			}
			my ($cmd, $args);
			# ... remove the preproc prefix. (#%)...
			$line =~ s/^\s*\#\%\s*//;
			# ... and expand the variables.
			$line = $self->_getvars($line);
			# ... remove trailing whitespace
			$line = trim_end($line);
			
			# ### check if we have any arguments.
			if($line =~ /^(.+?)\s+(.+)$/) {
				($cmd, $args) = ($1, $2);
			} else {
				($cmd, $args) = ($line, undef);
				$cmd = trim_end($cmd);
			};
			if($cmd eq 'ifdef') {
				$iflevel++; # increment iflevel...
				print STDERR "--- IFLEVEL NOW UP TO $iflevel\n" if $self->debug;
				$iftype = IFDEF;
				# ...and set iflevel dataelement to true if the condition is true.
				$ifdata[$iflevel] = 1 if $self->_isdef($args);
				$onewastrue++ if $ifdata[$iflevel];
			}
			elsif($cmd eq 'ifndef') {
				$iflevel++;
				print STDERR "--- IFLEVEL NOW UP TO $iflevel\n" if $self->debug;
				$iftype = IFNDEF;
				$ifdata[$iflevel] = 1 unless $self->_isdef($args);
				$onewastrue++ if $ifdata[$iflevel];
			}
			elsif($cmd eq 'endif') {
				# ### end the if block.
				$ifdata[$iflevel] = 0;
				$onewastrue = 0;
				$iflevel--;
				print STDERR "--- IFLEVEL NOW DOWN TO $iflevel\n" if $self->debug;
				printf("#line %d\n", $lineno+1) if !$self->no_lineno() && !$bool_include;
				
			}
			elsif($cmd eq 'elif') {
				# ### new test in the same block
				# but do not execute this block if the last was true.
				if(	$ifdata[$iflevel] == 1) {
					$ifdata[$iflevel] = 0;
				}
				elsif(	$iftype == IFDEF) {
					if($self->_isdef($args)) {
						$ifdata[$iflevel] = 1; 
					}
					else {
						$ifdata[$iflevel] = 0;
					}
				}
				elsif(	$iftype == IFNDEF) {
					unless($self->_isdef($args)) {
						$ifdata[$iflevel] = 1;
					}
					else {
						$ifdata[$iflevel] = 0;
					}
				}
				else {
					die "$me: Error: $file: $lineno: Unbalanced if's\n";
				}
				$onewastrue++ if $ifdata[$iflevel];
			}
			elsif($cmd eq 'else') {
				# ### 
				# only execute if one of the conditions
				# in the if block was true.
				if($onewastrue) {
					$ifdata[$iflevel] = 0;
				}
				else {
					$ifdata[$iflevel] = 1 ;
				}
			}
			else {
				if($iflevel) {
					# ###
					# don't print the lines if the current condition
					# is false.
					next unless $ifdata[$iflevel];
				}
				# give warning if illegal preproc command.
				unless($cmds{$cmd}) {
		  		  warn "$me:Warning:$file: $lineno: Illegal preprocessor statement '$cmd'\n";
				  next;
				}
				# ### run the function referenced in the %cmds hash.
				my $cmd = $cmds{$cmd};
				if($self->can($cmd)) {
					$self->$cmd($args, $lineno, $file);
				}
				printf("#line %d\n", $lineno+1) if !$self->no_lineno() && !$iflevel && !$bool_include;
			}
		}
		else {
			if($iflevel) {
				# ###
				# don't print the lines if the current condition
				# is false.
				next unless $ifdata[$iflevel];
			}
			print $_, "\n";
		}
	}
	# ### check if we got all the if blocks right.
	die "$me:Error:$file: $lineno: Expecting #\%endif\n"
		if $iflevel > 0;
	die "$me:Error:$file: $lineno: Too many 'if' levels at end of file\n"
		if $iflevel < 0;
	
	return 1;
}

# ### array _get_lines(char file)
# slurp the contents of a file and return as an array,
# where each element is one line.
#
sub _get_lines {
	my($self, $file) = @_;
	open(FH, $file) or die "Couldn't open $file for reading: $_\n";
	my @lines = <FH>;
	close(FH);
	return \@lines;
}

# ### void _exit(void);
# quits the program.
#
sub _exit {
	exit;
}

# ### void _die(char msg)
# print an error message and die.
# 
sub _die {
	my($self, $msg) = @_;
	die $msg, "\n";
}

# ### int _print(char text, int lineno, char current_file)
# print a line to stdout.
#
sub _print {
	my($self, $arg, $lineno, $curfile) = @_;
	print $arg, "\n" if $arg;
	return 1;
}

# ### int _addinc(char path, int lineno, char current_file)
# add new path to @INC
#
sub _addinc {
	my($self, $arg, $lineno, $curfile) = @_;
	push @INC, $arg;
	return 1;
}

# ### int _define(char argument, int lineno, char current_file)
# define a PiMPx variable
#
sub _define {
	my($self, $arg, $lineno, $curfile) = @_;
	my ($var, $value) = split(/\s+/, $arg, 2);
	die "$me:Error:$curfile:$lineno: Missing variable name to define\n"
		unless $var;
	$var = 1 unless $value or $value == 0;
	eval " \$vars{\"$var\"} = $value";
	print STDERR "*** $var set to $vars{$var}\n" if $self->debug;
	return 1;
}

# ### int _inc(char varname, int lineno, char current_file)
# increment an integer variable
#
sub _inc {
	my($self, $arg, $lineno, $curfile) = @_;
	die "$me:Error:$curfile:$lineno: $arg not defined\n"
		unless $vars{$arg} or $vars{$arg} == 0;
	die "$me:Error:$curfile:$lineno: Variable must be integer near $arg.\n"
		unless $vars{$arg} =~ /^[\d0]+$/;
	$vars{$arg}++;
	return 1;
}

# ### int _dec(char varname, int lineno, char current_file)
# decrement an integer variable
#
sub _dec {

	my($self, $arg, $lineno, $curfile) = @_;
	die "$me:Error:$curfile:$lineno: $arg not defined\n"
		unless $vars{$arg};
	die "$me:Error:$curfile:$lineno: Variable must be integer near $arg.\n"
		unless $vars{$arg} =~ /^\d+$/;
	$vars{$arg}--;
	return 1;
}

# ### int _isdef(char varname, int lineno, char current_file)
# return true if variable varname is defined.
#
sub _isdef {
	my($self, $arg, $lineno, $curfile) = @_;
	if($vars{$arg}) {
		return 1;
	};
}

# ### int _include(char argument, int lineno, char current_file)
# preprocess another file and print it after the current line.
# if the argument is "path/filename" the path is fixed,
# but if the argument is <path/filename> we search for the path
# in @INC and return the first found with _whereis().
#
sub _include {
	my ($self, $file, $lineno, $curfile) = @_;
	if($file =~ /"(.+?)"/) {
		# ### we got a fixed path
		if(-f $1) {
			my $c_file = $1;
			$self->preprocess($c_file, 1);
		}
		else {
			die("$me:Error:$curfile:$lineno: No such file near $file\n");
		}
	}
	elsif($file =~ /\<(.+?)\>/) {
		# ### look for the file in @INC
		my $c_file = $self->_whereis($1);
		if($c_file) {
			$self->preprocess($c_file, 1);
		}
		else {
			die("$me:Error:$curfile:$lineno: No such file near $file\n");
		}
	}
	else {
		die("$me:Error:$curfile:$lineno: Syntax error near $file\n");
	}
	return 1;
}

# ### char _whereis(char file)
# look for a file in @INC and return the full path of the file.
#
sub _whereis {
	my($self, $file) = @_;
	foreach(@INC) {
		my $f = sprintf("%s/%s", $_, $file);
		return $f if -f $f;
	}
	return 0;
}

# ### char _getvars(char text)
# extract variables from text and return the same text
# with variable names changed to variable values.
#
sub _getvars {
	my($self, $text) = @_;
	chomp $text;

	my $count = 0;		# current character number.
	my $quote = 0;		# true if we're in a backquote (\)
	my $in_var = 0;		# true if we're in a variable area
	my $varbuf = undef;	# the current variable name buffer
	my $curtext = undef;	# text so far since last variable name	

	my $strlength = length($text);	# total characters in string.
	# ### iterate through each character in string.
	foreach my $chr (split //, $text) {
		# ### if we're in a variable area...
		if($in_var) {
			# ### ...and if this is a ending character
			if($chr eq '%' || $chr eq ' ' || $chr eq '}' || $count >= $strlength - 1) {
				# ### ...convert the variable name to variable value.

				# }'s are part of the var name if the var is printed as %{var}
				$varbuf .= $chr 
				  if $chr eq '}'
				    or $count >= $strlength - 1;

				my $varname = $varbuf;
				if(defined $varname) {	
					# remove varname special chars
					$varname =~ s/[}{%]//g;
			
					# debugging info
					print STDERR "curtext: '$curtext' varbuf: '$varbuf' var: '$vars{$varname}'\n" 
						if $self->debug;

					# escape special characters so we don't break the regexp
					$curtext 	= quotemeta $curtext 	if $curtext;
					$varbuf  	= quotemeta $varbuf  	if $varbuf;
					$varname 	= quotemeta $varname	if $varname;
					$vars{$varname} = quotemeta $vars{$varname} if $vars{$varname};

					# define the vars if they're not defined.
					defined $curtext or $curtext = undef;
					defined $varbuf or $varbuf = undef;
					defined $vars{$varname} or $vars{$varname} = undef;	

					# substitue variable name with variable value.
					my $w=1 if $^W; $^W=0; # turn off warnings
					$text =~ s/($curtext)$varbuf/$1$vars{$varname}/;
					$w && $^W++; # turn warning on again if they were set.
				};
	
				# not in variable anymore.
				$in_var = 0;
				$curtext = undef;
			}
			else {	
				# ### ...else add current char to variable name.
				$varbuf .= $chr;
				$in_var++;
			}
		}
		else {
			# ### if the last character was a backquote
			if($quote) {
				# ### must be possible to write \ with \\ :-)
				if($chr eq '\\') {
					$curtext .= "\\\\";
				}
				else {
					$curtext .= $chr;
				}
				$quote = 0;
			}
			elsif($chr eq "\\") {
				# we're in a backquote.
				$curtext .= "\\\\";
				$quote = 1;
			}
			elsif($chr eq '%') {
				# we're in a variable name
				$in_var = 1;
				$varbuf = $chr;
			}
			else {
				$curtext .= $chr;
			}
		}
		$count++;
	}
	# \'s must be removed, but \\'s must be converted to one \ :-)
	$text =~ s/\\\\/\@\@###BACKQUOTE###\@\@/g;
	$text =~ s/\\//g;
	$text =~ s/\@\@###BACKQUOTE###\@\@/\\/g;
	return $text;
}

sub trim_end
{
	my($string) = (@_);
	my $strlen = length($string);
	if(substr($string, $strlen-1, $strlen) eq ' ') {
		s/\s*$//;
	}
	$string;
}

1;
__END__

=head1 NAME

Devel::PiMPx - The Perl-inclusive Macro Processor

=head1 SYNOPSIS

  use Devel::PiMPx;
  my $pp = new Devel::PiMPx(
    programname => $0,
    debug = 1,
    no_lineno => 0
  );

  $pp->debug(0);
  $pp->preprocess($filename);

=head1 DESCRIPTION

PiMPx is the Perl-inclusive Macro Processor.
It simplifies the management of bigger projects in Perl and can
be used in other languages that use lines beginning with "#" as comments.

=head1 EXPORT

None by default.

=head1 AUTHOR

Ask Solem Hoel E<lt>ask@unixmonks.netE<gt>

=head1 SEE ALSO
 
L<perl>. L<pimpx>

=cut
