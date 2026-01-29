#!/usr/bin/perl

use Path::Tiny;
use FindBin qw($RealBin);
use lib path($RealBin)->sibling('lib', 'perl5')->stringify;
use Milton::Config::Path;

use strict;
use warnings qw(all -uninitialized);

use strict;
use warnings qw(all -uninitialized);

use Milton::Config::Utils qw(find_reflow_profiles find_linear_profiles get_device_names);
use Milton::Config::Path qw(standard_search_path);

use Mojolicious::Lite;
use MiltonUI::CommandExecutor;

# Enable debug mode for development
app->log->level('debug');

# Configure WebSocket timeouts
app->config(
  hypnotoad => {
    inactivity_timeout => 300,  # 5 minutes instead of default 20 seconds
    keep_alive_timeout => 300,  # 5 minutes keep-alive
  }
);

standard_search_path();

# Configure WebSocket settings
# Can't locate object method "websocket_timeout" via package "Mojolicious::Lite" at webui/web_server.pl line 28.
# app->websocket_timeout(300);  # 5 minutes WebSocket timeout

# Create command executor
my $command_executor = MiltonUI::CommandExecutor->new();

# Serve static files from shared/public directories (user/local/system) with app-local as fallback
app->static->paths([
  $ENV{MILTON_BASE} . '/share/milton/webui/public',
  app->home->child('public'),
]);

# Template search paths (user/local/system) with app-local as fallback
app->renderer->paths([
  $ENV{MILTON_BASE} . '/share/milton/webui/templates',
  app->home->child('templates'),
]);

# Basic routes
get '/' => sub { my $c = shift;
                 $c->render('index');
               };

