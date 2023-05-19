# skinnyjames-crystal-debug README

This is a POC for Crystal VSCode debugging using the [Crystal intepreter](https://crystal-lang.org/2021/12/29/crystal-i/)

It is only meant to illustrate the idea for an embedded [DAP server](https://microsoft.github.io/debug-adapter-protocol/overview), and not a serious attempt at a plugin.

## Usage

1. Clone this repository
1. Compile crystal with the interpeter `make crystal intepreter=1 stats=1`.  This should create a binary in `bin`.
1. Open the project in VSCode and navigate to the `vscode-extension` directory in a terminal
1. Run `npm i`
1. Open `vscode-extension/src/extension.js` in VSCode, and click the `Run and Debug` menu option on the left of the IDE.
1. Click `Run and Debug`.  There should be a debug from extension menu option, and this will open a new extension debugger session.
1. In the new session, open an existing Crystal file.  There is a simple `hello.cr` provided in root directory of this project that can be used.
1. Set some breakpoints against the Crystal file and click `Run and Debug`
1. 2 prefilled prompts will show up for a filename and port.  They can be submitted.
1. Open the `DEBUG CONSOLE` in the cloned project to see output from the DAP server in the binary.
1. Use the `DEBUG CONSOLE` in the debugger session project to evaluate expressions from a breakpoint.


## Mechanic

For better or worse, this illustration works by embeddeding a DAP server in the interpreter's internals, and is activated by provided a `--debug-port <PORT>` option.

The VSCode extension itself simply starts the binary with this option, and proxies the port off to VSCode.

A few commands to set brekapoints and evaluate expressions are implemented, but it isn't formalized and I also don't know much about the Crystal compiler/interpreter.

## Requirements

If you have any requirements or dependencies, add a section describing those and how to install and configure them.

## Extension Settings

Include if your extension adds any VS Code settings through the `contributes.configuration` extension point.

For example:

This extension contributes the following settings:

* `myExtension.enable`: Enable/disable this extension.
* `myExtension.thing`: Set to `blah` to do something.

## Known Issues

Calling out known issues can help limit users opening duplicate issues against your extension.

## Release Notes

Users appreciate release notes as you update your extension.

### 1.0.0

Initial release of ...

### 1.0.1

Fixed issue #.

### 1.1.0

Added features X, Y, and Z.

---

## Working with Markdown

You can author your README using Visual Studio Code.  Here are some useful editor keyboard shortcuts:

* Split the editor (`Cmd+\` on macOS or `Ctrl+\` on Windows and Linux)
* Toggle preview (`Shift+Cmd+V` on macOS or `Shift+Ctrl+V` on Windows and Linux)
* Press `Ctrl+Space` (Windows, Linux, macOS) to see a list of Markdown snippets

## For more information

* [Visual Studio Code's Markdown Support](http://code.visualstudio.com/docs/languages/markdown)
* [Markdown Syntax Reference](https://help.github.com/articles/markdown-basics/)

**Enjoy!**
