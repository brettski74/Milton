# Hotplate Controller Web Interface Design

## Overview

This document outlines the design for a web-based interface to the hotplate controller system. The interface will leverage the existing command-line architecture while providing a modern, responsive web UI for controlling the system and monitoring real-time data.

## Architecture Principles

1. **Reuse Existing Components**: Leverage existing `Command`, `DataLogger`, and `EventLoop` classes
2. **Common Interface**: Build around a common interface usable by both web and command-line
3. **Real-time Communication**: WebSocket-based data streaming for live monitoring
4. **Single Command Execution**: Only one command can run at a time
5. **Clean Shutdown**: Support for stopping running commands gracefully
6. **Process Separation**: Fork child processes to run commands, avoiding event loop conflicts
7. **Unified Logging**: Extend DataLogger to support debug, info, and warning messages across all components

## Backend Architecture

### Directory Structure
```
webui/
├── DESIGN.md                   # This design document
├── lib/
│   ├── PSCWebUI.pm             # Main web application
│   ├── Controller/
│   │   ├── API.pm              # REST API endpoints
│   │   ├── WebSocket.pm        # Real-time data streaming
│   │   └── CommandExecutor.pm  # Command execution interface
│   ├── Model/
│   │   ├── CommandRegistry.pm  # Available commands discovery
│   │   ├── WebDataLogger.pm    # WebSocket-enabled DataLogger
│   │   └── WebEventLoop.pm     # Web-aware EventLoop wrapper
│   └── View/
│       └── JSON.pm             # JSON response formatting
├── public/                     # Static assets (JS, CSS, images)
├── templates/                  # HTML templates
└── t/                         # Unit tests
```

### Core Components

#### 1. PSCWebUI.pm
- Main Mojolicious application
- Routes configuration
- WebSocket setup
- Integration with existing PowerSupplyControl modules

#### 2. CommandExecutor.pm
- Manages command lifecycle (start, stop, status)
- Forks child processes to run existing command-line scripts
- Parses prefixed output (DEBUG:, INFO:, WARN:, CSV:)
- Manages single-command-at-a-time constraint
- Uses signal-based shutdown (TERM, INT, QUIT)

#### 3. WebDataLogger.pm
- Extends existing DataLogger with debug/info/warning support
- Streams data to WebSocket clients
- Maintains data buffering for new connections
- Formats data for JSON transmission
- Provides unified logging interface for Controller, Interface, and Device classes

#### 4. WebEventLoop.pm
- Wraps existing EventLoop for web context
- Provides web-friendly shutdown mechanisms
- Integrates with WebSocket for real-time updates
- Note: Child processes use existing AnyEvent+EV event loop

## API Design

### REST Endpoints

```
GET  /api/commands              # List available commands with metadata
GET  /api/commands/{name}       # Get command parameter schema
POST /api/commands/{name}       # Execute command with parameters
GET  /api/status                # Current system status
DELETE /api/commands/current    # Stop running command
GET  /api/data/history          # Recent historical data
```

### WebSocket Endpoints

```
/ws/data                        # Real-time temperature/power data
/ws/status                      # System status updates
/ws/console                     # Command output/logging
```

### Data Formats

#### Command List Response
```json
{
  "commands": [
    {
      "name": "reflow",
      "description": "Execute reflow profile",
      "parameters": {
        "profile": {
          "type": "string",
          "required": true,
          "description": "Profile name to execute"
        },
        "max_temp": {
          "type": "number",
          "required": false,
          "default": 250,
          "description": "Maximum temperature in Celsius"
        }
      }
    }
  ]
}
```

#### Command Execution Request
```json
{
  "parameters": {
    "profile": "lead-free",
    "max_temp": 245
  }
}
```

#### Real-time Data Stream
```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "data": {
    "heating_element_temp": 245.6,
    "hotplate_temp": 238.2,
    "power_output": 85.3,
    "setpoint": 250.0
  }
}
```

## Frontend Architecture

### Technology Stack
- **Framework**: React with TypeScript
- **State Management**: Zustand (lightweight, simple)
- **Charts**: Chart.js with real-time plugin
- **Styling**: Tailwind CSS
- **Build Tool**: Vite

