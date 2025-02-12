#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 12 August 2013
# Website: https://trizenx.blogspot.com

#
## A very simple file compressor.
#

# Best usage of this script is to compress files which
# contains not so many different bytes (for example, DNA-sequences)

use 5.010;
use strict;
use autodie;
use warnings;

use List::Util     qw(min);
use Getopt::Std    qw(getopts);
use File::Basename qw(basename);

our $DEBUG = 0;

use constant {
              CHUNK_SIZE => 1024,             # in bytes
              SIGNATURE  => 'TZP' . chr(1),
              FORMAT     => 'tzp',
             };

sub main {
    my %opt;
    getopts('ei:o:vh', \%opt);

    $opt{h} && help() && exit(0);

    my ($input, $output) = @ARGV;
    $input  //= $opt{i} // (help() && exit 1);
    $output //= $opt{o};

    $DEBUG = $opt{v};
    my $ext = qr{\.${\FORMAT}\z}i;
    if ($opt{e} || $input =~ $ext) {

        if (not defined $output) {
            ($output = $input) =~ s{$ext}{}
              || die "$0: no output file specified!\n";
        }

        if (-e $output) {
            print "'$output' already exists! -- Replace? [y/N] ";
            <STDIN> =~ /^y/i || exit 17;
        }

        decompress($input, $output)
          || die "$0: error: decompression failed!\n";
    }
    elsif ($input !~ $ext || (defined($output) && $output =~ $ext)) {
        $output //= basename($input) . '.' . FORMAT;
        compress($input, $output)
          || die "$0: error: compression failed!\n";
    }
    else {
        warn "$0: don't know what to do...\n";
        help() && exit 1;
    }
}

sub help {
    print <<"EOH";
usage: $0 [options] [input file] [output file]

options:
        -e            : extract
        -i <filename> : input filename
        -o <filename> : output filename

        -v            : verbose mode
        -h            : this message

examples:
         $0 document.txt
         $0 document.txt archive.tzp
         $0 archive.tzp document.txt
         $0 -e -i archive.tzp -o document.txt

EOH

    return 1;
}

sub _make_map {
    my ($int) = @_;

    my @groups = ([], [], []);
    for my $i (1 .. 3) {
        foreach my $j (0 .. length($int) - $i) {
            $i > 1 && substr($int, $j, 1) == 0 && next;
            (my $num = substr($int, $j, $i)) > 255 && next;
            $groups[$i - 1][$j] = $num;
        }
    }

    my @map = [[]];
    for (my $j = 0 ; $j <= $#{$groups[0]} ; $j++) {
        for (my $i = $j ; $i <= $#{$groups[0]} ; $i++) {
            if (defined($groups[2][$i])) {
                push @{$map[$j][$j]}, $groups[2][$i];
                $i += 2;
            }
            elsif (defined($groups[1][$i])) {
                push @{$map[$j][$j]}, $groups[1][$i];
                $i += 1;
            }
            else {
                push @{$map[$j][$j]}, $groups[0][$i];
            }
        }
    }

    return \@map;
}

