#! /usr/bin/perl

# This script is called
#
# PROGRAM [ OPTIONS ] FILEPREFIX
#
# It creates the basic architecture required for producing lecture notes, handouts and slides.
# More precisely it creates the files
#
# FILEPREFIX.tex		Actual contents of the lecture
# FILEPREFIX_notes.tex		Driver file for lecture notes
# FILEPREFIX_beamer.tex		Driver file for presentation slides
# FILEPREFIX_andout.tex		Driver file for handouts
#
# As well as the FILEPREFIX/figures directory.
#
# Information about the module can be read from a parameter file (default: parameters.dat).

use strict;
use warnings;
use diagnostics;

use Getopt::Long::Descriptive;

use English;

use IO::File;
use File::Copy 'copy';
use File::Path 'make_path';

my $TEMPLATE_PREFIX = '.template';
my $DEFAULT_PARAMETER_FILE = '.parameters.dat';
my %P; # Gathers all the parameters

my ($options, $usage) = describe_options
  $PROGRAM_NAME . ' %o <FILEPREFIX>',
  [ 'title|t=s', 'Title of the session' ],
  [ 'param|p=s', 'Parameter file (default parameters.dat)' ],
  [ 'help|h',    'Print usage message' ],
  [ 'lang|l=s',  'Language used for the presentation (english or french)', { 'default' => 'french' } ];

if ($options->help) {
	print $usage->text;
	exit;
}

if (! $options->title) {
	print STDERR "Error: Missing --title option\n";
	print STDERR $usage->text;
	exit 1;
}

if (@ARGV != 1) {
	print STDERR "Error: Missing file name prefix\n";
	print STDERR $usage->text;
	exit 1;
}

$P{ParameterFile} = $options->param || $DEFAULT_PARAMETER_FILE;

if (-f $P{ParameterFile}) {
	my @fields;
	
	my $fh = new IO::File $P{ParameterFile}, 'r';

	if (! defined $fh) {
		die "Could not read PARAMETER_FILE $P{ParameterFile} even though it exists: $!";
	}

	while (defined($_ = $fh->getline)) {
		chomp;

		next if /^#/;
		
		@fields = split "\t", $_, 2;
		$P{$fields[0]} = $fields[1] if @fields == 2;
	}
}

$P{Language} = $options->lang || $P{Language} || 'english';
$P{Language} = lc($P{Language});
$P{SessionTitle}  = $options->title;
$P{FilePrefix} = shift;

if (-d $P{FilePrefix} ||
    -f "$P{FilePrefix}.tex" ||
    -f "$P{FilePrefix}_notes.tex" ||
    -f "$P{FilePrefix}_beamer.tex" ||
    -f "$P{FilePrefix}_handout.tex") {
	print STDERR "Error: File name is already taken\n";
	print STDERR $usage->text;
	exit 1;
}

{
	my $err;

	make_path "$P{FilePrefix}/graphics", { error => \$err };
	if (@$err) {
		die "Error creating directory $P{FilePrefix}/graphics";
	}
}

my @suffixes = (qw(_notes _beamer _handout), '');

for my $suffix (@suffixes) {
	my $input_file  = new IO::File "${TEMPLATE_PREFIX}${suffix}.tex", 'r';
	die "Error opening ${TEMPLATE_PREFIX}${suffix}.tex $!" if ! defined $input_file;

	my $output_file = new IO::File "$P{FilePrefix}${suffix}.tex", 'w';
	die "Error opening $P{FilePrefix}${suffix}.tex $!" if ! defined $output_file;

	foreach my $key (keys %P) {
		$output_file->print("% $key\t$P{$key}\n");
	}
	$output_file->print("\n");
	
	while (defined($_ = $input_file->getline)) {
		s/[<](\w+)[>]/(exists $P{$1} ? $P{$1} : "<$1>")/ge;
		
		$output_file->print($_);
	}
}

__END__
