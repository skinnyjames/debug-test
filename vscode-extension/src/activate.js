const vscode = require("vscode");

function activateCrystalDebugFactory(context, factory) {
	context.subscriptions.push(vscode.debug.registerDebugAdapterDescriptorFactory('crystal', factory));
  context.subscriptions.push(factory)
}

module.exports = { activateCrystalDebugFactory }