#!/usr/bin/env perl

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=begin COPYRIGHT

	viswap - helper script for managing vi swap files
	Copyright (C) 2018 Benjamin Abendroth
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

=end COPYRIGHT

=begin DESCRIPTION

=end DESCRIPTION

=cut

use strict;
use warnings;
use feature 'say';

use Env qw($EDITOR $HOME $USER);
use FindBin qw($Script);
use Getopt::Long qw(:config gnu_getopt auto_version);
use IPC::System::Simple qw(capture);

my $vim = ($EDITOR eq 'nvim' ? 'nvim' : 'vim');

sub _delete  { unlink $_[0]->{fullpath} }
sub _recover { system $vim, '-r', $_[0]->{fullpath} }
sub _list    { 
   my ($num, $fullpath, $running, $owner) = @$_{qw(num fullpath running owner)};
   say $num, ': ', $fullpath, " [by $owner]", ($running ? ' (running)' : '');
}
sub _cat {
   my $tmp = "/tmp/.$USER.$$.tmp";
   system $vim, '-r', $_[0]->{fullpath}, "+wq!$tmp";
   system 'cat', $tmp;
   unlink $tmp;
}
#sub _diff {
#   system $vim, '-r', $_[0]->{file}, "+wq!test";
#}

my $action = \&_list;

my %filter = (
   num      => undef,
   file     => undef,
   running  => undef,
   modified => undef,
   owner    => undef
);

GetOptions(
   'vim'  => sub { $vim = 'vim' },
   'nvim' => sub { $vim = 'nvim' },

   'cat'     => sub { $action = \&_cat },
   'list'    => sub { $action = \&_list },
   'delete'  => sub { $action = \&_delete },
   'recover' => sub { $action = \&_recover },

   'name=s'  => \$filter{file},
   'num|n=i' => \$filter{num},
   'owner=s' => \$filter{owner},
   'running|r' => sub { $filter{running} = 1 },
   'modified|m' => sub { $filter{modified} = 1 },
   'unmodified|u' => sub { $filter{modified} = 0 },

   'help|h' => sub {
      require Pod::Usage;
      Pod::Usage::pod2usage(-exitstatus => 0, -verbose => 2)
   }
) or exit 1;

my (@files, %file, $dir);
for (capture("$vim -r 2>&1")) {
   s/[\r\n]+$//; # vim -r gives DOS-Newlines?!
   s/\s*//;

   if (/^in directory\s+(.+):/i) {
      $dir = $1;
      $dir =~ s/~/$HOME/;
      $dir =~ s/\/+/\//g;
   } elsif (/^(\d+)\.\s+(.*)/) {
      %file = ( dir => $dir, num => $1, file => $2 );
      $file{file} =~ s/\/+/\//g;
      $file{fullpath} = "$file{dir}$file{file}";
   } elsif (/^modified: (yes|no)/i) {
      $file{modified} = ($1 =~ /yes/i); 
   } elsif (/^owned by: (\w+) \s*dated: (.+)/) {
      $file{owner} = $1;
      $file{date} = $2;
   } elsif (/^process ID: (\d+)\s*(\(still running\))?/) {
      $file{pid} = $1;
      $file{running} = defined $2;
      push @files, { %file };
   }
}

for (@files) {
   next if (
      ($_->{running} and not $filter{running})                               ||
      (defined $filter{file}     and $_->{file}     !~ /$filter{file}/i)     ||
      (defined $filter{num}      and $_->{num}      !=  $filter{num})        ||
      (defined $filter{owner}    and $_->{owner}    ne  $filter{owner})      ||
      (defined $filter{modified} and $_->{modified} !=  $filter{modified})
   );

   $action->($_);
}

__END__

=pod

=head1 NAME

viswap - helper script for managing vi swap files

=head1 SYNOPSIS

=over 8

viswap [B<OPTIONS>]

=back

=head1 OPTIONS

=head2 Basic Startup Options

=over

=item B<--help>

Display this help text and exit.

=item B<--version>

Display the script version and exit.

=back

=head2 Options

=over

=item B<--vim>

Manage swap files of B<vim>

=item B<--nvim>

Manage swap files of B<nvim> 

=back

=head2 Actions

=over

=item B<--list>

List matching files (default action)

=item B<--delete>

Delete matching files

=item B<--recover>

Recover matching files in vim

=item B<--cat>

Recover matching files and write them to stdout

=back

=head2 Filter criteria

=over

=item B<--running>

Also list swap files of opened files

=item B<--modified>

Only list files that have been modified

=item B<--unmodified>

Only list files that have not been modified

=item B<--owner> I<OWNER>

Only list files owned by I<OWNER>

=item B<--name> I<PATTERN>

Grep for files matching I<PATTERN>

=item B<--num|-n> I<N>

Grep file matching number I<N>

=back

=head1 AUTHOR

Written by Benjamin Abendroth.

=cut

