#!/usr/bin/env python3
"""
MCP ADB Bridge - Android Device Monitoring Server
Monitors Android device crashes and sends them to OraFlow Desktop via WebSocket
"""

import subprocess
import json
import socket
import asyncio
import websockets
import re
import logging
import sys
import os
from typing import Dict, List, Optional, Tuple
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('adb_bridge.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class ADBBridge:
    def __init__(self, desktop_ws_port: int = 6544):
        self.desktop_ws_port = desktop_ws_port
        self.desktop_ws_uri = f"ws://localhost:{desktop_ws_port}"
        self.desktop_connection = None
        self.is_monitoring = False
        self.device_id = None
        self.adb_process = None
        
        # Android error patterns
        self.error_patterns = {
            'fatal_exception': re.compile(r'FATAL EXCEPTION: (.+)', re.IGNORECASE),
            'null_pointer': re.compile(r'java\.lang\.NullPointerException', re.IGNORECASE),
            'out_of_memory': re.compile(r'OutOfMemoryError', re.IGNORECASE),
            'permission_denied': re.compile(r'Permission denied', re.IGNORECASE),
            'network_error': re.compile(r'java\.net\.ConnectException', re.IGNORECASE),
            'storage_error': re.compile(r'java\.io\.FileNotFoundException', re.IGNORECASE),
            'crash_anr': re.compile(r'ANR in (.+)', re.IGNORECASE),
            'native_crash': re.compile(r'*** FATAL EXCEPTION IN SYSTEM PROCESS', re.IGNORECASE),
            'security_exception': re.compile(r'SecurityException', re.IGNORECASE),
            'illegal_state': re.compile(r'IllegalStateException', re.IGNORECASE),
            'runtime_exception': re.compile(r'RuntimeException', re.IGNORECASE),
        }
        
        # Permission-specific patterns
        self.permission_patterns = {
            'camera': re.compile(r'camera|CAMERA', re.IGNORECASE),
            'location': re.compile(r'location|gps|GPS|ACCESS_FINE_LOCATION', re.IGNORECASE),
            'storage': re.compile(r'storage|external|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE', re.IGNORECASE),
            'network': re.compile(r'network|internet|INTERNET|ACCESS_NETWORK_STATE', re.IGNORECASE),
            'phone_state': re.compile(r'phone_state|READ_PHONE_STATE', re.IGNORECASE),
            'contacts': re.compile(r'contacts|READ_CONTACTS|WRITE_CONTACTS', re.IGNORECASE),
            'sms': re.compile(r'sms|SEND_SMS|READ_SMS', re.IGNORECASE),
        }

    async def connect_to_desktop(self):
        """Establish WebSocket connection to OraFlow Desktop"""
        try:
            self.desktop_connection = await websockets.connect(self.desktop_ws_uri)
            logger.info(f"Connected to OraFlow Desktop at {self.desktop_ws_uri}")
            
            # Send connection confirmation
            await self.desktop_connection.send(json.dumps({
                'type': 'adb_bridge_status',
                'status': 'connected',
                'message': 'ADB Bridge connected successfully'
            }))
            
        except Exception as e:
            logger.error(f"Failed to connect to OraFlow Desktop: {e}")
            raise

    def get_connected_devices(self) -> List[str]:
        """Get list of connected Android devices"""
        try:
            result = subprocess.run(['adb', 'devices'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[1:]  # Skip header
                devices = []
                for line in lines:
                    if line.strip():
                        parts = line.split('\t')
                        if len(parts) >= 2 and parts[1] == 'device':
                            devices.append(parts[0])
                return devices
            else:
                logger.error(f"ADB devices command failed: {result.stderr}")
                return []
        except Exception as e:
            logger.error(f"Error getting connected devices: {e}")
            return []

    def select_device(self) -> Optional[str]:
        """Select Android device for monitoring"""
        devices = self.get_connected_devices()
        
        if not devices:
            logger.warning("No Android devices connected")
            return None
        
        if len(devices) == 1:
            logger.info(f"Auto-selected device: {devices[0]}")
            return devices[0]
        else:
            logger.info(f"Multiple devices found: {devices}")
            logger.info(f"Using first device: {devices[0]}")
            return devices[0]

    def start_adb_logcat(self, device_id: str) -> Optional[subprocess.Popen]:
        """Start adb logcat process for error monitoring"""
        try:
            # Start adb logcat with error filtering
            cmd = [
                'adb', '-s', device_id, 'logcat', 
                '*:E',  # Show only errors
                '-v', 'threadtime'  # Include timestamp and thread info
            ]
            
            logger.info(f"Starting ADB logcat for device {device_id}")
            logger.info(f"Command: {' '.join(cmd)}")
            
            self.adb_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            return self.adb_process
            
        except Exception as e:
            logger.error(f"Failed to start ADB logcat: {e}")
            return None

    def parse_log_line(self, line: str) -> Optional[Dict]:
        """Parse log line and extract error information"""
        if not line.strip():
            return None

        # Extract timestamp and message
        parts = line.split(' ', 5)
        if len(parts) < 6:
            return None

        try:
            timestamp = f"{parts[0]} {parts[1]} {parts[2]}"  # Date Time PID-TID
            message = parts[5] if len(parts) > 5 else ""
            
            # Check for error patterns
            error_type = None
            error_details = {}
            
            for pattern_name, pattern in self.error_patterns.items():
                if pattern.search(message):
                    error_type = pattern_name
                    break
            
            # Check for permission errors
            permission_type = None
            if error_type == 'permission_denied':
                for perm_name, perm_pattern in self.permission_patterns.items():
                    if perm_pattern.search(message):
                        permission_type = perm_name
                        break
            
            # Extract package name if available
            package_match = re.search(r'at ([a-zA-Z0-9_\.]+)\.', message)
            package_name = package_match.group(1) if package_match else None
            
            if error_type:
                return {
                    'type': 'android_error',
                    'timestamp': timestamp,
                    'device_id': self.device_id,
                    'error_type': error_type,
                    'permission_type': permission_type,
                    'package_name': package_name,
                    'message': message.strip(),
                    'full_log_line': line.strip(),
                    'severity': self._get_error_severity(error_type)
                }
            
        except Exception as e:
            logger.debug(f"Failed to parse log line: {e}")
            
        return None

    def _get_error_severity(self, error_type: str) -> str:
        """Determine error severity"""
        critical_errors = ['fatal_exception', 'native_crash', 'out_of_memory']
        permission_errors = ['permission_denied']
        
        if error_type in critical_errors:
            return 'critical'
        elif error_type in permission_errors:
            return 'high'
        else:
            return 'medium'

    async def send_error_to_desktop(self, error_data: Dict):
        """Send error data to OraFlow Desktop"""
        if not self.desktop_connection:
            logger.warning("No connection to desktop, cannot send error")
            return

        try:
            # Add metadata
            error_data['source'] = 'adb_bridge'
            error_data['timestamp_sent'] = time.time()
            
            await self.desktop_connection.send(json.dumps(error_data))
            logger.info(f"Sent Android error to desktop: {error_data['error_type']} - {error_data['message'][:50]}...")
            
        except Exception as e:
            logger.error(f"Failed to send error to desktop: {e}")

    async def monitor_adb_logcat(self):
        """Main monitoring loop for ADB logcat"""
        if not self.adb_process:
            logger.error("ADB process not started")
            return

        logger.info("Starting ADB logcat monitoring...")
        
        try:
            while self.is_monitoring and self.adb_process.poll() is None:
                line = self.adb_process.stdout.readline()
                if line:
                    error_data = self.parse_log_line(line)
                    if error_data:
                        logger.info(f"Detected Android error: {error_data['error_type']} - {error_data['message'][:100]}...")
                        await self.send_error_to_desktop(error_data)
                        
                await asyncio.sleep(0.1)  # Small delay to prevent CPU spinning
                
        except Exception as e:
            logger.error(f"Error in ADB monitoring loop: {e}")
        finally:
            self.stop_adb_logcat()

    def stop_adb_logcat(self):
        """Stop ADB logcat process"""
        if self.adb_process:
            try:
                self.adb_process.terminate()
                self.adb_process.wait(timeout=5)
                logger.info("ADB logcat process stopped")
            except subprocess.TimeoutExpired:
                self.adb_process.kill()
                logger.warning("ADB logcat process killed")
            finally:
                self.adb_process = None

    async def start_monitoring(self):
        """Start the ADB bridge monitoring"""
        if self.is_monitoring:
            logger.warning("ADB Bridge is already monitoring")
            return

        try:
            # Connect to desktop
            await self.connect_to_desktop()
            
            # Select device
            self.device_id = self.select_device()
            if not self.device_id:
                logger.error("No Android device available for monitoring")
                return
            
            # Start ADB logcat
            adb_process = self.start_adb_logcat(self.device_id)
            if not adb_process:
                logger.error("Failed to start ADB logcat")
                return
            
            self.is_monitoring = True
            
            # Send status update
            await self.desktop_connection.send(json.dumps({
                'type': 'adb_monitoring_status',
                'status': 'active',
                'device_id': self.device_id,
                'message': f'Monitoring Android device: {self.device_id}'
            }))
            
            logger.info(f"ADB Bridge started - monitoring device: {self.device_id}")
            
            # Start monitoring loop
            await self.monitor_adb_logcat()
            
        except Exception as e:
            logger.error(f"Failed to start ADB Bridge: {e}")
            await self.stop_monitoring()

    async def stop_monitoring(self):
        """Stop the ADB bridge monitoring"""
        if not self.is_monitoring:
            return

        self.is_monitoring = False
        
        # Stop ADB logcat
        self.stop_adb_logcat()
        
        # Send status update
        if self.desktop_connection:
            try:
                await self.desktop_connection.send(json.dumps({
                    'type': 'adb_monitoring_status',
                    'status': 'stopped',
                    'message': 'ADB Bridge monitoring stopped'
                }))
            except Exception as e:
                logger.error(f"Failed to send stop status: {e}")
        
        # Close desktop connection
        if self.desktop_connection:
            try:
                await self.desktop_connection.close()
                logger.info("ADB Bridge stopped and disconnected from desktop")
            except Exception as e:
                logger.error(f"Error closing desktop connection: {e}")

    async def run(self):
        """Main run method"""
        logger.info("Starting MCP ADB Bridge...")
        
        try:
            await self.start_monitoring()
            
            # Keep running until interrupted
            while self.is_monitoring:
                await asyncio.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt, stopping...")
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
        finally:
            await self.stop_monitoring()

async def main():
    """Main entry point"""
    bridge = ADBBridge()
    
    # Check if ADB is available
    try:
        result = subprocess.run(['adb', 'version'], capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            logger.error("ADB not found. Please install Android SDK Platform Tools.")
            return
        logger.info(f"ADB version: {result.stdout.strip()}")
    except Exception as e:
        logger.error(f"Failed to check ADB: {e}")
        return
    
    await bridge.run()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("ADB Bridge shutdown requested")
    except Exception as e:
        logger.error(f"ADB Bridge failed: {e}")
