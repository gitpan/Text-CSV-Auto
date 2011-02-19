package Text::CSV::Auto;
BEGIN {
  $Text::CSV::Auto::VERSION = '0.02';
}

=head1 NAME

Text::CSV::Auto - Comprehensive and automatic loading, processing, and
analysis of CSV files.

=head1 SYNOPSIS

Given a CSV file like this:

    name,age,gender
    Jill,44,f
    Bob,32,m
    Joe,51,m
    June,23,f

You could do this:

    use Text::CSV::Auto qw( process_csv );
    
    process_csv(
        'path/to/file.csv',
        sub{
            my ($row) = @_;

            print "$row->{name} is $row->{age} years old.\n";
        },
    );

You can also slurp in all the rows in one giant array of hashes:

    use Text::CSV::Auto qw( slurp_csv );
    
    my $rows = slurp_csv( 'path/to/file.csv' );
    foreach my $row (@$rows) {
        print "$row->{name} is $row->{age} years old.\n";
    }

You can also get an analysis about the content of the file:

    use Text::CSV::Auto qw( analyze_csv );
    
    my $headers = analyze_csv( 'path/to/file.csv' );

This will give you something like this:

    [
        {
            header        => 'name',
            string        => 1,
            string_length => 4,
        },
        {
            header          => 'age',
            integer         => 1,
            min             => 23,
            max             => 51,
            integer_length  => 2,
        },
        {
            header        => 'gender',
            string        => 1,
            string_length => 1,
        },
    ]

=head1 DESCRIPTION

This module provides utilities to quickly process and analyze CSV files
with as little hassle as possible.

The reliable and robust L<Text::CSV_XS> module is used for the actual
CSV parsing.  This module provides a simpler and smarter interface.  In
most situations all you need to do is specify the filename of the file
and this module will automatically figure out what kind of separator is
used and set some good default options for processing the file.

The name CSV is misleading as any variable-width delimited file should
be fine including TSV files and pipe "|" delimited files to name a few.

=cut

use feature ':5.10';

use Text::CSV_XS;
use Text::CSV::Separator qw( get_separator );
use List::MoreUtils qw( zip );
use autodie;
use Carp qw( croak );
use Clone qw( clone );

use Exporter qw( import );
our @EXPORT_OK = qw( process_csv slurp_csv analyze_csv );

=head1 SUBROUTINES

=head2 process_csv

    process_csv(
        $filename,
        $options, # optional
        $code_ref,
    );

For each row that is found in the CSV it will be converted in to a hash
and the code reference you pass will be executed with the row hashref as
the first argument.

Options may be specified as a hashref.  Any options that L<Text::CSV_XS>
supports, such as sep_char and binary, can be set.  Some sane options are
set by default but can be overriden:

    binary    => 1 # Assume there is binary data.
    auto_diag => 2 # die() if there are any errors.
    sep_char  => ... # Automatically detected.

Read the L<Text::CSV_XS> docs to see the many options that it supports.

There are additional options that can be set that affect how this module
works.  Read below about the additional options that are supported:

=head3 headers

By default headers are pulled from the first row in the CSV.  In some
cases a CSV file does not have headers.  In these cases you should
specify an arrayref of header names that you would like to use.

    headers => ['foo', 'bar']

=head3 format_headers

When the first row is pulled from the CSV to determine the headers
this option will cause them to be formatted to be more consistent
and remove duplications.  For example, if this were the headers:

    Parents Name,Parent Age,Child Name,Child Age,Child Name,Child Age

The headers would be transformed too:

    parent_name,parent_age,child_name,child_age,child_name_2,child_age_2

This option is enabled by default.  You can turn it off if you want:

    format_headers => 0

=head3 skip_rows

An arrayref of row numbers to skip can be specified.  This is useful for
CSV files that contain ancillary rows that you don't want to be processed.
For example, you could ignore the 2nd row and the 5th through the 10th rows:

    skip_rows => [2, 5..10]

=head3 max_rows

By default all rows will be processed.  In some cases you only want to
run a sample set of rows.  This option will limit the number of rows
processed.  This is most useful for when you are using analyze_csv() on
a very large file where you don't need every row to be analyzed.

    max_rows => 50

=cut

sub process_csv {
    my ($file, $options, $sub) = @_;

    if (!$sub) {
        $sub = $options;
        $options = {};
    }

    $options = _validate( $file, $options );
    delete( $options->{_validated} );

    my $headers        = delete( $options->{headers} );
    my $format_headers = delete( $options->{format_headers} ) // 1;
    my $skip_rows      = delete( $options->{skip_rows} ) // [];
    my $max_rows       = delete( $options->{max_rows} );

    $skip_rows = { map { $_=>1 } @$skip_rows };

    my $csv = Text::CSV_XS->new($options);

    my $rows = [];
    my $row_number = 0;
    open( my $fh, '<', $file );
    while (my $row = $csv->getline($fh)) {
        $row_number ++;
        next if $skip_rows->{$row_number};

        if (!$headers) {
            $headers = $row;
            $headers = _format_headers( $headers ) if $format_headers;
            $row_number --;
            next;
        }

        next if (@$row == 1) and $row->[0] ~~ '';

        if (@$headers != @$row) {
            croak 'Header count does not match row #' . $row_number;
        }

        $row = { zip @$headers, @$row };

        $sub->( $row, $headers );

        last if $max_rows and $row_number >= $max_rows;
    }
    $csv->eof() or $csv->error_diag();
    close( $fh );

    return;
}

