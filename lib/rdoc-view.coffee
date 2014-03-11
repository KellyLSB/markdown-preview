url = require 'url'
fs = require 'fs-plus'

RdocViewerView = require './rdoc-viewer-view'

module.exports =
  configDefaults:
    grammars: [
      'source.gfm'
      'source.litcoffee'
      'text.plain'
      'text.plain.null-grammar'
    ]

  activate: ->
    atom.workspaceView.command 'rdoc-viewer:toggle', =>
      @toggle()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'rdoc-viewer:'

      if host is 'editor'
        new RdocViewerView(editorId: pathname.substring(1))
      else
        new RdocViewerView(filePath: pathname)

  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('rdoc-viewer.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    uri = "rdoc-viewer://editor/#{editor.id}"

    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (rdocViewerView) ->
      if rdocViewerView instanceof RdocViewerView
        rdocViewerView.renderRdoc()
        previousActivePane.activate()
