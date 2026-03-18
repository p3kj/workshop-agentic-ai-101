## Prepare your Windows environment for agentic coding

```powershell
irm https://raw.githubusercontent.com/p3kj/workshop-agentic-ai/refs/heads/main/setup-agentic-coding.ps1 | iex
```

## Gemini CLI

### Installation

To install the Gemini CLI, ensure you have Node.js 20+ installed, then run:

```powershell
npm install -g @google/gemini-cli
```

### Authentication

To authenticate your account, simply run:

```powershell
gemini
```

Then, select **Sign in with Google** and follow the instructions in your browser. This works for both personal and Google Workspace accounts.

### Basic Shortcuts & Navigation

| Shortcut | Action |
| :--- | :--- |
| `Enter` | Submit prompt / Confirm |
| `Ctrl + C` | Cancel request / Exit |
| `Up / Down` | Navigate history |
| `Tab` | Accept suggestion / Next item |
| `Esc` (twice) | Browse and rewind history |
| `?` | Toggle shortcuts help panel |
| `/help` | Show interactive commands |
| `!` | Toggle Shell Mode |
| `/quit` | Exit Gemini CLI |
