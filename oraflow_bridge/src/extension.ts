import * as vscode from 'vscode';
import WebSocket from 'ws';
import { PreviewHandler } from './preview_handler';
import * as path from 'path';
import * as fs from 'fs';

let ws: WebSocket | null = null;
let reconnectInterval: NodeJS.Timeout | null = null;
let previewHandler: PreviewHandler | null = null;
const RECONNECT_INTERVAL = 3000; // 3 seconds
const SERVER_URL = 'ws://localhost:6543';

export function activate(context: vscode.ExtensionContext) {
    console.log('OraFlow VS Code Extension is now active!');

    // Initialize preview handler
    previewHandler = new PreviewHandler(context);

    // Start connection attempt
    connectToOraFlow();

    // Register commands
    let disposable = vscode.commands.registerCommand('oraflow.testConnection', () => {
        vscode.window.showInformationMessage('OraFlow: Testing connection...');
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'test', message: 'Hello from VS Code!' }));
        } else {
            vscode.window.showWarningMessage('OraFlow: Not connected to desktop app');
        }
    });

    context.subscriptions.push(disposable);
}

function connectToOraFlow() {
    console.log('Attempting to connect to OraFlow Desktop...');

    ws = new WebSocket(SERVER_URL);

    ws.on('open', () => {
        console.log('Connected to OraFlow Desktop!');
        vscode.window.showInformationMessage('OraFlow Connected ⚡');

        // Clear any pending reconnect
        if (reconnectInterval) {
            clearInterval(reconnectInterval);
            reconnectInterval = null;
        }
    });

    ws.on('message', async (data: Buffer) => {
        try {
            const message = JSON.parse(data.toString());
            console.log('Received from OraFlow:', message);

            // FIX: Check for both 'type' OR 'command'
            const msgType = message.type || message.command;

            if (msgType === 'apply_edit' || msgType === 'apply_workspace_edit') {
                // Support both single-line edits (legacy) and multi-file atomic edits.
                const edits = message.edits || (message.file && message.line && message.newText ? [
                    { file: message.file, startLine: message.line, endLine: message.line, newText: message.newText }
                ] : []);

                if (!edits || edits.length === 0) {
                    vscode.window.showErrorMessage('OraFlow: No edits provided');
                    return;
                }

                const workspaceEdit = new vscode.WorkspaceEdit();
                const appliedFiles = new Set<string>();

                try {
                    for (const e of edits) {
                        const workspaceRoot = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
                            ? vscode.workspace.workspaceFolders[0].uri.fsPath
                            : '';
                        const filePath = e.file ? e.file.toString() : '';
                        const resolvedPath = path.isAbsolute(filePath) ? filePath : path.join(workspaceRoot, filePath);

                        console.log('OraFlow: attempting to apply edit to', resolvedPath);

                        let finalResolved = resolvedPath;
                        if (!fs.existsSync(finalResolved)) {
                            // Try fallback: trim any leading path separators
                            const trimmed = filePath.replace(/^\\+|^\/+/, '');
                            const alt = path.isAbsolute(trimmed) ? trimmed : path.join(workspaceRoot, trimmed);
                            if (fs.existsSync(alt)) {
                                finalResolved = alt;
                            } else {
                                // Try to search the workspace for the filename
                                try {
                                    const basename = path.basename(filePath);
                                    const found = await vscode.workspace.findFiles(`**/${basename}`, '**/build/**', 1);
                                    if (found && found.length > 0) {
                                        finalResolved = found[0].fsPath;
                                    }
                                } catch (searchErr) {
                                    console.error('OraFlow: workspace search failed:', searchErr);
                                }
                            }
                        }

                        if (!fs.existsSync(finalResolved)) {
                            console.error('OraFlow: target file does not exist after search:', finalResolved);
                            ws?.send(JSON.stringify({ type: 'fix_applied_confirmation', success: false, error: `Target file not found: ${finalResolved}`, files: [] }));
                            vscode.window.showErrorMessage(`OraFlow: Target file not found: ${finalResolved}`);
                            return;
                        }

                        const fileUri = vscode.Uri.file(finalResolved);
                        const doc = await vscode.workspace.openTextDocument(fileUri);
                        const start = (e.startLine ? Math.max(e.startLine - 1, 0) : 0);
                        const end = (e.endLine ? Math.max(e.endLine - 1, 0) : start);
                        const range = new vscode.Range(new vscode.Position(start, 0), new vscode.Position(end, doc.lineAt(end).range.end.character));

                        // If newText not provided, skip
                        const newText = e.newText ?? '';
                        workspaceEdit.replace(fileUri, range, newText);
                                    appliedFiles.add(finalResolved);
                    }

                    const success = await vscode.workspace.applyEdit(workspaceEdit);
                    if (success) {
                        // Save all changed documents
                        for (const f of appliedFiles) {
                            const uri = vscode.Uri.file(f);
                            const doc = await vscode.workspace.openTextDocument(uri);
                            await doc.save();
                        }

                        ws?.send(JSON.stringify({
                            type: 'fix_applied_confirmation',
                            success: true,
                            files: Array.from(appliedFiles),
                        }));

                        vscode.window.showInformationMessage(`OraFlow: Applied ${appliedFiles.size} edit(s) ✅`);
                    } else {
                        vscode.window.showErrorMessage('OraFlow: Failed to apply workspace edit');
                        console.error('OraFlow: vscode.workspace.applyEdit returned false');
                    }
                } catch (err) {
                    console.error('Failed to apply workspace edits:', err);
                    vscode.window.showErrorMessage(`OraFlow: Failed to apply edits: ${err}`);
                    // Send failure back
                    ws?.send(JSON.stringify({ type: 'fix_applied_confirmation', success: false, error: `${err}` }));
                }
            }
            else if (msgType === 'error_detected') {
                // Surface incoming error details from desktop into VS Code
                try {
                    const err = message.error || message.payload || {};
                    const msg = err.errorMessage || JSON.stringify(err);
                    console.log('OraFlow: error_detected received:', err);
                    vscode.window.showWarningMessage(`OraFlow detected an error: ${msg}`);
                } catch (e) {
                    console.error('OraFlow: failed to surface error_detected:', e);
                }
            }
            else if (msgType === 'preview_fix') {
                // Handle preview fix request
                if (previewHandler && message.preview_available) {
                    const fileName = message.file_name || 'Unknown';
                    const lineNumber = message.line_number || 1;
                    const beforeCode = message.before_code || '';
                    const afterCode = message.after_code || '';
                    const changeDescription = message.change_description || 'No description provided';

                    previewHandler.showPreview(
                        fileName,
                        lineNumber,
                        beforeCode,
                        afterCode,
                        changeDescription,
                        async () => {
                            // User accepted the fix - attempt to apply edits provided in original_fix
                            try {
                                const original = message.original_fix || message.originalFix || null;
                                const edits = original && Array.isArray(original.edits) ? original.edits : [];

                                if (!edits || edits.length === 0) {
                                    // If no edits provided, notify desktop and return
                                    ws?.send(JSON.stringify({ type: 'fix_accepted', file: message.file_name, line: lineNumber, original_fix: message.original_fix }));
                                    return;
                                }

                                const workspaceEdit = new vscode.WorkspaceEdit();
                                const appliedFiles = new Set<string>();

                                const workspaceRoot = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
                                    ? vscode.workspace.workspaceFolders[0].uri.fsPath
                                    : '';

                                for (const e of edits) {
                                    const filePath = e.file ? e.file.toString() : '';
                                    const resolved = path.isAbsolute(filePath) ? filePath : path.join(workspaceRoot, filePath);
                                    const fileUri = vscode.Uri.file(resolved);
                                    const doc = await vscode.workspace.openTextDocument(fileUri);

                                    const startLine = e.startLine ? Math.max(e.startLine - 1, 0) : (e.line ? Math.max(e.line - 1, 0) : 0);
                                    const endLine = e.endLine ? Math.max(e.endLine - 1, 0) : startLine;
                                    const startPos = new vscode.Position(startLine, 0);
                                    const endPos = new vscode.Position(endLine, doc.lineAt(endLine).range.end.character);
                                    const range = new vscode.Range(startPos, endPos);

                                    const newText = e.newText ?? (e.new_line_content ?? '');
                                    workspaceEdit.replace(fileUri, range, newText);
                                    appliedFiles.add(resolved);
                                }

                                const success = await vscode.workspace.applyEdit(workspaceEdit);
                                if (success) {
                                    for (const f of appliedFiles) {
                                        const uri = vscode.Uri.file(f);
                                        const d = await vscode.workspace.openTextDocument(uri);
                                        await d.save();
                                    }

                                    ws?.send(JSON.stringify({ type: 'fix_applied_confirmation', success: true, files: Array.from(appliedFiles) }));
                                    vscode.window.showInformationMessage(`OraFlow: Applied ${appliedFiles.size} edit(s) ✅`);
                                } else {
                                    ws?.send(JSON.stringify({ type: 'fix_applied_confirmation', success: false, error: 'Failed to apply workspace edit' }));
                                    vscode.window.showErrorMessage('OraFlow: Failed to apply edits from preview');
                                }
                            } catch (err) {
                                console.error('Failed to apply edits from preview:', err);
                                ws?.send(JSON.stringify({ type: 'fix_applied_confirmation', success: false, error: `${err}` }));
                                vscode.window.showErrorMessage(`OraFlow: Failed to apply edits: ${err}`);
                            }
                        },
                        () => {
                            // User rejected the fix - send rejection to desktop
                            ws?.send(JSON.stringify({
                                type: 'fix_rejected',
                                file: message.file_name,
                                line: lineNumber,
                                reason: 'User rejected preview'
                            }));
                        }
                    );
                } else {
                    vscode.window.showWarningMessage('OraFlow: Preview not available or handler not initialized');
                }
            }
            else if (msgType === 'ping') {
                ws?.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
            }
            else if (msgType === 'notification') {
                vscode.window.showInformationMessage(`OraFlow: ${message.message}`);
            }
            else if (msgType === 'error') {
                vscode.window.showErrorMessage(`OraFlow Error: ${message.message}`);
            }
            else {
                console.log('Unhandled message type:', msgType);
            }
        } catch (error) {
            console.error('Failed to parse message:', error);
        }
    });

    ws.on('close', () => {
        console.log('Disconnected from OraFlow Desktop');
        vscode.window.showWarningMessage('OraFlow Disconnected - Attempting to reconnect...');

        // Start reconnection attempts
        startReconnect();
    });

    ws.on('error', (error: any) => {
        console.error('WebSocket error:', error);
        startReconnect();
    });
}