=head2 slurp_csv

    my $rows = slurp_csv(
        $filename,
        $options, # optional
    );

Specify a filename and all the rows will be returned as an array of hashes.

Supports the exact same options as process_csv().

=cut

sub slurp_csv {
    my ($file, $options) = @_;

    $options = _validate( $file, $options );

    my $rows = [];
    process_csv(
        $file,
        $options,
        sub{
            my ($row) = @_;
            push @$rows, $row;
        },
    );

    return $rows;
}

=head2 analyze_csv

    my $info = analyze_csv(
        $filename,
        $options, # optional
        $sub, # optional
    );

Returns an array of hashes where each hash represents a header in
the CSV file.  The hash will contain a lot of different meta data
about the data that was found in the rows for that header.

It is possible that within the same header that multiple data types are found,
such as finding a integer value on one row then a string value on another row
within the same header.  In a case like this both the integer=>1 and string=>1
flags would be set.

Supports the exact same options as process_csv().

The meta data can contain any of the follow values:

=head3 string => 1

A value did not look like a number.

=head3 string_length => ...

The length of the largest value.

=head3 integer => 1

A value looked like a integer (non-decimal number).

=head3 integer_length => ...

The number of integer digits in the largest value.

=head3 decimal => 1

A value looked like a decimal.

=head3 fractional_length => ...

The number of decimal digits in the value with the most decimal places.

=head3 max => ...

The maximum number value found.

=head3 min => ...

The minimum number value found.

=head3 mdy_date => 1

A value had the format of "MM/DD/YYYY".

=head3 ymd_date => 1

A value had the format of "YYYY-MM-DD".

=head3 unsigned => 1

A negative number was found.

=head3 undef => 1

An empty value was found.

=cut

sub analyze_csv {
    my ($file, $options) = @_;

    $options = _validate( $file, $options );

    my $types;
    my $headers;
    process_csv(
        $file,
        $options,
        sub{
            my ($row, $row_headers) = @_;
            $headers //= $row_headers;

            foreach my $header (@$headers) {
                my $type = $types->{$header} //= {};
                my $value = $row->{$header};

                my $is_number;
                if ($value ~~ '') {
                    $type->{undef} = 1;
                }
                elsif ($value =~ m{^(-?)(\d+)$}s) {
                    my ($dash, $left) = ($1, $2);
                    $type->{unsigned} = 1 if $dash;
                    $type->{integer_length} = length($left+0);
                    $type->{integer} = 1;
                    $is_number = 1;
                }
                elsif ($value =~ m{^(-?)(\d+)\.(\d+)$}s) {
                    my ($dash, $left, $right) = ($1, $2, $3);
                    $type->{unsigned} = 1 if $dash;

                    $left  = length($left+0);
                    $right = length($right);

                    $type->{integer_length}  //= 0;
                    $type->{fractional_length} //= 0;

                    $type->{integer_length}  = $left if $left > $type->{integer_length};
                    $type->{fractional_length} = $right if $right > $type->{fractional_length};

                    $type->{decimal} = 1;
                    $is_number = 1;
                }
                elsif ($value =~ m{^\d\d/\d\d/\d\d\d\d}) {
                    $type->{mdy_date} = 1;
                }
                elsif ($value =~ m{^\d\d\d\d-\d\d-\d\d}) {
                    $type->{ymd_date} = 1;
                }
                else {
                    my $length = length( $value );

                    $type->{string_length} //= 0;
                    $type->{string_length} = $length if $length > $type->{string_length};

                    $type->{string} = 1;
                }

                if ($is_number) {
                    $value += 0;

                    $type->{min} //= $value;
                    $type->{max} //= $value;

                    $type->{min} = $value if $value < $type->{min};
                    $type->{max} = $value if $value > $type->{max};
                }
            }
        },
    );

    $types = [
        map { $types->{$_}->{header} = $_; $types->{$_} }
        @$headers
    ];

    return $types;
}

sub _validate {
    my ($file, $options) = @_;

    return $options if $options->{_validated};

    croak 'A filename must be passed as the first argument' if !$file;
    croak 'The file "' . $file . '" does not exist' if !-e $file;
    croak 'The file name "' . $file . '" is not a file' if !-f $file;

    $options = $options ? clone($options) : {};

    $options->{auto_diag} //= 2;
    $options->{binary} //= 1;

    if (!$options->{sep_char}) {
        my @chars = get_separator( path => $file );
        croak 'Unable to automatically detect the sep_char' if @chars != 1;
        ($options->{sep_char}) = @chars;
    }

    $options->{_validated} = 1;

    return $options;
}

sub _format_headers {
    my ($headers) = @_;

    my $header_lookup = {};
    my $new_headers = [];
    foreach my $header (@$headers) {
        $header = lc( $header );
        $header =~ s{-}{_}g;
        $header =~ s{[^a-z_0-9-]+}{_}gs;
        $header =~ s{^_*(.+?)_*$}{$1};
        $header =~ s{_{2,}}{_}g;

        if ($header_lookup->{$header}) {
            my $new_header;
            foreach my $num (2..100) {
                $new_header = $header . '_' . $num;
                last if !$header_lookup->{$new_header};
            }
            $header = $new_header;
        }
        $header_lookup->{$header} = 1;

        push @$new_headers, $header;
    }

    return $new_headers;
}

1;
__END__

=head1 AUTHOR

Aran Clary Deltac <bluefeet@gmail.com>

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

