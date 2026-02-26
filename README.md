# OraFlow 🚀

<p align="center">
  <img src="https://img.shields.io/badge/Version-Phase_4Complete-brightgreen?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/Platform-Flutter_Desktop-blue?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Author-Abduljabbar_Abdulghani-red?style=for-the-badge" alt="Author">
</p>

<p align="center">
  <em>Built with ❤️ by <a href="https://github.com/AbduljabbarBXR">Abduljabbar Abdulghani</a></em>
</p>

---

## 📖 Table of Contents

- [Introduction](#-introduction)
- [Features](#-features)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Running the App](#running-the-app)
- [Components](#-components)
  - [Flutter Desktop App](#flutter-desktop-app)
  - [VS Code Extension](#vs-code-extension)
  - [MCP Servers](#mcp-servers)
- [How It Works](#-how-it-works)
- [Phases of Development](#-phases-of-development)
- [Configuration](#-configuration)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Acknowledgments](#-acknowledgments)

---

## 🎯 Introduction

**OraFlow** is an intelligent developer productivity suite that combines a powerful Flutter desktop application with a seamless VS Code extension. Designed to enhance your coding workflow, OraFlow provides real-time error detection, AI-powered code analysis, and intelligent fix suggestions—all within a modern, spaceship cockpit-style interface.

Born from a vision to streamline developer workflows, OraFlow bridges the gap between your IDE and a smart assistant that helps you write better code, faster. Whether you're debugging complex issues or exploring code relationships, OraFlow is your trusted companion.

---

## ✨ Features

### Core Features

| Feature | Description |
|---------|-------------|
| **WebSocket Communication** | Real-time bidirectional communication between Flutter desktop app and VS Code |
| **Automatic Error Detection** | Monitors code in real-time and detects errors as you type |
| **AI Code Analysis** | Intelligent analysis powered by AI to understand code context and suggest improvements |
| **One-Click Fixes** | Apply AI-generated code fixes with a single click |
| **Knowledge Graph** | Visual representation of code relationships and dependencies |
| **Health Monitor** | System resource monitoring to ensure optimal performance |
| **Activity Log** | Comprehensive logging of all operations and events |
| **Resource Guard** | Automatic RAM monitoring with cloud AI fallback for low-resource machines |

### Additional Features

- **Custom Title Bar**: Spaceship cockpit-inspired UI design
- **File Inspector**: Detailed file analysis and inspection
- **Semantic Analyzer**: Deep code semantic understanding
- **Status Bar**: Real-time connection and system status
- **Error Badges**: Visual indicators for code issues
- **Dashboard**: Central hub for all OraFlow activities

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        OraFlow System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────────────────┐  │
│  │  Flutter Desktop │◄───────►│     WebSocket Server         │  │
│  │      App         │  WS     │    (localhost:6543)         │  │
│  └──────────────────┘         └──────────────┬───────────────┘  │
│                                              │                   │
│  ┌──────────────────┐                        │                   │
│  │  VS Code         │◄──────────────────────┘                   │
│  │  Extension       │                                            │
│  │  (oraflow_bridge)│                                            │
│  └──────────────────┘                                            │
│                                                                  │
│  ┌──────────────────┐                                            │
│  │  MCP Servers     │◄──── Optional ADB Bridge                  │
│  │  (adb_bridge)    │                                            │
│  └──────────────────┘                                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Desktop App | Flutter | 3.0+ |
| Extension | TypeScript | 4.x |
| Runtime | Node.js | 16+ |
| Communication | WebSocket | RFC 6455 |
| UI Framework | Material Design | 3.0 |

---

## 📂 Project Structure

```
ORAFLOW/
├── README.md                    # This file
├── flutter/                     # Flutter SDK (submodule)
│   ├── bin/
│   ├── packages/
│   └── ...
│
├── oraflow_desktop/             # Main Flutter Desktop Application
│   ├── lib/
│   │   ├── main.dart           # Entry point
│   │   ├── screens/            # Screen widgets
│   │   │   └── dashboard.dart  # Main dashboard
│   │   ├── services/           # Business logic services
│   │   │   ├── bridge_service.dart        # WebSocket client
│   │   │   ├── scanner_service.dart       # Code scanner
│   │   │   ├── semantic_analyzer_service.dart
│   │   │   └── resource_guard_service.dart
│   │   └── widgets/            # Reusable UI components
│   │       ├── knowledge_graph_view.dart
│   │       ├── health_monitor.dart
│   │       ├── file_inspector.dart
│   │       ├── status_bar.dart
│   │       ├── activity_log.dart
│   │       └── error_badge.dart
│   ├── pubspec.yaml            # Dependencies
│   └── build/                  # Build outputs
│
├── oraflow_bridge/             # VS Code Extension
│   ├── src/
│   │   ├── extension.ts        # Main extension logic
│   │   └── preview_handler.ts  # Preview handling
│   ├── package.json            # Extension metadata
│   └── .vscode/                # VS Code config
│
└── mcp_servers/                # MCP Server Implementations
    ├── adb_bridge.py           # ADB bridge server
    ├── requirements.txt        # Python dependencies
    └── setup_adb_bridge.bat    # Setup script
```

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

| Requirement | Minimum Version | Recommended Version |
|-------------|-----------------|---------------------|
| Flutter SDK | 3.0+ | Latest stable |
| VS Code | 1.70+ | Latest |
| Node.js | 16+ | 20 LTS |
| npm | 8+ | Latest |
| Git | 2.30+ | Latest |

#### Installing Flutter

1. Download Flutter from [flutter.dev](https://flutter.dev)
2. Extract the archive to your preferred location
3. Add Flutter to your system PATH
4. Run `flutter doctor` to verify installation

#### Enabling Desktop Support

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/AbduljabbarBXR/Oraflow.git
cd Oraflow
```

#### 2. Initialize Git (if not already initialized)

```bash
git remote add origin https://github.com/AbduljabbarBXR/Oraflow.git
git branch -M main
```

#### 3. Setup Flutter Desktop App

```bash
cd oraflow_desktop

# Install dependencies
flutter pub get

# Build for desktop
flutter build windows
```

#### 4. Setup VS Code Extension

```bash
cd oraflow_bridge

# Install Node.js dependencies
npm install

# Compile TypeScript
npm run compile
```

### Running the App

#### Running the Flutter Desktop App

```bash
cd oraflow_desktop
flutter run -d windows
```

Or for development with hot reload:

```bash
flutter run -d windows --debug
```

#### Running the VS Code Extension

1. Open the `oraflow_bridge` folder in VS Code
2. Press `F5` to launch the extension debugger
3. The extension will connect to the running Flutter app

---

## 🔌 Components

### Flutter Desktop App

The main OraFlow application built with Flutter, featuring:

- **Custom Window Manager**: Frameless window with custom title bar
- **WebSocket Server**: Built-in Dart HttpServer on port 6543
- **Service Layer**: Modular services for different functionalities
- **Widget Library**: Reusable UI components

#### Key Services

| Service | Purpose |
|---------|---------|
| `BridgeService` | Manages WebSocket connections |
| `ScannerService` | Scans and analyzes code files |
| `SemanticAnalyzerService` | Performs deep code analysis |
| `ResourceGuardService` | Monitors and manages system resources |

### VS Code Extension

The VS Code extension (`oraflow_bridge`) provides:

- Automatic WebSocket connection to the Flutter app
- Real-time error detection and display
- Code fix suggestions with diff preview
- One application
- Status-click fix notifications in VS Code

#### Extension Commands

| Command | Description |
|---------|-------------|
| `oraflow.connect` | Connect to OraFlow |
| `oraflow.disconnect` | Disconnect from OraFlow |
|.an `oraflowalyze` | Trigger code analysis |
| `oraflow.applyFix` | Apply suggested fix |

### MCP Servers

Model Context Protocol (MCP) server implementations for extended functionality:

- **ADB Bridge**: Android Debug Bridge integration for mobile development

---

## 🔄 How It Works

### Phase 1: WebSocket Heartbeat

1. **Flutter App** starts a WebSocket server on `localhost:6543`
2. **VS Code Extension** automatically connects to the WebSocket server
3. **Connection Status** shows "OraFlow Connected ⚡" notification
4. **Test Button** sends a ping/pong to verify communication

### Phase 2: Shadow Terminal

1. **Background Scanner** monitors code changes
2. **Error Detection** identifies issues in real-time
3. **Shadow Log** displays detected errors with details

### Phase 3: Agent Logic

1. **AI Analysis** sends code to CTO Agent for analysis
2. **Fix Suggestions** provides code diff (OLD/NEW)
3. **One-Click Apply** applies fixes directly to VS Code

### Phase 4: Full UI

1. **Knowledge Graph** visualizes code relationships
2. **Health Monitor** tracks system performance
3. **Dashboard** provides comprehensive overview

---

## 📋 Phases of Development

| Phase | Status | Features |
|-------|--------|----------|
| Phase 1: WebSocket Heartbeat | ✅ Complete | Basic WebSocket communication |
| Phase 2: Shadow Terminal | ✅ Complete | Error detection and logging |
| Phase 3: Agent Logic | ✅ Complete | AI analysis and fix suggestions |
| Phase 4: Full UI | ✅ Complete | Knowledge graph, health monitor, dashboard |

---

## ⚙️ Configuration

### Flutter Configuration

The desktop app can be configured via `oraflow_config.json`:

```json
{
  "websocket_port": 6543,
  "log_level": "info",
  "enable_ram_monitoring": true,
  "ram_threshold_mb": 8192,
  "fallback_to_cloud_ai": true
}
```

### VS Code Extension Configuration

Configure via VS Code settings:

```json
{
  "oraflow.serverUrl": "ws://localhost:6543",
  "oraflow.autoConnect": true,
  "oraflow.showNotifications": true
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. WebSocket Connection Failed

**Problem**: VS Code extension cannot connect to Flutter app

**Solution**:
- Ensure Flutter app is running
- Check if port 6543 is available
- Verify firewall settings

```bash
# Check if port is in use
netstat -an | findstr 6543
```

#### 2. Flutter Desktop Not Supported

**Problem**: Desktop support not enabled

**Solution**:
```bash
flutter config --enable-windows-desktop
flutter doctor
```

#### 3. Extension Not Loading

**Problem**: VS Code extension fails to load

**Solution**:
```bash
cd oraflow_bridge
npm install
npm run compile
```

#### 4. RAM Issues

**Problem**: App consuming too much memory

**Solution**:
- Enable Resource Guard in settings
- Set lower RAM threshold
- Enable cloud AI fallback

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

<p align="center">
  <em>Built with ❤️ by <strong>Abduljabbar Abdulghani</strong></em>
</p>

Special thanks to:

- The Flutter team for the amazing framework
- VS Code team for the extensible editor
- All contributors and testers

---

<p align="center">
  <strong>Happy Coding! 🎉</strong>
</p>
