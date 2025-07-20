#!/usr/bin/perl

use strict;
use warnings qw(all -uninitialized);

# Make sure that we can find our libraries.
BEGIN {
  my $path = __FILE__;
  $path =~ s/\/[^\/]*$/lib/;
  unshift @INC, $path;
}

use Mojolicious::Lite;
use PSCWebUI::CommandExecutor;

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
my $command_executor = PSCWebUI::CommandExecutor->new();

# Global list of active WebSocket connections
my @active_websockets = ();

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
                                                                  , parameters => { device => { type => 'string'
                                                                                               , required => 0
                                                                                               , description => 'Device to use (optional)'
                                                                                               }
                                                                                  }
                                                                  }
                                                                , { name => 'replay'
                                                                  , description => 'Replay log file for testing'
                                                                  , parameters => { file => { type => 'string'
                                                                                             , required => 1
                                                                                             , description => 'Log file to replay'
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
    
                                      if ($command_name eq 'reflow') {
                                        my $device_name = $params->{parameters}->{device};
                                        
                                        eval {
                                          $command_executor->execute_reflow($device_name);
                                          start_command_timers_for_all();
                                          $c->render(json => { status => 'success'
                                                             , message => "Reflow command started"
                                                             }
                                                    );
                                        } or do {
                                          $c->render(json => { status => 'error'
                                                             , message => $@
                                                             }
                                                    , status => 400);
                                        };
                                      } elsif ($command_name eq 'replay') {
                                        my $file_name = $params->{parameters}->{file};
                                        
                                        eval {
                                          $command_executor->execute_replay($file_name);
                                          start_command_timers_for_all();
                                          $c->render(json => { status => 'success'
                                                             , message => "Replay command started"
                                                             }
                                                    );
                                        } or do {
                                          $c->render(json => { status => 'error'
                                                             , message => $@
                                                             }
                                                    , status => 400);
                                        };
                                      } else {
                                        $c->render(json => { status => 'error'
                                                           , message => "Unknown command: $command_name"
                                                           }
                                                  , status => 400);
                                      }
                                    };
  
  # Stop current command
  del '/api/commands/current' => sub { my $c = shift;
                                        eval {
                                          $command_executor->stop_command();
                                          stop_command_timers_for_all();
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
  get '/api/status' => sub { my $c = shift;
                             my $status = $command_executor->get_status();
                             $c->render(json => $status);
                           };
  
  # Get available devices
  get '/api/devices' => sub { my $c = shift;
                              my @devices = $command_executor->discover_devices();
                              $c->render(json => { devices => \@devices });
                            };
  
  # Get available log files for replay
  get '/api/logfiles' => sub { my $c = shift;
                               my @logfiles = $command_executor->get_log_files();
                               $c->render(json => { logfiles => \@logfiles });
                             };

# WebSocket endpoints
websocket '/ws/data' => sub { my $c = shift;
  
                              $c->app->log->info('WebSocket data connection established');
  
                                                            # Send initial status
                              my $status = $command_executor->get_status();
                              my $status_msg = { type => 'status'
                                              , data => $status
                                              };
                              my $json = Mojo::JSON::encode_json($status_msg);
                              $c->app->log->debug("Sending initial status WebSocket message: $json");
                              $c->send($json);

                              # Store timer reference for this connection
                              $c->stash->{data_timer} = undef;
  
                              # Add to active connections list
                              push @active_websockets, $c;
                              
                              # Handle incoming messages (ping/pong)
                              $c->on(message => sub { my ($c, $msg) = @_;
                                                      my $data = Mojo::JSON::decode_json($msg);
                                                      if ($data->{type} eq 'ping') {
                                                        $c->send(Mojo::JSON::encode_json({ type => 'pong' }));
                                                      }
                                                    }
                                    );
                              
                              # Handle connection close
                              $c->on(finish => sub { my ($c, $code, $reason) = @_;
                                                     $c->app->log->info("WebSocket data connection closed");
                                                     if ($c->stash->{data_timer}) {
                                                       Mojo::IOLoop->remove($c->stash->{data_timer});
                                                     }
                                                     # Remove from active connections list
                                                     @active_websockets = grep { $_ != $c } @active_websockets;
                                                   }
                                    );
                            };

websocket '/ws/console' => sub { my $c = shift;
  
                                 $c->app->log->info('WebSocket console connection established');
  
                                                                  # Send initial console data
                                 my $console_msg = { type => 'console'
                                                  , data => { message => 'Web interface connected'
                                                            , level => 'info'
                                                            , timestamp => time()
                                                            }
                                                  };
                                 my $json = Mojo::JSON::encode_json($console_msg);
                                 $c->app->log->debug("Sending initial console WebSocket message: $json");
                                 $c->send($json);

                                 # Store timer reference for this connection
                                 $c->stash->{console_timer} = undef;
  
                                 # Add to active connections list
                                 push @active_websockets, $c;
                                 
                                 # Handle incoming messages (ping/pong)
                                 $c->on(message => sub { my ($c, $msg) = @_;
                                                         my $data = Mojo::JSON::decode_json($msg);
                                                         if ($data->{type} eq 'ping') {
                                                           $c->send(Mojo::JSON::encode_json({ type => 'pong' }));
                                                         }
                                                       }
                                       );
                                 
                                 # Handle connection close
                                 $c->on(finish => sub { my ($c, $code, $reason) = @_;
                                                        $c->app->log->info("WebSocket console connection closed");
                                                        if ($c->stash->{console_timer}) {
                                                          Mojo::IOLoop->remove($c->stash->{console_timer});
                                                        }
                                                        # Remove from active connections list
                                                        @active_websockets = grep { $_ != $c } @active_websockets;
                                                      }
                                       );
                            };
};

# Timer management functions
sub start_command_timers_for_all {
  foreach my $c (@active_websockets) {
    start_command_timers($c);
  }
}

sub stop_command_timers_for_all {
  foreach my $c (@active_websockets) {
    stop_command_timers($c);
  }
}

sub start_command_timers {
  my ($c) = @_;
  
  # Track if we've already sent the command finished message
  $c->stash->{command_finished_sent} = 0;
  
  # Start data timer
  $c->stash->{data_timer} = Mojo::IOLoop->recurring(0.1 => sub {
    $c->app->log->debug("Data WebSocket timer tick - checking for output");
    my $output = $command_executor->read_output();
    if ($output) {
      $c->app->log->debug("Data WebSocket received output: " . $output->{type});
      
      # Send data and header messages to data WebSocket
      if ($output->{type} eq 'data' || $output->{type} eq 'header') {
        my $json = Mojo::JSON::encode_json($output);
        $c->app->log->debug("Sending data WebSocket message: $json");
        $c->send($json);
      }
      
      # Also send status updates when we get new data
      if ($output->{type} eq 'data') {
        my $status = $command_executor->get_status();
        my $status_msg = { type => 'status'
                        , data => $status
                        };
        my $json = Mojo::JSON::encode_json($status_msg);
        $c->app->log->debug("Sending status WebSocket message: $json");
        $c->send($json);
      }
    } else {
      # Check if command has finished
      my $status = $command_executor->get_status();
      if ($status->{status} eq 'idle' && $status->{current_command} eq undef && !$c->stash->{command_finished_sent}) {
        $c->app->log->info("Command finished, sending final status update and stopping timer");
        # Command finished, send final status update
        my $status_msg = { type => 'status'
                        , data => $status
                        };
        my $json = Mojo::JSON::encode_json($status_msg);
        $c->app->log->debug("Sending final status WebSocket message: $json");
        $c->send($json);
        
        # Mark as finished to prevent duplicate messages
        $c->stash->{command_finished_sent} = 1;
        
        # Stop timers
        stop_command_timers($c);
      }
    }
  });
  
  # Start console timer
  $c->stash->{console_timer} = Mojo::IOLoop->recurring(0.1 => sub {
    $c->app->log->debug("Console WebSocket timer tick - checking for output");
    my $output = $command_executor->read_output();
    if ($output && $output->{type} eq 'console') {
      $c->app->log->debug("Console WebSocket received: " . $output->{data}->{message});
      my $json = Mojo::JSON::encode_json($output);
      $c->app->log->debug("Sending console WebSocket message: $json");
      $c->send($json);
    } else {
      # Check if command has finished
      my $status = $command_executor->get_status();
      if ($status->{status} eq 'idle' && $status->{current_command} eq undef && !$c->stash->{command_finished_sent}) {
        $c->app->log->info("Command finished, sending console message and stopping timer");
        # Command finished, send console message
        my $console_msg = { type => 'console'
                         , data => { message => 'Command finished'
                                   , level => 'info'
                                   , timestamp => time()
                                   }
                         };
        my $json = Mojo::JSON::encode_json($console_msg);
        $c->app->log->debug("Sending command finished console message: $json");
        $c->send($json);
        
        # Mark as finished to prevent duplicate messages
        $c->stash->{command_finished_sent} = 1;
        
        # Stop timers
        stop_command_timers($c);
      }
    }
  });
  
  $c->app->log->info("Command timers started");
}

sub stop_command_timers {
  my ($c) = @_;
  
  # Stop data timer
  if ($c->stash->{data_timer}) {
    Mojo::IOLoop->remove($c->stash->{data_timer});
    $c->stash->{data_timer} = undef;
    $c->app->log->info("Data timer stopped");
  }
  
  # Stop console timer
  if ($c->stash->{console_timer}) {
    Mojo::IOLoop->remove($c->stash->{console_timer});
    $c->stash->{console_timer} = undef;
    $c->app->log->info("Console timer stopped");
  }
  
  # Reset command finished flag
  $c->stash->{command_finished_sent} = 0;
}

# Start the application
app->start; 