#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use Test2::V0;
use PowerSupplyControl::Math::ThermalModel;

my $model = PowerSupplyControl::Math::ThermalModel->new({
    resistance => 2.5,
    capacity => 40,
});
isa_ok($model, 'PowerSupplyControl::Math::ThermalModel');

is($model->period, 1, 'Default period');
is($model->ambient, 20, 'Default ambient');
is($model->resistance, 2.5, 'resistance');
is($model->capacity, 40, 'capacity');
is($model->kp, 0.025, 'kp');
is($model->kt, 0.01, 'kt');

is($model->period(2), 1, 'change period from 1 to 2');
is($model->period, 2, 'period');
is($model->capacity, 40, 'capacity');
is($model->resistance, 2.5, 'resistance');
is($model->kp, 0.05, 'kp');
is($model->kt, 0.02, 'kt');

is($model->resistance(5), 2.5, 'change resistance from 2.5 to 5');
is($model->period, 2, 'period');
is($model->resistance, 5, 'resistance');
is($model->capacity, 40, 'capacity');
is($model->kp, 0.05, 'kp');
is($model->kt, 0.01, 'kt');

is($model->capacity(50), 40, 'change capacity from 40 to 50');
is($model->period, 2, 'period');
is($model->resistance, 5, 'resistance');
is($model->capacity, 50, 'capacity');
is($model->kp, 0.04, 'kp');
is($model->kt, 0.008, 'kt');

is($model->kp(0.8), 0.04, 'change kp from 0.04 to 0.8');
is($model->period, 2, 'period');
is($model->resistance, 100, 'resistance');
is($model->capacity, 2.5, 'capacity');
is($model->kp, 0.8, 'kp');
is($model->kt, 0.008, 'kt');

is($model->kt(0.01), 0.008, 'change kt from 0.008 to 0.01');
is($model->period, 2, 'period');
is($model->resistance, 80, 'resistance');
is($model->capacity, 2.5, 'capacity');
is($model->kp, 0.8, 'kp');
is($model->kt, 0.01, 'kt');

is($model->period(1), 2, 'change period from 2 to 1');
is($model->period, 1, 'period');
is($model->resistance, 80, 'resistance');
is($model->capacity, 1.25, 'capacity');
is($model->kp, 0.8, 'kp');
is($model->kt, 0.01, 'kt');

is($model->capacity(10), 1.25, 'change capacity from 1.25 to 10');
is($model->period(1.5), 1, 'change period from 1 to 1.5');
is($model->period, 1.5, 'period');
is($model->resistance, 80, 'resistance');
is($model->capacity, 10, 'capacity');
is($model->kp, 0.15, 'kp');
is($model->kt, 0.001875, 'kt');

$model = PowerSupplyControl::Math::ThermalModel->new({ capacity => 40, resistance => 2.5 });
is($model->predictDeltaT(100, 20), 2.5, 'predict temperature change for 100W power applied at 20C ambient');
is($model->predictDeltaT(80, 60), 1.6, 'predict temperature change for 80W power applied at 60C ambient');
is($model->predictPower(20, 21), 40, 'predict power required to achieve temperature change from 20 to 21');
is($model->predictPower(60, 61.2), float(64, tolerance => 0.0000001), 'predict power required to achieve temperature change from 60 to 61.2');

done_testing; 