### Component Structure
```
src/
├── components/
│   ├── CommandMenu/
│   │   ├── CommandList.tsx     # Available commands
│   │   └── CommandForm.tsx     # Parameter input
│   ├── Monitoring/
│   │   ├── RealTimeChart.tsx   # Temperature/power graphs
│   │   ├── StatusPanel.tsx     # System status
│   │   └── ConsolePanel.tsx    # Command output
│   └── Controls/
│       ├── ExecuteButton.tsx   # Start command
│       └── StopButton.tsx      # Stop command
├── services/
│   ├── api.ts                  # REST API client
│   ├── websocket.ts            # WebSocket management
│   └── commandRegistry.ts      # Command definitions
├── store/
│   ├── commandStore.ts         # Command state
│   ├── dataStore.ts            # Real-time data
│   └── statusStore.ts          # System status
└── types/
    └── api.ts                  # TypeScript definitions
```

## Integration with Existing Code

### Command Class Integration
- Run existing command-line scripts (psc.pl) in forked processes
- Leverage existing `info()` and `debug()` methods for console output
- Reuse command execution logic unchanged
- Add output prefixing for web interface parsing

### DataLogger Integration
- Extend existing DataLogger with debug/info/warning message support
- Provide unified logging interface for Controller, Interface, and Device classes
- Maintain existing file logging functionality
- Add output prefixing for web interface parsing

### EventLoop Integration
- Wrap existing EventLoop for web context
- Integrate with WebSocket for real-time status updates
- Child processes use existing AnyEvent+EV event loop
- Maintain existing signal handling for command-line compatibility

## Data Flow

### Command Execution Flow
1. User selects command and enters parameters
2. Frontend sends POST request to `/api/commands/{name}`
3. Backend validates parameters and forks child process
4. Child process runs existing command-line script (psc.pl)
5. Parent process parses prefixed output (DEBUG:, INFO:, WARN:, CSV:)
6. Parsed data streams to WebSocket clients
7. User can stop command via DELETE request (sends TERM signal)

### Real-time Data Flow
1. Child process runs existing command-line script
2. Script output includes prefixed messages (DEBUG:, INFO:, WARN:, CSV:)
3. Parent process parses output and formats as JSON
4. Data broadcast to all connected WebSocket clients
5. Frontend updates charts and status displays
6. Data also logged to files (existing functionality)

## Security Considerations

### Input Validation
- Parameter validation via command-line argument parsing
- JSON schema validation for API requests
- Rate limiting: one command at a time

### Network Security
- No authentication required (trusted network only)
- Input sanitization for all user inputs
- CORS configuration for local development

## Implementation Phases

### Phase 1: Basic Web Framework
- [ ] Set up Mojolicious application structure
- [ ] Create basic API endpoints for command listing
- [ ] Implement command parameter schema discovery
- [ ] Basic frontend with command selection

### Phase 2: Command Integration
- [ ] Implement CommandExecutor with process forking
- [ ] Extend DataLogger with debug/info/warning support
- [ ] Add output prefixing to existing scripts
- [ ] Command execution API endpoints
- [ ] Frontend command forms

### Phase 3: Real-time Data
- [ ] Implement output parsing (DEBUG:, INFO:, WARN:, CSV:)
- [ ] WebSocket data streaming
- [ ] Real-time charts in frontend
- [ ] Console output streaming

### Phase 4: Command Control
- [ ] Signal-based command stopping (TERM, INT, QUIT)
- [ ] Status monitoring
- [ ] Error handling and recovery
- [ ] Command history

### Phase 5: Polish & Testing
- [ ] Error handling improvements
- [ ] Mobile responsiveness
- [ ] Performance optimization
- [ ] Comprehensive testing

## Technical Decisions

### WebSocket vs Server-Sent Events
- **Chosen**: WebSocket
- **Reason**: Bidirectional communication needed for command control

### JSON vs Binary Protocol
- **Chosen**: JSON
- **Reason**: Low data volume (1.5s updates), easier debugging

### State Management
- **Chosen**: Zustand
- **Reason**: Lightweight, simple API, good TypeScript support

### Chart Library
- **Chosen**: Chart.js
- **Reason**: Good real-time support, extensive documentation

### Process Management
- **Chosen**: Fork child processes
- **Reason**: Avoids event loop conflicts, leverages existing command-line scripts

### Backend Framework
- **Chosen**: Mojolicious
- **Reason**: Excellent Perl web framework, native WebSocket support, familiar language

## Questions for Refinement

1. **Data Retention**: How much historical data should be buffered for new WebSocket connections?

2. **Error Handling**: Should failed commands be retryable, or require manual restart?

3. **Mobile Support**: What level of mobile responsiveness is required?

4. **Offline Support**: Should the interface work when disconnected from the controller?

5. **Configuration**: Should web interface settings be configurable via the existing config system? 