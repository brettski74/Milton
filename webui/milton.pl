#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Milton::Config::Utils qw(getReflowProfiles getDeviceNames);

# Make sure that we can find our libraries.
BEGIN {
  my $path = __FILE__;
  $path =~ s/\/[^\/]*$/\/lib/;
  unshift @INC, $path;
}

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

# Configure WebSocket settings
# Can't locate object method "websocket_timeout" via package "Mojolicious::Lite" at webui/web_server.pl line 28.
# app->websocket_timeout(300);  # 5 minutes WebSocket timeout

# Create command executor
my $command_executor = MiltonUI::CommandExecutor->new();

# Serve static files from shared/public directories (user/local/system) with app-local as fallback
app->static->paths([
  $ENV{HOME} . '/share/psc/webui/public',
  '/usr/local/share/psc/webui/public',
  '/usr/share/psc/webui/public',
  app->home->child('public'),
]);

# Template search paths (user/local/system) with app-local as fallback
app->renderer->paths([
  $ENV{HOME} . '/share/psc/webui/templates',
  '/usr/local/share/psc/webui/templates',
  '/usr/share/psc/webui/templates',
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
                                                       , { name => 'r0'
                                                         , type => 'text'
                                                         , required => 0
                                                         , description => 'Cold resistance:temperature in Ω or mΩ and °C (optional)'
                                                         }
                                                       , $PARAM_AMBIENT
                                                       , { name => 'resetCalibration'
                                                         , type => 'boolean'
                                                         , required => 0
                                                         , description => 'Treat as new hotplate PCB'
                                                         }
                                                       ]
                                       }
                                     , { name => 'reflow'
                                       , description => 'Execute reflow profile'
                                       , parameters => [ $PARAM_PROFILE
                                                       , $PARAM_AMBIENT
                                                       , $PARAM_DEVICE
                                                       , { name => 'tune'
                                                         , type => 'text'
                                                         , required => 0
                                                         , description => 'If specified, tunes the temperature prediction and saves to the specified file name (optional)'
                                                         }
                                                       ]
                                       }
                                     , { name => 'setup'
                                       , description => 'Set up a new hotplate PCB'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , $PARAM_PROFILE
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
                                     , { name => 'tune'
                                       , description => 'Tune a Hybrid PI controller'
                                       , parameters => [ $PARAM_AMBIENT
                                                       , $PARAM_DEVICE
                                                       , $PARAM_PROFILE
                                                       , { name => 'predictor-calibration'
                                                         , type => 'text'
                                                         , required => 1
                                                         , description => 'The name of the file where the predictor calibration data will be written'
                                                         , default => $command_executor->getConfigPath('controller', 'predictor')
                                                         }
                                                       , { name => 'controller-calibration'
                                                         , type => 'text'
                                                         , required => 0
                                                         , description => 'The name of the file where the controller calibration data will be written'
                                                         , default => $command_executor->getConfigPath('controller')
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

    print "command params: ". join(', ', %$params) ."\n";

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
    my @devices = getDeviceNames();
    $c->render(json => { list => \@devices });
  };
  
  # Get available log files for replay
  get '/api/logfiles' => sub {
    my $c = shift;
    my @logfiles = $command_executor->getLogFiles();
    $c->render(json => { logfiles => \@logfiles });
  };

  get '/api/reflow/profiles' => sub {
    my $c = shift;
    my @profiles = getReflowProfiles();
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
