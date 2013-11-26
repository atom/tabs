{_} = require 'atom'
TabBarView = require './tab-bar-view'

module.exports =
  activate: ->
    @paneSubscription = atom.workspaceView.eachPane (pane) =>
      tabBarView = new TabBarView(pane)
      @tabBarViews ?= []
      @tabBarViews.push(tabBarView)
      onPaneRemoved = (event, removedPane) =>
        return unless pane is removedPane
        _.remove(@tabBarViews, tabBarView)
        atom.workspaceView.off('pane:removed', onPaneRemoved)
      atom.workspaceView.on('pane:removed', onPaneRemoved)
      tabBarView

  deactivate: ->
    @paneSubscription?.off()
    tabBarView.remove() for tabBarView in @tabBarViews ? []