async function handleApplyEdit(message: any) {
    const { file, line, oldText, newText } = message;

    try {
        // Open the document
        const document = await vscode.workspace.openTextDocument(file);
        await vscode.window.showTextDocument(document);

        const editor = vscode.window.activeTextEditor;
        if (editor && editor.document === document) {
            // Get the range for the entire line (0-based indexing)
            const lineIndex = line - 1;
            const lineRange = document.lineAt(lineIndex).range;

            // Apply the edit using TextEditorEdit.replace
            const success = await editor.edit(editBuilder => {
                editBuilder.replace(lineRange, newText);
            });

            if (success) {
                vscode.window.showInformationMessage('OraFlow: Fix Applied Successfully! 🚀');
                // Optionally move cursor to the edited line
                const position = new vscode.Position(lineIndex, 0);
                editor.selection = new vscode.Selection(position, position);
                editor.revealRange(new vscode.Range(position, position));
            } else {
                vscode.window.showErrorMessage('OraFlow: Failed to apply fix');
            }
        } else {
            vscode.window.showErrorMessage('OraFlow: No active editor for the target file');
        }
    } catch (error) {
        console.error('Failed to apply edit:', error);
        vscode.window.showErrorMessage(`OraFlow: Failed to apply fix to ${file}`);
    }
}

function startReconnect() {
    if (reconnectInterval) return; // Already reconnecting

    console.log(`Will attempt to reconnect every ${RECONNECT_INTERVAL}ms...`);
    reconnectInterval = setInterval(() => {
        if (ws && ws.readyState === WebSocket.CLOSED) {
            console.log('Attempting to reconnect...');
            connectToOraFlow();
        }
    }, RECONNECT_INTERVAL);
}

export function deactivate() {
    console.log('OraFlow VS Code Extension deactivated');

    if (reconnectInterval) {
        clearInterval(reconnectInterval);
    }

    if (ws) {
        ws.close();
    }
}
