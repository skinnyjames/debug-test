
const vscode = require("vscode");
const { activateCrystalDebugFactory } = require('./activate')
const Net = require('node:net')
const { spawn, execSync } = require("child_process");


// doing inline i think...
function activate(context) {
  activateCrystalDebug(context);
}

function deactivate() {  
}

module.exports = { activate, deactivate }

function activateCrystalDebug(context) {
	// register commands
  context.subscriptions.push(
    vscode.commands.registerCommand('extension.skinnyjames-crystal.getProgramName', async (res) => {
      const foo = await  vscode.window.showInputBox({
        placeHolder: "Please enter the name of a crystal file in the workspace folder",
        value: "\"${file}\""
      });
			console.log(foo);
			return foo;
    }),

		vscode.commands.registerCommand('extension.skinnyjames-crystal.getPort', async (res) => {
      const foo = await  vscode.window.showInputBox({
        placeHolder: "Please enter the port Number",
        value: "4567"
      });
			console.log(foo);
			return foo;
    }),

    vscode.commands.registerCommand('extension.skinnyjames-crystal.debugEditorContents', (resource) => {
			let targetResource = resource;
			if (!targetResource && vscode.window.activeTextEditor) {
				targetResource = vscode.window.activeTextEditor.document.uri;
			}
			if (targetResource) {
				vscode.debug.startDebugging(undefined, {
					type: 'crystal',
					name: 'Debug crystal',
					request: 'launch',
					program: targetResource.fsPath,
					port: 4342,
					stopOnEntry: true
				});
			}
    })
  );

	const factory = new CrystalDescriptorFactory()
  const provider = new CrystalConfigurationProvider();

	activateCrystalDebugFactory(context, factory)

  context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('crystal', provider));
}

class CrystalDescriptorFactory {
	#socket;
	#child;

	createDebugAdapterDescriptor(session, exe) {
		const { program, port  } = session.configuration 

		if (!this.#socket) {

			this.#child = spawn(`${__dirname}/../../bin/crystal`, ['i', '--debug-port', `${port}`, program.replace(/\"/g, '')]);
			this.#child.stdout.on('data', (d) => console.log(d.toString()))
			this.#child.stderr.on('data', (d) => console.error(d.toString()))
		}

		execSync('sleep 4')

		return new vscode.DebugAdapterServer(port)
	}

	dispose(){
		console.log('disposing')
		if (this.#socket) {
			this.#socket.close()
		}

		if (this.#child) {
			this.#child.kill()
		}
	}
}

class CrystalConfigurationProvider  {
  async resolveDebugConfiguration(folder, config, token) {

		const program = await vscode.commands.executeCommand('extension.skinnyjames-crystal.getProgramName')
		const port = await vscode.commands.executeCommand('extension.skinnyjames-crystal.getPort')

    if (!config.type && !config.request && !config.name) {
			const editor = vscode.window.activeTextEditor;
			if (editor && editor.document.languageId.toLowerCase() === 'crystal') {
				config.type = 'crystal';
				config.name = 'Launch';
				config.request = 'launch';
				config.port = port
				config.program = program
			}
		}

    if (!config.program) {
			return vscode.window.showInformationMessage("Cannot find a program to debug").then(_ => {
				return undefined;	// abort launch
			});
		}

    return config
  }
}
