module.exports =
  activate: (state) ->
    @tabBarViews = []

    TabBarView = require './tab-bar-view'
    _ = require 'underscore-plus'

    @paneSubscription = atom.workspace.observePanes (pane) =>
      tabBarView = new TabBarView
      tabBarView.initialize(pane)

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)

  deactivate: ->
    @paneSubscription.dispose()
    tabBarView.remove() for tabBarView in @tabBarViews
    return
