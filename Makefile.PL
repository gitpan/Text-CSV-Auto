
use strict;
use warnings;

BEGIN { require v5.10.0; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Comprehensive and automatic loading, processing, and analysis of CSV files.',
  'AUTHOR' => 'Aran Deltac <bluefeet@gmail.com>',
  'BUILD_REQUIRES' => {},
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Text-CSV-Auto',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Text::CSV::Auto',
  'PREREQ_PM' => {
    'Clone' => '0.31',
    'List::MoreUtils' => '0.30',
    'Text::CSV::Separator' => '0.20',
    'Text::CSV_XS' => '0.80',
    'autodie' => '2.10'
  },
  'VERSION' => '0.02',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



