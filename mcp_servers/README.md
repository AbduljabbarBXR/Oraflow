# MCP ADB Bridge

The MCP ADB Bridge is a Python server that monitors Android device crashes and sends them to OraFlow Desktop for AI-powered analysis and fixing.

## 🚀 Features

- **Real-time Android Crash Monitoring**: Monitors `adb logcat` for error patterns
- **Permission Error Detection**: Identifies missing permissions (Camera, GPS, Storage, etc.)
- **Native Crash Analysis**: Detects Java exceptions and native crashes
- **WebSocket Communication**: Sends structured error data to OraFlow Desktop
- **Multi-Device Support**: Automatically selects connected Android devices
- **Error Severity Classification**: Categorizes errors by criticality

## 📋 Requirements

- Python 3.8+
- Android SDK Platform Tools (ADB)
- Connected Android device with USB debugging enabled
- OraFlow Desktop app running

## 🔧 Installation

1. **Install Python dependencies:**
   ```bash
   cd mcp_servers
   pip install -r requirements.txt
   ```

2. **Install Android SDK Platform Tools:**
   - Download from [Android Developer Website](https://developer.android.com/studio/releases/platform-tools)
   - Add `adb` to your PATH environment variable

3. **Connect Android device:**
   - Enable USB debugging on your Android device
   - Connect via USB to your computer
   - Verify connection: `adb devices`

## 🏃‍♂️ Usage

### Quick Start
```bash
cd mcp_servers
python adb_bridge.py
```

### Using Setup Script (Windows)
```bash
cd mcp_servers
setup_adb_bridge.bat
```

### Manual Setup
1. Ensure ADB is in your PATH
2. Connect Android device with USB debugging enabled
3. Run: `python adb_bridge.py`
4. The bridge will automatically:
   - Connect to OraFlow Desktop (port 6544)
   - Detect connected Android devices
   - Start monitoring `adb logcat` for errors
   - Send detected errors to OraFlow for analysis

## 📊 Error Types Detected

### Critical Errors
- **Fatal Exceptions**: `FATAL EXCEPTION` patterns
- **Native Crashes**: System-level crashes
- **Out of Memory**: `OutOfMemoryError`

### Permission Errors
- **Camera Access**: Missing camera permissions
- **Location Access**: GPS/location permission issues
- **Storage Access**: External storage permission problems
- **Network Access**: Internet/network state permissions
- **Phone State**: Read phone state permissions
- **Contacts**: Contact read/write permissions
- **SMS**: SMS send/read permissions

### Runtime Errors
- **Null Pointer**: `NullPointerException`
- **Security Exceptions**: Permission/security violations
- **Illegal State**: Invalid state exceptions
- **Runtime Exceptions**: General runtime errors

## 🔌 Integration with OraFlow

The ADB Bridge communicates with OraFlow Desktop via WebSocket on port 6544:

```json
{
  "type": "android_error",
  "timestamp": "2025-12-30 15:30:45.123",
  "device_id": "emulator-5554",
  "error_type": "permission_denied",
  "permission_type": "camera",
  "package_name": "com.example.myapp",
  "message": "Permission denied: Camera permission not granted",
  "severity": "high",
  "source": "adb_bridge"
}
```

## 🐛 Troubleshooting

### ADB Not Found
```bash
# Check if ADB is installed
adb version

# If not found, add to PATH:
# Windows: Add Android SDK platform-tools to PATH
# macOS/Linux: export PATH=$PATH:/path/to/platform-tools
```

### No Devices Connected
```bash
# Check connected devices
adb devices

# If no devices listed:
# 1. Enable USB debugging on device
# 2. Install USB drivers if needed
# 3. Try different USB cable/port
```

### Permission Issues
```bash
# On Android device:
# 1. Go to Settings > Developer Options
# 2. Enable USB Debugging
# 3. Reconnect device and accept RSA key prompt
```

### Connection to Desktop Failed
- Ensure OraFlow Desktop is running
- Check that port 6544 is not blocked by firewall
- Verify WebSocket server is active in OraFlow

## 📝 Log Files

The ADB Bridge creates log files for debugging:
- `adb_bridge.log`: Main application logs
- Console output: Real-time monitoring information

## 🔧 Configuration

### Custom Port
To use a different port, modify the `desktop_ws_port` parameter:
```python
bridge = ADBBridge(desktop_ws_port=6545)
```

### Custom Error Patterns
Add new error patterns to the `error_patterns` dictionary:
```python
self.error_patterns['custom_error'] = re.compile(r'Custom Error Pattern')
```

## 🚀 Advanced Usage

### Multiple Devices
The bridge automatically selects the first connected device. For multiple devices, it will use the first one detected.

### Error Filtering
The bridge filters `adb logcat` to show only errors (`*:E`) to reduce noise and focus on actionable issues.

### Real-time Monitoring
Errors are processed and sent to OraFlow in real-time as they appear in the logcat output.

## 🤝 Integration Points

### With OraFlow Desktop
- WebSocket communication on port 6544
- JSON message format for error data
- Status updates for connection and monitoring state

### With Terminal Service
- Complements existing terminal error detection
- Handles Android-specific errors not visible in Flutter terminal
- Maintains first-error-only lock system

### With AI Service
- Provides structured Android error data for AI analysis
- Enables mobile-specific fix suggestions
- Supports permission-related fix recommendations

## 📋 Development

### Testing
```bash
# Run tests (if pytest is installed)
pytest test_adb_bridge.py

# Manual testing
python adb_bridge.py
```

### Debug Mode
Enable debug logging by modifying the logging level:
```python
logging.basicConfig(level=logging.DEBUG)
```

## 📞 Support

For issues with the MCP ADB Bridge:
1. Check the troubleshooting section above
2. Review log files for error details
3. Verify ADB and device connection
4. Ensure OraFlow Desktop is running and accessible

This bridge is a critical component for making OraFlow truly comprehensive in mobile development monitoring and debugging.
