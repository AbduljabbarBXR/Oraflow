import * as vscode from 'vscode';
import * as path from 'path';

export class PreviewHandler {
  private panel: vscode.WebviewPanel | undefined;
  private disposables: vscode.Disposable[] = [];

  constructor(private context: vscode.ExtensionContext) {}

  showPreview(
    fileName: string,
    lineNumber: number,
    beforeCode: string,
    afterCode: string,
    changeDescription: string,
    onAccept: () => void,
    onReject: () => void
  ) {
    const title = `OraFlow Fix Preview - ${fileName}:${lineNumber}`;

    if (this.panel) {
      this.panel.title = title;
      this.panel.webview.html = this.getHtmlForWebview(
        fileName,
        lineNumber,
        beforeCode,
        afterCode,
        changeDescription
      );
      this.panel.reveal(vscode.ViewColumn.Beside);
    } else {
      this.panel = vscode.window.createWebviewPanel(
        'oraflowFixPreview',
        title,
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          localResourceRoots: [vscode.Uri.file(path.join(this.context.extensionPath, 'media'))]
        }
      );

      this.panel.webview.html = this.getHtmlForWebview(
        fileName,
        lineNumber,
        beforeCode,
        afterCode,
        changeDescription
      );

      this.panel.onDidDispose(() => {
        this.panel = undefined;
        this.dispose();
      }, null, this.disposables);

      // Handle messages from the webview
      this.panel.webview.onDidReceiveMessage(
        message => {
          switch (message.command) {
            case 'acceptFix':
              onAccept();
              this.panel?.dispose();
              return;
            case 'rejectFix':
              onReject();
              this.panel?.dispose();
              return;
            case 'closePreview':
              this.panel?.dispose();
              return;
          }
        },
        undefined,
        this.disposables
      );
    }
  }

  private getHtmlForWebview(
    fileName: string,
    lineNumber: number,
    beforeCode: string,
    afterCode: string,
    changeDescription: string
  ): string {
    const nonce = this.getNonce();

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OraFlow Fix Preview</title>
    <style>
        :root {
            --bg-color: #ffffff;
            --text-color: #333333;
            --border-color: #e1e4e8;
            --header-bg: #2d3748;
            --header-text: #ffffff;
            --before-bg: #fff5f5;
            --after-bg: #f0fff4;
            --accept-bg: #48bb78;
            --reject-bg: #f56565;
            --code-font: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            margin: 0;
            padding: 0;
            background-color: var(--bg-color);
            color: var(--text-color);
            height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .header {
            background-color: var(--header-bg);
            color: var(--header-text);
            padding: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid var(--border-color);
        }

        .header h2 {
            margin: 0;
            font-size: 16px;
            font-weight: 600;
        }

        .content {
            flex: 1;
            display: flex;
            height: 100%;
        }

        .code-panel {
            flex: 1;
            display: flex;
            flex-direction: column;
            border-right: 1px solid var(--border-color);
        }

        .code-panel:last-child {
            border-right: none;
        }

        .panel-header {
            background-color: #f8fafc;
            padding: 8px 16px;
            border-bottom: 1px solid var(--border-color);
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #4a5568;
        }

        .code-container {
            flex: 1;
            overflow: auto;
            padding: 16px;
            background-color: var(--before-bg);
            font-family: var(--code-font);
            font-size: 12px;
            line-height: 1.5;
            white-space: pre;
        }

        .code-container.after {
            background-color: var(--after-bg);
        }

        .footer {
            background-color: #f7fafc;
            padding: 16px;
            border-top: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .change-description {
            font-size: 14px;
            color: #4a5568;
            margin-bottom: 8px;
        }

        .buttons {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .status-text {
            font-size: 12px;
            color: #718096;
        }

        button {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .btn-accept {
            background-color: var(--accept-bg);
            color: white;
        }

        .btn-accept:hover {
            background-color: #38a169;
            transform: translateY(-1px);
        }

        .btn-reject {
            background-color: transparent;
            color: #e53e3e;
            border: 1px solid #e53e3e;
        }

        .btn-reject:hover {
            background-color: #e53e3e;
            color: white;
        }

        .btn-close {
            background-color: transparent;
            color: #718096;
            border: 1px solid #cbd5e0;
        }

        .btn-close:hover {
            background-color: #cbd5e0;
            color: #2d3748;
        }

        .line-highlight {
            background-color: rgba(255, 255, 0, 0.2);
            padding: 2px 4px;
            border-radius: 3px;
        }

        .monospace {
            font-family: var(--code-font);
        }
    </style>
</head>
<body>
    <div class="header">
        <h2>
            <span style="opacity: 0.7;">OraFlow Fix Preview</span>
            <span style="margin-left: 8px; font-weight: 400;">${fileName}:${lineNumber}</span>
        </h2>
        <button class="btn-close" onclick="sendMessage('closePreview')">Close</button>
    </div>

    <div class="content">
        <div class="code-panel">
            <div class="panel-header">Before</div>
            <div class="code-container">
${beforeCode}
            </div>
        </div>
        <div class="code-panel">
            <div class="panel-header">After</div>
            <div class="code-container after">
${afterCode}
            </div>
        </div>
    </div>

    <div class="footer">
        <div class="change-description">
            <strong>Change:</strong> <span class="monospace">${changeDescription}</span>
        </div>
        <div class="buttons">
            <span class="status-text">Review the changes before applying</span>
            <div>
                <button class="btn-accept" onclick="sendMessage('acceptFix')">Apply Fix</button>
                <button class="btn-reject" onclick="sendMessage('rejectFix')">Reject</button>
            </div>
        </div>
    </div>

    <script nonce="${nonce}">
        function sendMessage(command) {
            vscode.postMessage({
                command: command
            });
        }

        // Handle keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                sendMessage('closePreview');
            } else if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                sendMessage('acceptFix');
            } else if (e.key === 'Escape') {
                sendMessage('rejectFix');
            }
        });
    </script>
</body>
</html>`;
  }

  private getNonce(): string {
    let text = '';
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    for (let i = 0; i < 32; i++) {
      text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
  }

  dispose() {
    if (this.panel) {
      this.panel.dispose();
    }
    while (this.disposables.length) {
      const x = this.disposables.pop();
      if (x) {
        x.dispose();
      }
    }
  }
}
