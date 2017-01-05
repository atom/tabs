{Disposable} = require 'atom'
FileIcons = require './file-icons'
layout = require './layout'

module.exports =
  activate: (state) ->
    layout.activate()
    @tabBarViews = []
    @mruListViews = []

    TabBarView = require './tab-bar-view'
    MRUListView = require './mru-list-view'
    _ = require 'underscore-plus'

    # If the command bubbles up without being handled by a particular pane,
    # close all tabs in all panes
    atom.commands.add 'atom-workspace',
      'tabs:close-all-tabs': =>
        # We loop backwards because the panes are
        # removed from the array as we go
        for tabBarView in @tabBarViews by -1
          tabBarView.closeAllTabs()

    @paneSubscription = atom.workspace.observePanes (pane) =>
      tabBarView = new TabBarView(pane)
      mruListView = new MRUListView
      mruListView.initialize(pane)

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView.element, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)
      @mruListViews.push(mruListView)
      pane.onDidDestroy => _.remove(@mruListViews, mruListView)

  deactivate: ->
    layout.deactivate()
    @paneSubscription.dispose()
    @fileIconsDisposable?.dispose()
    tabBarView.destroy() for tabBarView in @tabBarViews
    mruListView.remove() for mruListView in @mruListViews
    return

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @updateFileIcons()
    new Disposable =>
      FileIcons.resetService()
      @updateFileIcons()

  updateFileIcons: ->
    for tabBarView in @tabBarViews
      tabView.updateIcon() for tabView in tabBarView.getTabs()