# API endpoints
group {
  # API routes go here
  my $PARAM_AMBIENT = { name => 'ambient'
                      , type => 'number'
                      , required => 0
                      , description => 'Ambient temperature in °C (optional)'
                      };
  my $PARAM_DEVICE = { name => 'device'
                     , type => 'pdlist'
                     , required => 0
                     , description => 'Calibration device to use (optional)'
                     , url => '/api/devices'
                     };
  my $PARAM_PROFILE = { name => 'profile'
                      , type => 'pdlist'
                      , required => 0
                      , description => 'Reflow Profile (optional)'
                      , url => '/api/reflow/profiles'
                      };
  # List available commands
  get '/api/commands' => sub {
    my $c = shift;
    $c->render(json => { commands => [ { name => 'power'
                                       , description => 'Constant power'
                                       , parameters => [ { name => 'power'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Power to apply in watts'
                                                         }
                                                       , { name => 'duration'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Duration of power application in seconds (optional)'
                                                         }
                                                       , $PARAM_AMBIENT
                                                       , $PARAM_DEVICE
                                                       ]
                                       }
                                     , { name => 'onePointCal'
                                       , description => 'One-point calibration'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , $PARAM_DEVICE
                                                       ]
                                       }
                                     , { name => 'reflow'
                                       , description => 'Execute reflow profile'
                                       , parameters => [ { name => 'profile'
                                                         , type => 'pdlist'
                                                         , required => 0
                                                         , description => 'Reflow Profile (optional)'
                                                         , url => '/api/reflow/profiles'
                                                         }
                                                       , $PARAM_AMBIENT
                                                       , $PARAM_DEVICE
                                                       ]
                                       }
                                     , { name => 'linear'
                                       , description => 'Execute a linear reflow profile'
                                       , parameters => [ { name => 'profile'
                                                         , type => 'pdlist'
                                                         , required => 1
                                                         , description => 'Reflow Profile'
                                                         , default => 'snpb-standard'
                                                         , url => '/api/linear/profiles'
                                                         }
                                                       , $PARAM_AMBIENT
                                                       , { name => 'tune'
                                                         , type => 'boolean'
                                                         , required => 0
                                                         , description => 'Tune the specified linear reflow profile.'
                                                         }
                                                       ]
                                       }
                                     , { name => 'setup'
                                       , description => 'Calibrate a new hotplate PCB'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , { name => 'profile'
                                                         , type => 'pdlist'
                                                         , required => 1
                                                         , description => 'Reflow Profile'
                                                         , default => 'calibration'
                                                         , url => '/api/reflow/profiles'
                                                         }
                                                       , $PARAM_DEVICE
                                                       , { name => 'rtd-calibration'
                                                         , type => 'text'
                                                         , required => 1
                                                         , description => 'The name of the file where the RTD calibration data will be written'
                                                         , default => $command_executor->getConfigPath('controller', 'calibration')
                                                         }
                                                       , { name => 'predictor-calibration'
                                                         , type => 'text'
                                                         , required => 0
                                                         , description => 'The name of the file where the predictor calibration data will be written'
                                                         , default => $command_executor->getConfigPath('controller', 'predictor')
                                                         }
                                                       ]
                                       }
                                     , { name => 'rework'
                                       , description => 'Constant temperature (Rework or Preheat)'
                                       , parameters => [ { name => 'temperature'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Temperature to apply in °C'
                                                         , order => 2
                                                         }
                                                       , { name => 'ramp'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Ramp up time in seconds (optional)'
                                                         , order => 3
                                                         }
                                                       , { name => 'cutoff'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Heating element cutoff temperature in °C (optional)'
                                                         , order => 4
                                                         }
                                                       , { name => 'limit'
                                                         , type => 'text'
                                                         , required => 0
                                                         , description => 'Heating element limit temperature:power in °C:W (optional)'
                                                         , order => 5
                                                         }
                                                       , { name => 'duration'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Duration of temperature application in seconds (optional)'
                                                         , order => 6
                                                         }
                                                       , { name => 'monitor'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Duration in seconds to monitor temperature after shutdown (optional)'
                                                         , order => 7
                                                         }
                                                       , { name => 'unsafe'
                                                         , type => 'boolean'
                                                         , required => 0
                                                         , description => 'Disable safety limits (optional)'
                                                         , order => 8
                                                         }
                                                       , $PARAM_DEVICE
                                                       ]
                                       }
                                     , { name => 'rth'
                                       , description => 'Estimate the thermal resistance of a thermal assembly'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , { name => 'length'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Length of the assembly under test in mm'
                                                         , order => 1
                                                         }
                                                       , { name => 'width'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Width of the assembly under test in mm'
                                                         , order => 2
                                                         }
                                                      , { name => 'mass'
                                                        , type => 'number'
                                                        , required => 0
                                                        , description => 'Mass of the heat sink under test in grams'
                                                        , order => 3
                                                        }
                                                       ]
                                       }
                                     , { name => 'rthcal'
                                       , description => 'Calibrate thermal resistance measurement'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , { name => 'length'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Length of the hotplate in mm'
                                                         , order => 1
                                                         }
                                                       , { name => 'width'
                                                         , type => 'number'
                                                         , required => 1
                                                         , description => 'Width of the hotplate in mm'
                                                         , order => 2
                                                         }
                                                       , { name => 'test-delta-T'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Temperature difference between ambient and the assembly under test in °C'
                                                         , order => 3
                                                         }
                                                       , { name => 'preheat-time'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Preheat time in seconds'
                                                         , order => 4
                                                         }
                                                       , { name => 'soak-time'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Soak time in seconds'
                                                         , order => 5
                                                         }
                                                       , { name => 'measure-time'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Measure time in seconds'
                                                         , order => 6
                                                         }
                                                       , { name => 'sample-time'
                                                         , type => 'number'
                                                         , required => 0
                                                         , description => 'Sample time in seconds'
                                                         , order => 7
                                                         }
                                                       ]
                                       }
                                     ]
                                   }
              )
   };
  
  # Get command parameter schema
  get '/api/commands/:name' => sub {
    my $c = shift;
    my $command_name = $c->param('name');

    # For now, return a simple schema
    $c->render(json => { name => $command_name
                       , description => "Execute $command_name command"
                       , parameters => { } # This will be populated dynamically later
                       }
              );
  };
  
  # Execute command
  post '/api/commands/:name' => sub {
    my $c = shift;
    my $command_name = $c->param('name');
    my $params = $c->req->json;

    my $method = 'execute'. ucfirst($command_name);

    if ($command_executor->can($method)) {
      eval {
        $command_executor->$method($params->{parameters});
        $c->render(json => { status => 'success'
                           , message => "$command_name command started"
                           }
                  );
      } or do {
        $c->render(json => { status => 'error'
                           , message => $@
                           , status => 400
                           });
      }
    } else {
      $c->render(json => { status => 'error'
                         , message => "Unknown command: $command_name"
                         , status => 400
                         }
              );
    }
  };
  
  # Stop current command
  del '/api/commands/current' => sub {
    my $c = shift;
    eval {
      $command_executor->stopCommand();
      $c->render(json => { status => 'success'
                         , message => 'Command stopped'
                         }
                );
    } or do {
      $c->render(json => { status => 'error'
                         , message => $@
                         }
                , status => 400);
    };
  };
 
  # Get system status
  get '/api/status' => sub {
    my $c = shift;
    my $status = $command_executor->getStatus();
    $c->render(json => $status);
  };
  
  # Get available devices
  get '/api/devices' => sub {
    my $c = shift;
    my @devices = get_device_names();
    $c->render(json => { list => \@devices });
  };
  
  # Get available log files for replay
  get '/api/logfiles' => sub {
    my $c = shift;
    my @logfiles = $command_executor->getLogFiles();
    $c->render(json => { logfiles => \@logfiles });
  };

  get '/api/linear/profiles' => sub {
    my $c = shift;
    my @profiles = find_linear_profiles();
    $c->render(json => { list => \@profiles });
  };

  get '/api/reflow/profiles' => sub {
    my $c = shift;
    my @profiles = find_reflow_profiles();
    $c->render(json => { list => \@profiles });
  };

  # WebSocket endpoints
  websocket '/ws/data' => sub {
    my $c = shift;
    $c->inactivity_timeout(600);
    my $ws = $c->tx;
    
    $c->app->log->info('WebSocket data connection established from ' . $ws->remote_address);

    # Controller's reference to WebSocket is weak. Need to store it somewhere to ensure it doesn't get closed by garbage collection.
    # And we need it for sending messages to the client, anyway!
    $command_executor->addWebSocket($ws);
    
    # Handle incoming messages (ping/pong)
    $c->on(message => sub { my ($c, $msg) = @_;
                            my $data = Mojo::JSON::decode_json($msg);
                            if ($data->{type} eq 'ping') {
                              $c->send(Mojo::JSON::encode_json({ type => 'pong' }));
                            } else {
                              $command_executor->receiveMessage($c->tx, $data);
                            }
                          }
          );
    
    # Handle connection close
    $c->on(finish => sub { my ($c, $code, $reason) = @_;
                           $c->app->log->info("WebSocket data connection closed");

                           $command_executor->removeWebSocket($c->tx);
                         }
          );
  };
};

# Start the application
app->start; 
