use strict;
use warnings;

use Test::More;
use Text::CSV::Auto qw( analyze_csv );

my $expected = [
          {
            'integer' => 1,
            'min' => 479,
            'max' => 2749,
            'integer_length' => 4,
            'header' => 'feature_id'
          },
          {
            'string_length' => 18,
            'string' => 1,
            'header' => 'feature_name'
          },
          {
            'string_length' => 15,
            'string' => 1,
            'header' => 'feature_class'
          },
          {
            'integer' => 1,
            'min' => 170,
            'max' => 12070,
            'integer_length' => 5,
            'header' => 'census_code'
          },
          {
            'string_length' => 2,
            'string' => 1,
            'header' => 'census_class_code'
          },
          {
            'integer' => 1,
            'min' => 5,
            'undef' => 1,
            'max' => 80,
            'integer_length' => 2,
            'header' => 'gsa_code'
          },
          {
            'integer' => 1,
            'min' => 40005013,
            'undef' => 1,
            'max' => 40080013,
            'integer_length' => 8,
            'header' => 'opm_code'
          },
          {
            'integer' => 1,
            'min' => 4,
            'max' => 4,
            'integer_length' => 1,
            'header' => 'state_numeric'
          },
          {
            'string_length' => 2,
            'string' => 1,
            'header' => 'state_alpha'
          },
          {
            'integer' => 1,
            'min' => 1,
            'max' => 1,
            'integer_length' => 1,
            'header' => 'county_sequence'
          },
          {
            'integer' => 1,
            'min' => 1,
            'max' => 25,
            'integer_length' => 2,
            'header' => 'county_numeric'
          },
          {
            'string_length' => 8,
            'string' => 1,
            'header' => 'county_name'
          },
          {
            'fractional_length' => 7,
            'min' => '31.3514908',
            'max' => '36.6016535',
            'decimal' => 1,
            'integer_length' => 2,
            'header' => 'primary_latitude'
          },
          {
            'fractional_length' => 7,
            'min' => '-114.5682983',
            'max' => '-109.4870088',
            'decimal' => 1,
            'unsigned' => 1,
            'integer_length' => 3,
            'header' => 'primary_longitude'
          },
          {
            'mdy_date' => 1,
            'header' => 'date_created'
          },
          {
            'mdy_date' => 1,
            'undef' => 1,
            'header' => 'date_edited'
          }
        ];

my $info = analyze_csv('t/features.csv');

is_deeply(
    $info,
    $expected,
    'analyze returned the expected results',
);

done_testing;