sub int2bytes {
    my ($int) = @_;

    my $data = _make_map($int);

    my @nums;
    foreach my $arr (@{$data}) {
        for my $i (0 .. $#{$arr}) {
            if (ref($arr->[$i]) eq 'ARRAY') {
                my $head = _make_map(substr($int, 0, $i));
                push @nums, [@{$head->[0][0]}, @{$arr->[$i]}];
            }
        }
    }

    my $min   = min(map { $#{$_} } @nums);
    my @bytes = do {
        my %seen;
        grep { !$seen{join(' ', @{$_})}++ } grep { $#{$_} == $min } @nums;
    };

    return \@bytes;
}

sub next_power_of_two {
    my ($number) = @_;

    return 2 if $number <= 1;

    ## If the number is a power of
    ## two, then return it as it is.
    unless ($number & ($number - 1)) {
        return $number;
    }

    ## Return the next power of two
    return 2 << (log($number) / log(2));
}

sub valid_archive {
    my ($fh) = @_;

    if (read($fh, (my $sig), length(SIGNATURE), 0) == length(SIGNATURE)) {
        $sig eq SIGNATURE || return;
    }

    return 1;
}

sub open_file {
    my ($mode, $file) = @_;
    open(my $fh, $mode, $file);
    return $fh;
}

sub uniq_bytes {
    my ($fh) = @_;

    my %table;
    while (my $size = read($fh, (my $chunk), CHUNK_SIZE)) {
        @table{split //, $chunk} = ();
    }

    seek($fh, 0, 0);
    return [keys %table];
}

sub info {
    my (%info) = @_;

    print STDERR <<"EOT";
input       : $info{input}
output      : $info{output}
filesize    : $info{filesize}
bits num    : $info{bits_num}
bytes num   : $info{bytes_num}
compressing : $info{compress}
EOT
}

sub compress {
    my ($input, $output) = @_;

    my $fh     = open_file('<:raw', $input);
    my $out_fh = open_file('>:raw', $output);

    my $filesize = -s $input;

    my $uniq_bytes = uniq_bytes($fh);
    my $bytes_num  = scalar @{$uniq_bytes};
    my $bits_num   = log(next_power_of_two($bytes_num)) / log(2);

    $DEBUG
      && info(
              bytes_num => $bytes_num,
              bits_num  => $bits_num,
              input     => $input,
              output    => $output,
              filesize  => $filesize,
              compress  => 'true',
             );

    my %table;
    my $bits_map = '';

    foreach my $i (0 .. $#{$uniq_bytes}) {
        $bits_map .= ($table{$uniq_bytes->[$i]} = sprintf("%0${bits_num}b", $i));
    }

    my $size_bytes = ${int2bytes($filesize)}[0];

    print {$out_fh} SIGNATURE,
      chr($#{$size_bytes} + 1),
      join('', map { chr } @{$size_bytes}),
      chr($bits_num), chr($bytes_num - 1),
      join('', @{$uniq_bytes}), pack('B*', $bits_map);

    while (my $size = read($fh, (my $chunk), CHUNK_SIZE)) {
        print {$out_fh} scalar pack "B*", join('', @table{split //, $chunk});
    }

    return 1;
}

sub decompress {
    my ($input, $output) = @_;

    my $fh     = open_file('<:raw', $input);
    my $out_fh = open_file('>:raw', $output);

    valid_archive($fh) || die "$0: file `$input' is not a TZP archive!\n";

    my $fsize_len = do { read($fh, (my $byte), 1); ord $byte };
    my $filesize  = do {
        read($fh, (my $bytes), $fsize_len);
        join('', unpack('C*', $bytes));
    };

    my $bits_num  = do { read($fh, (my $byte), 1); ord $byte };
    my $bytes_num = do { read($fh, (my $byte), 1); 1 + ord $byte };

    $DEBUG
      && info(
              bytes_num => $bytes_num,
              bits_num  => $bits_num,
              input     => $input,
              output    => $output,
              filesize  => $filesize,
              compress  => 'false',
             );

    my $bytes = do { read($fh, (my $bytes), $bytes_num); [split(//, $bytes)] };

    my $bits_len = $bits_num * $bytes_num;
    if ((my $mod = $bits_len % 8) != 0) {
        $bits_len += 8 - $mod;
    }

    my $bits = do { read($fh, my ($bytes), $bits_len / 8); unpack 'B*', $bytes };

    my %table;
    foreach my $byte (@{$bytes}) {
        $table{substr($bits, 0, $bits_num, '')} = $byte;
    }

    my $byte_counter = 0;
    my $prev_bits    = '';
    while (my $size = read($fh, (my $chunk), CHUNK_SIZE)) {

        my $bits     = $prev_bits . unpack('B*', $chunk);
        my $bits_len = 8 * $size + length($prev_bits);

        my $left = $bits_len % $bits_num;

        $prev_bits =
          $left == 0
          ? q{}
          : substr($bits, $bits_len - $left, $bits_len, '');

        if (($byte_counter += int($bits_len / $bits_num)) > $filesize) {
            $bits_len -= ($byte_counter - $filesize);
        }

        print {$out_fh} join('', @{table}{unpack("(a$bits_num)" . int($bits_len / $bits_num), $bits)});
    }

    return 1;
}

main();
exit(0);
