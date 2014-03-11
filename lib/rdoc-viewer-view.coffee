path = require 'path'
{$, $$$, EditorView, ScrollView, BufferedProcess} = require 'atom'
_ = require 'underscore-plus'
{File} = require 'pathwatcher'
{extensionForFenceName} = require './extension-helper'


module.exports =
class RdocViewerView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new RdocViewerView(state)

  @content: ->
    @div class: 'rdoc-viewer native-key-bindings', tabindex: -1

  constructor: ({@editorId, filePath}) ->
    super

    if @editorId?
      @resolveEditor(@editorId)
    else
      @file = new File(filePath)
      @handleEvents()

  serialize: ->
    deserializer: 'RdocViewerView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      atom.packages.once 'activated', =>
        resolve()
        @renderMarkdown()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderRdoc()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()

    changeHandler = =>
      @renderMarkdown()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @subscribe(@file, 'contents-changed', changeHandler)
    else if @editor?
      @subscribe(@editor.getBuffer(), 'contents-modified', changeHandler)

  renderRdoc: ->
    @showLoading()
    if @file?
      @file.read().then (contents) => @renderRdocText(contents)
    else if @editor?
      @renderRdocText(@editor.getText())

  renderRdocText: (text) ->
    command = 'sdoc'
    temp_file = new File('/tmp/rdoc_' + @editorId + '.html')
    temp_file.write(text)
    # sdoc ~/src/jiff/platform_x3/gems/jiff_messaging/lib/jiff_messaging/builder.rb -T direct -Z > /tmp/sdoc.html
    args = [temp_file.getPath, '-T', 'direct', '-Z']

    output = []
    errors = []
    stdout = (data) -> output.push(data)
    stderr = (data) -> errors.push(data)

    exit = (code) ->
      if errors.length < 1
        @html(output.join(' '))
      else
        @html(errors.join(' '))

    process = new BufferedProcess({command, args, stdout, stderr, exit})

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Docs"
    else if @editor?
      "#{@editor.getTitle()} Docs"
    else
      "Rdoc Preview"

  getUri: ->
    if @file?
      "rdoc-viewer://#{@getPath()}"
    else
      "rdoc-viewer://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Compiling Rdoc Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'rdoc-spinner', 'Loading Documentation\u2026'

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
      $(preElement).addClass("editor-colors")
      codeBlock = $(preElement.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name matches `lang`
      continue unless extension = extensionForFenceName(fenceName)
      text = codeBlock.text()

      grammar = atom.syntax.selectGrammar("foo.#{extension}", text)

      codeBlock.empty()
      for tokens in grammar.tokenizeLines(text)
        codeBlock.append(EditorView.buildLineHtml({ tokens, text }))

    html
