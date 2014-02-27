{$, View} = require 'atom'
path = require 'path'

module.exports =
class TabView extends View
  @content: ->
    @li class: 'tab sortable', =>
      @div class: 'title', outlet: 'title'
      @div class: 'close-icon'

  initialize: (@item, @pane) ->
    @item.on? 'title-changed', =>
      @updateTitle()
      @updateTooltip()

    @item.on? 'modified-status-changed', =>
      @updateModifiedStatus()

    @item.addClass("preview") if @item.isPreview

    @updateTitle()
    @updateModifiedStatus()
    @updateTooltip()

  updateTooltip: ->
    @destroyTooltip()

    if itemPath = @item.getPath?()
      @setTooltip
        title: itemPath
        delay:
          show: 2000
          hide: 100
        placement: 'bottom'

  beforeRemove: ->
    @destroyTooltip()

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

  getSiblingTabs: ->
    @siblings('.tab').views()

  updateModifiedStatus: ->
    if @item.isModified?()
      @addClass('modified') unless @isModified
      @isModified = true
    else
      @removeClass('modified') if @isModified
      @isModified = false
