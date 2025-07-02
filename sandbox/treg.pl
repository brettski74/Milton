#!/usr/bin/perl

use Statistics::Regression;

my $NOISE = shift || 1;
my $period = shift || 1.5;
my $RT = shift || 2.4;
my $CT = shift || 45;
my $a = $period / $CT;
my $b = $period / ($CT * $RT);

my $t = 0;
my $AMBIENT = 20;
my $DATA = [ { time => 0
             , start_temp => $AMBIENT
             , end_temp => $AMBIENT
             , deltaT => 0
             , power => 0
             , noisy => { end_temp => $AMBIENT }
             }
           ];

sub generate_data_point {
  my ($power, $data) = @_;

  my $last = $data->[$#$data];
  my $rise = $last->{end_temp} - $AMBIENT;

  # Calculate real temperature using model
  my $deltaT = $a * $power - $b * $rise;
  my $start_temp = $last->{end_temp};
  my $end_temp = $start_temp + $deltaT;

  # Add some noise to the temperature reading
  my $noise = (rand(2) - 1) * $NOISE;

  my $time = $last->{time} + $period;

  my $dp = { time => $time
           , start_temp => $start_temp
           , end_temp => $end_temp
           , rel_temp => $end_temp - $AMBIENT
           , deltaT => $deltaT
           , power => $power
           , noisy => { start_temp => $last->{noisy}->{end_temp}
                      , end_temp => $end_temp + $noise
                      , rel_temp => $end_temp + $noise - $AMBIENT
                      , deltaT => $end_temp + $noise - $last->{noisy}->{end_temp}
                      , power => $power
                      , time => $time
                      , const => 1
                      }
           };

  push @$data, $dp;
  return $dp;
}

sub add_data_point {
  my ($power, $regression, $data) = @_;

  my $dp = generate_data_point($power, $data);
  my $sample = $dp->{noisy};

  $regression->include($sample->{deltaT}, $sample);
  my $theta = $regression->theta;

  print join(',', $dp->{end_temp}
                , $dp->{rel_temp}
                , $dp->{deltaT}
                , $dp->{power}
                , $sample->{end_temp}
                , $sample->{rel_temp}
                , $sample->{deltaT}
                , $regression->theta
                )
                ."\n";
}

my $reg = Statistics::Regression->new('hotplate regression', [ 'power', 'rel_temp' ]);
print join(',', 'Real End Temp'
              , 'Real Rel Temp'
              , 'Real Temp Delta'
              , 'Power'
              , 'Sample End Temp'
              , 'Sample Rel Temp'
              , 'Sample Temp Delta'
              , 'Real a'
              , 'Real b'

add_data_point(49, $reg, $DATA);
add_data_point(50, $reg, $DATA);
add_data_point(51, $reg, $DATA);

add_data_point(100, $reg, $DATA);
add_data_point(95, $reg, $DATA);
add_data_point(102, $reg, $DATA);
add_data_point(98, $reg, $DATA);
add_data_point(97, $reg, $DATA);

add_data_point(81, $reg, $DATA);
add_data_point(88, $reg, $DATA);
add_data_point(86, $reg, $DATA);
add_data_point(81, $reg, $DATA);
add_data_point(82, $reg, $DATA);

add_data_point(83, $reg, $DATA);
add_data_point(80, $reg, $DATA);
add_data_point(80, $reg, $DATA);
add_data_point(87, $reg, $DATA);
add_data_point(89, $reg, $DATA);

add_data_point(86, $reg, $DATA);
add_data_point(81, $reg, $DATA);
add_data_point(40, $reg, $DATA);
add_data_point(60, $reg, $DATA);
add_data_point(67, $reg, $DATA);

