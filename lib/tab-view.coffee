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
    @lastActiveAt   = new Date()
    @lastModifiedAt = null

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
    return if @updatingTitle
    @updatingTitle = true

    title = @item.getTitle()
    useLongTitle = false
    for tab in @getSiblingTabs()
      if tab.item.getTitle() is title
        tab.updateTitle()
        useLongTitle = true
    title = @item.getLongTitle?() ? title if useLongTitle

    @title.text(title)
    @updatingTitle = false

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
      @lastModifiedAt = new Date()
    else
      @removeClass('modified') if @isModified
      @isModified = false
