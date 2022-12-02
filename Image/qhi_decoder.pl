#!/usr/bin/perl

# Implementation of the QHI decoder (QOI+Huffman coding), generating a PNG file.

# See also:
#   https://qoiformat.org/
#   https://github.com/phoboslab/qoi

use 5.020;
use warnings;

use Imager;
use experimental qw(signatures);

sub huffman_decode ($bits, $hash) {
    local $" = '|';
    $bits =~ s/(@{[sort { length($a) <=> length($b) } keys %{$hash}]})/$hash->{$1}/gr;    # very fast
}

sub qhi_decoder ($bytes) {

    my sub invalid() {
        die "Not a QHIF image";
    }

    my $index = 0;

    join('', map { $bytes->[$index++] } 1 .. 4) eq 'qhif' or invalid();

    my $width  = unpack('N', join('', map { $bytes->[$index++] } 1 .. 4));
    my $height = unpack('N', join('', map { $bytes->[$index++] } 1 .. 4));

    my $channels   = ord $bytes->[$index++];
    my $colorspace = ord $bytes->[$index++];

    ($width > 0 and $height > 0) or invalid();
    ($channels > 0 and $channels <= 4) or invalid();
    ($colorspace == 0 or $colorspace == 1) or invalid();

    ord(pop(@$bytes)) == 0x01 or invalid();

    for (1 .. 7) {
        ord(pop(@$bytes)) == 0x00 or invalid();
    }

    say "[$width, $height, $channels, $colorspace]";

    my $img = 'Imager'->new(
                            xsize    => $width,
                            ysize    => $height,
                            channels => $channels,
                           );

    my $run = 0;
    my @px  = (0, 0, 0, 255);

    my @pixels;
    my @colors = (map { [0, 0, 0, 0] } 1 .. 64);

    my @codes;
    my $codes_len = 0;

    foreach my $c (0 .. 255) {
        my $l = ord($bytes->[$index++]);
        if ($l > 0) {
            $codes_len += $l;
            push @codes, [$c, $l];
        }
    }

    my $codes_bin = '';
    while (length($codes_bin) < $codes_len) {
        $codes_bin .= unpack('B*', $bytes->[$index++] // last);
    }

    my %rev_dict;
    foreach my $pair (@codes) {
        my $code = substr($codes_bin, 0, $pair->[1], '');
        $rev_dict{$code} = chr($pair->[0]);
    }

    my $enc_len = unpack('N', join('', map { $bytes->[$index++] } 1 .. 4));

    splice(@$bytes, 0, $index);

    if ($enc_len > 0) {
        @$bytes = unpack("C*", huffman_decode(unpack("B" . $enc_len, join('', @$bytes)), \%rev_dict));
    }
    else {
        @$bytes = ();
    }

    $index  = 0;

    while (1) {

        if ($run > 0) {
            --$run;
        }
        else {
            my $byte = $bytes->[$index++] // last;

            if ($byte == 0b11_11_11_10) {    # OP RGB
                $px[0] = $bytes->[$index++];
                $px[1] = $bytes->[$index++];
                $px[2] = $bytes->[$index++];
            }
            elsif ($byte == 0b11_11_11_11) {    # OP RGBA
                $px[0] = $bytes->[$index++];
                $px[1] = $bytes->[$index++];
                $px[2] = $bytes->[$index++];
                $px[3] = $bytes->[$index++];
            }
            elsif (($byte >> 6) == 0b00) {      # OP INDEX
                @px = @{$colors[$byte]};
            }
            elsif (($byte >> 6) == 0b01) {      # OP DIFF
                my $dr = (($byte & 0b00_11_00_00) >> 4) - 2;
                my $dg = (($byte & 0b00_00_11_00) >> 2) - 2;
                my $db = (($byte & 0b00_00_00_11) >> 0) - 2;

                ($px[0] += $dr) %= 256;
                ($px[1] += $dg) %= 256;
                ($px[2] += $db) %= 256;
            }
            elsif (($byte >> 6) == 0b10) {      # OP LUMA
                my $byte2 = $bytes->[$index++];

                my $dg    = ($byte & 0b00_111_111) - 32;
                my $dr_dg = ($byte2 >> 4) - 8;
                my $db_dg = ($byte2 & 0b0000_1111) - 8;

                my $dr = $dr_dg + $dg;
                my $db = $db_dg + $dg;

                ($px[0] += $dr) %= 256;
                ($px[1] += $dg) %= 256;
                ($px[2] += $db) %= 256;
            }
            elsif (($byte >> 6) == 0b11) {    # OP RUN
                $run = ($byte & 0b00_111_111);
            }

            $colors[($px[0] * 3 + $px[1] * 5 + $px[2] * 7 + $px[3] * 11) % 64] = [@px];
        }

        push @pixels, @px;
    }

    foreach my $row (0 .. $height - 1) {
        my @line = splice(@pixels, 0, 4 * $width);
        $img->setscanline(y => $row, pixels => pack("C*", @line));
    }

    return $img;
}

@ARGV || do {
    say STDERR "usage: $0 [input.qhi] [output.png]";
    exit(2);
};

my $in_file  = $ARGV[0];
my $out_file = $ARGV[1] // "$in_file.png";

my @chars = do {
    open(my $fh, '<:raw', $in_file)
      or die "Can't open file <<$in_file>> for reading: $!";
    local $/;
    split(//, scalar <$fh>);
};

my $img = qhi_decoder(\@chars);
$img->write(file => $out_file, type => 'png');
