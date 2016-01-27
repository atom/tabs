FileIcons = require './file-icons'
layout = require './layout'

module.exports =
  activate: (state) ->
    layout.activate()
    @tabBarViews = []

    TabBarView = require './tab-bar-view'
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
      tabBarView = new TabBarView
      tabBarView.initialize(pane)

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)

  deactivate: ->
    layout.deactivate()
    @paneSubscription.dispose()
    @fileIconsDisposable?.dispose()
    tabBarView.remove() for tabBarView in @tabBarViews
    return

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @fileIconsDisposable = service.onWillDeactivate ->
      FileIcons.resetService()
      @updateFileIcons()
    @updateFileIcons()

  updateFileIcons: ->
    for tabBarView in @tabBarViews
      tabView.updateIcon() for tabView in tabBarView.getTabs()
