{_} = require 'atom'
TabBarView = require './tab-bar-view'

module.exports =
  activate: ->
    @paneSubscription = atom.rootView.eachPane (pane) =>
      tabBarView = new TabBarView(pane)
      @tabBarViews ?= []
      @tabBarViews.push(tabBarView)
      onPaneRemoved = (event, removedPane) =>
        return unless pane is removedPane
        _.remove(@tabBarViews, tabBarView)
        atom.rootView.off('pane:removed', onPaneRemoved)
      atom.rootView.on('pane:removed', onPaneRemoved)
      tabBarView

  deactivate: ->
    @paneSubscription?.off()
    tabBarView.remove() for tabBarView in @tabBarViews ? []
