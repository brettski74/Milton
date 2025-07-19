#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

use Mojolicious::Lite;

# Enable debug mode for development
app->log->level('debug');

# Serve static files from public directory
app->static->paths->[0] = app->home->child('public');

# Basic routes
get '/' => sub { my $c = shift;
                 $c->render('index');
               };

# API endpoints
group {
  # API routes go here
  
  # List available commands
  get '/api/commands' => sub { my $c = shift;
                               $c->render(json => { commands => [ { name => 'reflow'
                                                                  , description => 'Execute reflow profile'
                                                                  , parameters => { profile => { type => 'string'
                                                                                               , required => 1
                                                                                               , description => 'Profile name to execute'
                                                                                               }
                                                                                  }
                                                                  }
                                                                , { name => 'calibrate'
                                                                  , description => 'Calibrate temperature sensor'
                                                                  , parameters => { device => { type => 'string'
                                                                                             , required => 1
                                                                                             , description => 'External temperature sensor to use for calibration'
                                                                                             }
                                                                                  }
                                                                  }
                                                                , { name => 'power'
                                                                  , description => 'Set power output'
                                                                  , parameters => { power => { type => 'number'
                                                                                             , required => 1
                                                                                             , description => 'Power output in watts'
                                                                                             }
                                                                                  }
                                                                  }
                                                                ]
                                                              }
                                         )
                              };
  
  # Get command parameter schema
  get '/api/commands/:name' => sub { my $c = shift;
                                     my $command_name = $c->param('name');
    
                                     # For now, return a simple schema
                                     $c->render(json => { name => $command_name
                                                        , description => "Execute $command_name command"
                                                        , parameters => { } # This will be populated dynamically later
                                                        }
                                               );
                                   };
  
  # Execute command
  post '/api/commands/:name' => sub { my $c = shift;
                                      my $command_name = $c->param('name');
                                      my $params = $c->req->json;
    
                                      # For now, just return success
                                      $c->render(json => { status => 'success'
                                                         , message => "Command $command_name started"
                                                         , command_id => '12345'
                                                         }
                                                );
                                    };
  
  # Stop current command
  del '/api/commands/current' => sub { my $c = shift;
                                        $c->render(json => { status => 'success'
                                                           , message => 'Command stopped'
                                                           }
                                                 );
                                     };
 
  # Get system status
  get '/api/status' => sub { my $c = shift;
                             $c->render(json => { status => 'idle'
                                                , current_command => undef
                                                , uptime => time()
                                                , temperature => { heating_element => undef
                                                                 , hotplate => undef
                                                                 , device => undef
                                                                 }
                                                , power_output => 0.0
                                                }
                                       );
                           };

# WebSocket endpoints
websocket '/ws/data' => sub { my $c = shift;
  
                              $c->app->log->info('WebSocket data connection established');
  
                              # Send initial data
                              $c->send({ type => 'status'
                                       , data => { status => 'idle'
                                                 , timestamp => time()
                                                 }
                                       }
                                      );
  
                              # Handle incoming messages
                              $c->on(message => sub { my ($c, $message) = @_;
                                                      $c->app->log->info("Received message: $message");
                                                    }
                                    );
  
                              # Handle connection close
                              $c->on(finish => sub { my ($c, $code, $reason) = @_;
                                                     $c->app->log->info("WebSocket data connection closed");
                                                   }
                                    );
                            };

websocket '/ws/console' => sub { my $c = shift;
  
                                 $c->app->log->info('WebSocket console connection established');
  
                                 # Send initial console data
                                 $c->send({ type => 'console'
                                          , data => { message => 'Web interface connected'
                                                    , level => 'info'
                                                    , timestamp => time()
                                                    }
                                          }
                                         );
  
                              # Handle connection close
                              $c->on(finish => sub { my ($c, $code, $reason) = @_;
                                                     $c->app->log->info("WebSocket console connection closed");
                                                   }
                                    );
                            };
};

# Start the application
app->start; 