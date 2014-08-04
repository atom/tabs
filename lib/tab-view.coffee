{$, View} = require 'atom'
_ = require 'underscore-plus'
path = require 'path'

module.exports =
class TabView extends View
  @content: ->
    @li class: 'tab sortable', =>
      @div class: 'title', outlet: 'title'
      @div class: 'close-icon'

  initialize: (@item, @pane) ->
    @item.on? 'title-changed', =>
      @updateDataAttributes()
      @updateTitle()
      @updateTooltip()

    @item.on? 'icon-changed', =>
      @updateIcon()

    @item.on? 'modified-status-changed', =>
      @updateModifiedStatus()

    @subscribe atom.config.observe 'tabs.showIcons', => @updateIconVisibility()

    @updateDataAttributes()
    @updateTitle()
    @updateIcon()
    @updateModifiedStatus()
    @updateTooltip()

  updateTooltip: ->
    @destroyTooltip()

    if itemPath = @item.getPath?()
      @setTooltip
        title: _.escape(itemPath)
        delay:
          show: 2000
          hide: 100
        placement: 'bottom'

  beforeRemove: ->
    @destroyTooltip()

  updateDataAttributes: ->
    if itemPath = @item.getPath?()
      @title.attr('data-name', path.basename(itemPath))
      @title.attr('data-path', itemPath)

  updateTitle: ->
    tabs = [this]
    collectTabs= (parent, tabs)->
      for tab in parent.getSiblingTabs()
        if (tabs.indexOf(tab) != -1  and 
            tab.item.getTitle() is parent.item.getTitle())
          parent.useLongTitle = true
          tabs.push(tab)
          collectTabs(tab, tabs)
    collectTabs this, tabs
    for tab in tabs
      tab.title.text(tab.useLongTitle and tab.item.getLongTitle() or
                     tab.item.getTitle())
      delete tab.useLongTitle

  updateIcon: ->
    if @iconName
      @title.removeClass "icon icon-#{@iconName}"

    if @iconName = @item.getIconName?()
      @title.addClass "icon icon-#{@iconName}"

  getSiblingTabs: ->
    @siblings('.tab').views()

  updateIconVisibility: ->
    if atom.config.get "tabs.showIcons"
      @title.removeClass("hide-icon")
    else
      @title.addClass("hide-icon")

  updateModifiedStatus: ->
    if @item.isModified?()
      @addClass('modified') unless @isModified
      @isModified = true
    else
      @removeClass('modified') if @isModified
      @isModified = false
